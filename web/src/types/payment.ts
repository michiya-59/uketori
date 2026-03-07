/** 支払い方法 */
export type PaymentMethod = 'bank_transfer' | 'cash' | 'credit_card' | 'other'

/** マッチング種別 */
export type MatchType = 'manual' | 'ai_auto' | 'ai_suggested'

/** 入金記録 */
export interface PaymentRecord {
  uuid: string
  document_uuid: string
  bank_statement_id: number | null
  amount: number
  payment_date: string
  payment_method: PaymentMethod
  matched_by: MatchType
  match_confidence: number | null
  memo: string | null
  recorded_by_user_uuid: string
  created_at: string
  updated_at: string
}

/** 入金記録作成リクエスト */
export interface PaymentRecordRequest {
  document_uuid: string
  bank_statement_id?: number | null
  amount: number
  payment_date: string
  payment_method: PaymentMethod
  matched_by?: MatchType
  memo?: string | null
}

/** 銀行明細 */
export interface BankStatement {
  id: number
  transaction_date: string
  value_date: string | null
  description: string
  payer_name: string | null
  amount: number
  balance: number | null
  bank_name: string | null
  account_number: string | null
  is_matched: boolean
  matched_document_uuid: string | null
  ai_suggested_document_uuid: string | null
  ai_match_confidence: number | null
  ai_match_reason: string | null
  import_batch_id: string
  raw_data: Record<string, unknown> | null
  created_at: string
  updated_at: string
}
