/** 督促アクション種別 */
export type DunningActionType = 'email' | 'internal_alert' | 'both'

/** 督促送信先種別 */
export type DunningSendTo = 'billing_contact' | 'primary_contact' | 'custom_email'

/** 督促ログステータス */
export type DunningLogStatus = 'sent' | 'failed' | 'opened' | 'clicked'

/** 督促ルール */
export interface DunningRule {
  id: number
  name: string
  trigger_days_after_due: number
  action_type: DunningActionType
  email_template_subject: string | null
  email_template_body: string | null
  send_to: DunningSendTo
  custom_email: string | null
  is_active: boolean
  sort_order: number
  max_dunning_count: number
  interval_days: number
  escalation_rule_id: number | null
  created_at: string
  updated_at: string
}

/** 督促ルール作成・更新リクエスト */
export interface DunningRuleRequest {
  name: string
  trigger_days_after_due: number
  action_type: DunningActionType
  email_template_subject?: string | null
  email_template_body?: string | null
  send_to: DunningSendTo
  custom_email?: string | null
  is_active?: boolean
  sort_order?: number
  max_dunning_count?: number
  interval_days?: number
  escalation_rule_id?: number | null
}

/** 督促ログ */
export interface DunningLog {
  id: number
  document_uuid: string
  dunning_rule_id: number
  customer_uuid: string
  action_type: DunningActionType
  sent_to_email: string | null
  email_subject: string | null
  email_body: string | null
  status: DunningLogStatus
  overdue_days: number
  remaining_amount: number
  created_at: string
}
