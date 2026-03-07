/** ユーザーロール */
export type UserRole = 'owner' | 'admin' | 'accountant' | 'sales' | 'member'

/** ユーザー情報 */
export interface User {
  id: string
  name: string
  email: string
  role: UserRole
  last_sign_in_at?: string | null
  sign_in_count?: number
  created_at?: string
  updated_at?: string
}

/** トークンペア */
export interface Tokens {
  access_token: string
  refresh_token: string
  expires_in: number
}

/** 認証レスポンス（サインアップ用） */
export interface SignUpResponse {
  user: User
  tenant: {
    id: string
    name: string
    industry: string
    plan: string
  }
  tokens: Tokens
}

/** 認証レスポンス（サインイン用） */
export interface SignInResponse {
  user: User
  tokens: Tokens
}

/** トークンリフレッシュレスポンス */
export interface RefreshResponse {
  tokens: Tokens
}

/** サインアップリクエスト */
export interface SignUpRequest {
  auth: {
    tenant_name: string
    industry_code: string
    name: string
    email: string
    password: string
    password_confirmation: string
  }
}

/** ログインリクエスト */
export interface LoginRequest {
  auth: {
    email: string
    password: string
  }
}
