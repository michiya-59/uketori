# frozen_string_literal: true

module Api
  module V1
    # 顧客担当者を管理するコントローラー
    #
    # 顧客のネストリソースとして担当者のCRUDを提供する。
    class CustomerContactsController < BaseController
      before_action :set_customer
      before_action :set_contact, only: %i[update destroy]

      # 担当者一覧を返す
      #
      # @return [void]
      def index
        authorize @customer, :show?
        contacts = @customer.customer_contacts.order(:id)

        render json: { contacts: contacts.map { |c| serialize_contact(c) } }
      end

      # 担当者を追加する
      #
      # @return [void]
      def create
        authorize @customer, :update?
        contact = @customer.customer_contacts.build(contact_params)
        contact.save!

        render json: { contact: serialize_contact(contact) }, status: :created
      end

      # 担当者情報を更新する
      #
      # @return [void]
      def update
        authorize @customer, :update?
        @contact.update!(contact_params)

        render json: { contact: serialize_contact(@contact) }
      end

      # 担当者を削除する
      #
      # @return [void]
      def destroy
        authorize @customer, :update?
        @contact.destroy!

        head :no_content
      end

      private

      # @return [void]
      def set_customer
        @customer = policy_scope(Customer).active.find_by_uuid!(params[:customer_id])
      end

      # @return [void]
      def set_contact
        @contact = @customer.customer_contacts.find(params[:id])
      end

      # @return [ActionController::Parameters]
      def contact_params
        params.require(:contact).permit(
          :name, :email, :phone, :department, :title,
          :is_primary, :is_billing_contact, :memo
        )
      end

      # @param contact [CustomerContact]
      # @return [Hash] 担当者情報
      def serialize_contact(contact)
        {
          id: contact.id,
          name: contact.name,
          email: contact.email,
          phone: contact.phone,
          department: contact.department,
          title: contact.title,
          is_primary: contact.is_primary,
          is_billing_contact: contact.is_billing_contact,
          memo: contact.memo
        }
      end
    end
  end
end
