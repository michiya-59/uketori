/** テナントのプラン種別 */
export type TenantPlan = 'free' | 'starter' | 'standard' | 'professional'

/** テナント情報 */
export interface Tenant {
  uuid: string
  name: string
  name_kana: string | null
  postal_code: string | null
  prefecture: string | null
  city: string | null
  address_line1: string | null
  address_line2: string | null
  phone: string | null
  fax: string | null
  email: string | null
  website: string | null
  invoice_registration_number: string | null
  invoice_number_verified: boolean
  logo_url: string | null
  seal_url: string | null
  bank_name: string | null
  bank_branch_name: string | null
  bank_account_type: number | null
  bank_account_number: string | null
  bank_account_holder: string | null
  industry_type: string
  fiscal_year_start_month: number
  plan: TenantPlan
  default_payment_terms_days: number
  default_tax_rate: number
  dunning_enabled: boolean
  ip_restriction_enabled: boolean
  allowed_ip_addresses: string[]
  import_enabled: boolean
  timezone: string
}
