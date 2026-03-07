/** エイジングサマリー */
export interface AgingSummary {
  current: number
  days_1_30: number
  days_31_60: number
  days_61_90: number
  days_over_90: number
}

/** リスク顧客 */
export interface AtRiskCustomer {
  id: string
  company_name: string
  credit_score: number
  total_outstanding: number
  has_overdue: boolean
}

/** 月次トレンド */
export interface MonthlyTrend {
  month: string
  invoiced: number
  collected: number
}

/** 回収ダッシュボードレスポンス */
export interface CollectionDashboard {
  outstanding_total: number
  overdue_amount: number
  overdue_count: number
  paid_this_month: number
  collection_rate: number
  avg_dso: number
  aging_summary: AgingSummary
  at_risk_customers: AtRiskCustomer[]
  monthly_trend: MonthlyTrend[]
  unmatched_count: number
}

/** エイジングレポートの顧客行 */
export interface AgingCustomerRow {
  id: string
  company_name: string
  credit_score: number
  current: number
  days_1_30: number
  days_31_60: number
  days_61_90: number
  days_over_90: number
  total_outstanding: number
}

/** エイジングレポートレスポンス */
export interface AgingReportResponse {
  customers: AgingCustomerRow[]
  meta: {
    current_page: number
    total_pages: number
    total_count: number
    per_page: number
  }
}

/** 入金予測週次データ */
export interface ForecastWeek {
  week_start: string
  week_end: string
  expected_amount: number
}

/** 入金予測レスポンス */
export interface ForecastResponse {
  forecast: ForecastWeek[]
}
