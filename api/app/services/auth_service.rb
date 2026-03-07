# frozen_string_literal: true

# 認証に関するビジネスロジックを集約するサービス
class AuthService
  class AuthenticationError < StandardError; end
  class RegistrationError < StandardError; end
  class PlanLimitError < StandardError; end

  # プラン別ユーザー数上限
  PLAN_USER_LIMITS = {
    "free" => 3,
    "starter" => 5,
    "standard" => 10,
    "professional" => nil # 無制限
  }.freeze

  class << self
    # @param params [Hash] :tenant_name, :industry_code, :name, :email, :password, :password_confirmation
    # @return [Hash] { user:, tenant:, tokens: }
    # @raise [RegistrationError] バリデーションエラー時
    def sign_up(params)
      ActiveRecord::Base.transaction do
        industry = IndustryTemplate.find_by(code: params[:industry_code]) || IndustryTemplate.find_by!(code: "general")

        tenant = Tenant.create!(
          name: params[:tenant_name],
          industry_type: industry.code,
          plan: "free"
        )

        user = User.create!(
          tenant: tenant,
          name: params[:name],
          email: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          role: "owner"
        )

        create_default_products(tenant, industry)
        create_default_dunning_rules(tenant)

        tokens = JwtService.encode(user)

        { user: user, tenant: tenant, tokens: tokens }
      end
    rescue ActiveRecord::RecordInvalid => e
      raise RegistrationError, e.record.errors.full_messages.join(", ")
    end

    # @param email [String]
    # @param password [String]
    # @return [Hash] { user:, tokens: }
    # @raise [AuthenticationError]
    def sign_in(email, password)
      user = User.find_by(email: email, deleted_at: nil)
      raise AuthenticationError, "メールアドレスまたはパスワードが正しくありません" unless user&.authenticate(password)

      user.update!(last_sign_in_at: Time.current, sign_in_count: user.sign_in_count + 1)
      tokens = JwtService.encode(user)

      { user: user, tokens: tokens }
    end

    # @param user [User]
    # @return [void]
    def sign_out(user)
      JwtService.revoke(user)
    end

    # @param refresh_token [String]
    # @return [Hash, nil] 新しいトークンペア
    def refresh(refresh_token)
      JwtService.refresh(refresh_token)
    end

    # @param email [String]
    # @return [void]
    def request_password_reset(email)
      user = User.find_by(email: email, deleted_at: nil)
      return unless user

      # Rails 8のhas_secure_password組み込みのパスワードリセットトークンを使用
      # トークンはpassword_saltベースで署名され、パスワード変更時に自動失効する
      token = user.password_reset_token
      AuthMailer.password_reset(user, token).deliver_later
    end

    # @param token [String]
    # @param password [String]
    # @param password_confirmation [String]
    # @return [User]
    # @raise [AuthenticationError]
    def reset_password(token, password, password_confirmation)
      user = User.find_by_password_reset_token(token)
      raise AuthenticationError, "無効なリセットトークンです" unless user

      user.update!(
        password: password,
        password_confirmation: password_confirmation
      )
      JwtService.revoke(user)
      user
    end

    # @param inviter [User]
    # @param params [Hash] :email, :name, :role
    # @return [User]
    # @raise [RegistrationError]
    # @raise [PlanLimitError] プランのユーザー数上限に達している場合
    def invite_user(inviter, params)
      tenant = inviter.tenant
      enforce_plan_user_limit!(tenant)

      token = SecureRandom.urlsafe_base64(32)
      user = User.create!(
        tenant: tenant,
        email: params[:email],
        name: params[:name],
        role: params[:role] || "member",
        password: SecureRandom.hex(16),  # temporary password
        invitation_token: token,
        invitation_sent_at: Time.current
      )
      AuthMailer.invitation(user, inviter).deliver_later
      user
    rescue ActiveRecord::RecordInvalid => e
      raise RegistrationError, e.record.errors.full_messages.join(", ")
    end

    # @param token [String]
    # @param params [Hash] :password, :password_confirmation
    # @return [Hash] { user:, tokens: }
    # @raise [AuthenticationError]
    def accept_invitation(token, params)
      user = User.find_by(invitation_token: token)
      raise AuthenticationError, "無効な招待トークンです" unless user

      user.update!(
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        invitation_token: nil,
        invitation_accepted_at: Time.current
      )

      tokens = JwtService.encode(user)
      { user: user, tokens: tokens }
    end

    private

    # @param tenant [Tenant]
    # @return [void]
    # @raise [PlanLimitError] ユーザー数上限に達している場合
    def enforce_plan_user_limit!(tenant)
      limit = PLAN_USER_LIMITS[tenant.plan]
      return if limit.nil? # 無制限プラン

      current_count = tenant.users.where(deleted_at: nil).count
      return if current_count < limit

      raise PlanLimitError,
            "#{tenant.plan}プランのユーザー数上限（#{limit}人）に達しています。プランをアップグレードしてください。"
    end

    # @param tenant [Tenant]
    # @param industry [IndustryTemplate]
    # @return [void]
    def create_default_products(tenant, industry)
      return unless industry.default_products.present?

      industry.default_products.each do |product_data|
        Product.create!(
          tenant: tenant,
          name: product_data["name"],
          unit: product_data["unit"],
          tax_rate_type: product_data["tax_rate_type"] || "standard"
        )
      end
    end

    # @param tenant [Tenant]
    # @return [void]
    def create_default_dunning_rules(tenant)
      [
        { name: "初回督促（7日後）", trigger_days_after_due: 7, action_type: "email",
          email_template_subject: "【{{company_name}}】お支払いのお願い（{{document_number}}）",
          email_template_body: "{{customer_name}}様\n\n{{document_number}}（{{total_amount}}円）のお支払い期日（{{due_date}}）を過ぎております。\nご確認をお願いいたします。\n\n{{company_name}}" },
        { name: "2回目督促（14日後）", trigger_days_after_due: 14, action_type: "email",
          email_template_subject: "【再送】【{{company_name}}】お支払いのお願い（{{document_number}}）",
          email_template_body: "{{customer_name}}様\n\n重ねてのご連絡となりますが、{{document_number}}（{{total_amount}}円）のお支払いが確認できておりません。\nお早めにご対応いただけますようお願いいたします。\n\n{{company_name}}" },
        { name: "3回目督促（30日後）", trigger_days_after_due: 30, action_type: "email",
          email_template_subject: "【重要】【{{company_name}}】お支払い催促（{{document_number}}）",
          email_template_body: "{{customer_name}}様\n\n{{document_number}}（{{total_amount}}円）につきまして、支払期日から30日が経過しております。\n至急のご対応をお願いいたします。\n\n{{company_name}}" }
      ].each_with_index do |rule_data, index|
        DunningRule.create!(
          tenant: tenant,
          name: rule_data[:name],
          trigger_days_after_due: rule_data[:trigger_days_after_due],
          action_type: rule_data[:action_type],
          email_template_subject: rule_data[:email_template_subject],
          email_template_body: rule_data[:email_template_body],
          is_active: true,
          sort_order: index
        )
      end
    end
  end
end
