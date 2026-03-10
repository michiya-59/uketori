Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # 認証
      namespace :auth do
        post "sign_up", to: "sign_ups#create"
        post "sign_in", to: "sessions#create"
        post "refresh", to: "sessions#refresh"
        delete "sign_out", to: "sessions#destroy"
        post "password/reset", to: "passwords#reset"
        patch "password/update", to: "passwords#update"
        post "invitation/accept", to: "invitations#accept"
      end

      # テナント設定
      resource :tenant, only: %i[show update]

      # 業種テンプレート（認証不要のマスタデータ）
      resources :industry_templates, only: %i[index show]

      # ユーザー管理
      resources :users, only: %i[index create show update destroy] do
        post :invite, on: :collection
      end

      # 顧客
      resources :customers do
        get :documents, on: :member
        get :credit_history, on: :member
        post :verify_invoice_number, on: :member
        post :katakana, on: :collection
        resources :contacts, controller: "customer_contacts", only: %i[index create update destroy]
      end

      # 品目マスタ
      resources :products

      # 案件
      resources :projects do
        patch :status, on: :member
        get :documents, on: :member
        get :pipeline, on: :collection
      end

      # 帳票
      resources :documents do
        post :duplicate, on: :member
        post :convert, on: :member
        post :approve, on: :member
        post :reject, on: :member
        post :send_document, on: :member
        post :lock, on: :member
        get :pdf, on: :member
        get :versions, on: :member
        post :ai_suggest, on: :member
        post :bulk_generate, on: :collection
      end

      # 入金
      resources :payments, only: %i[index create destroy]

      # 銀行明細
      resources :bank_statements, only: %i[index] do
        post :import, on: :collection
        post :ocr_preview, on: :collection
        get :unmatched, on: :collection
        post :match, on: :member
        post :ai_match, on: :collection
        post :ai_suggest, on: :member
      end

      # 督促
      namespace :dunning do
        resources :rules
        resources :logs, only: %i[index]
        post :execute, to: "executions#create"
      end

      # 回収
      namespace :collection do
        get :dashboard, to: "dashboard#dashboard"
        get :aging_report, to: "dashboard#aging_report"
        get :forecast, to: "dashboard#forecast"
      end

      # データ移行
      resources :imports, only: %i[create show] do
        get :preview, on: :member
        patch :mapping, on: :member
        post :execute, on: :member
        get :result, on: :member
        get :error_csv, on: :member
      end

      # お問い合わせ
      post "contact", to: "contacts#create"
      post "contact/plan_inquiry", to: "contacts#plan_inquiry"

      # 通知
      resources :notifications, only: %i[index update]

      # ダッシュボード
      get "dashboard", to: "dashboard#show"

      # システム管理者
      namespace :admin do
        get "me", to: "me#show"
        resources :tenants, only: %i[index show update]
      end
    end
  end
end
