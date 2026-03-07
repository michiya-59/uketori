/** 書類種別 */
export type DocumentType =
  | 'estimate'
  | 'purchase_order'
  | 'order_confirmation'
  | 'delivery_note'
  | 'invoice'
  | 'receipt'

/** 書類ステータス */
export type DocumentStatus =
  | 'draft'
  | 'approved'
  | 'sent'
  | 'accepted'
  | 'rejected'
  | 'cancelled'
  | 'locked'

/** 入金ステータス */
export type PaymentStatus =
  | 'unpaid'
  | 'partial'
  | 'paid'
  | 'overdue'
  | 'bad_debt'

/** 明細行種別 */
export type DocumentItemType = 'normal' | 'subtotal' | 'discount' | 'section_header'

/** 税率種別 */
export type TaxRateType = 'standard' | 'reduced' | 'exempt'

/** 書類明細行 */
export interface DocumentItem {
  id: number
  product_uuid: string | null
  sort_order: number
  item_type: DocumentItemType
  name: string
  description: string | null
  quantity: number
  unit: string | null
  unit_price: number
  amount: number
  tax_rate: number
  tax_rate_type: TaxRateType
  tax_amount: number
}

/** 税率別サマリ */
export interface TaxSummary {
  rate: number
  subtotal: number
  tax: number
}

/** 送信者・受信者スナップショット */
export interface AddressSnapshot {
  name?: string
  postal_code?: string
  prefecture?: string
  city?: string
  address_line1?: string
  address_line2?: string
  phone?: string
  email?: string
  invoice_registration_number?: string
}

/** 書類情報 */
export interface Document {
  uuid: string
  project_uuid: string | null
  customer_uuid: string
  created_by_user_uuid: string
  document_type: DocumentType
  document_number: string
  status: DocumentStatus
  version: number
  parent_document_uuid: string | null
  title: string | null
  issue_date: string
  due_date: string | null
  valid_until: string | null
  subtotal_amount: number
  tax_amount: number
  total_amount: number
  tax_summary: TaxSummary[]
  notes: string | null
  internal_memo: string | null
  sender_snapshot: AddressSnapshot
  recipient_snapshot: AddressSnapshot
  pdf_url: string | null
  pdf_generated_at: string | null
  sent_at: string | null
  sent_method: string | null
  locked_at: string | null
  payment_status: PaymentStatus | null
  paid_amount: number
  remaining_amount: number
  last_dunning_at: string | null
  dunning_count: number
  is_recurring: boolean
  recurring_rule_uuid: string | null
  imported_from: string | null
  external_id: string | null
  document_items: DocumentItem[]
  created_at: string
  updated_at: string
}

/** 明細行作成・更新リクエスト */
export interface DocumentItemRequest {
  id?: number
  product_uuid?: string | null
  sort_order?: number
  item_type?: DocumentItemType
  name: string
  description?: string | null
  quantity: number
  unit?: string | null
  unit_price: number
  tax_rate?: number
  tax_rate_type?: TaxRateType
  _destroy?: boolean
}

/** 書類作成・更新リクエスト */
export interface DocumentRequest {
  project_uuid?: string | null
  customer_uuid: string
  document_type: DocumentType
  title?: string | null
  issue_date: string
  due_date?: string | null
  valid_until?: string | null
  notes?: string | null
  internal_memo?: string | null
  document_items_attributes: DocumentItemRequest[]
}
