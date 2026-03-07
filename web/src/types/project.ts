/** 案件ステータス */
export type ProjectStatus =
  | 'negotiation'
  | 'won'
  | 'lost'
  | 'in_progress'
  | 'delivered'
  | 'invoiced'
  | 'paid'
  | 'partially_paid'
  | 'overdue'
  | 'bad_debt'
  | 'cancelled'

/** 案件情報（API レスポンス） */
export interface Project {
  id: string
  project_number: string
  name: string
  status: ProjectStatus
  customer_id: string | null
  customer_name: string | null
  assigned_user_id: string | null
  assigned_user_name: string | null
  probability: number | null
  amount: number | null
  cost: number | null
  start_date: string | null
  end_date: string | null
  description?: string | null
  created_at: string
  updated_at?: string
}

/** 案件作成・更新リクエスト */
export interface ProjectRequest {
  name: string
  customer_id: string
  assigned_user_id?: string | null
  probability?: number | null
  amount?: number | null
  cost?: number | null
  start_date?: string | null
  end_date?: string | null
  description?: string | null
}
