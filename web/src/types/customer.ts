/** 顧客区分 */
export type CustomerType = 'client' | 'vendor' | 'both'

/** 顧客情報 */
export interface Customer {
  id: string
  uuid?: string
  customer_type: CustomerType
  company_name: string
  company_name_kana: string | null
  department: string | null
  title: string | null
  contact_name: string | null
  email: string | null
  phone: string | null
  fax: string | null
  postal_code: string | null
  prefecture: string | null
  city: string | null
  address_line1: string | null
  address_line2: string | null
  invoice_registration_number: string | null
  invoice_number_verified: boolean
  invoice_number_verified_at: string | null
  payment_terms_days: number | null
  default_tax_rate: number | null
  bank_name: string | null
  bank_branch_name: string | null
  bank_account_type: number | null
  bank_account_number: string | null
  bank_account_holder: string | null
  tags: string[]
  memo: string | null
  credit_score: number | null
  credit_score_updated_at: string | null
  avg_payment_days: number | null
  late_payment_rate: number | null
  total_outstanding: number
  imported_from: string | null
  external_id: string | null
  created_at: string
  updated_at: string
}

/** 顧客作成・更新リクエスト */
export interface CustomerRequest {
  customer_type?: CustomerType
  company_name: string
  company_name_kana?: string | null
  department?: string | null
  title?: string | null
  contact_name?: string | null
  email?: string | null
  phone?: string | null
  fax?: string | null
  postal_code?: string | null
  prefecture?: string | null
  city?: string | null
  address_line1?: string | null
  address_line2?: string | null
  invoice_registration_number?: string | null
  payment_terms_days?: number | null
  default_tax_rate?: number | null
  bank_name?: string | null
  bank_branch_name?: string | null
  bank_account_type?: number | null
  bank_account_number?: string | null
  bank_account_holder?: string | null
  tags?: string[]
  memo?: string | null
}
