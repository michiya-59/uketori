/** 売上KPI */
export interface RevenueKpi {
  current: number;
  previous: number;
}

/** 未回収KPI */
export interface OutstandingKpi {
  amount: number;
  overdue_count: number;
}

/** 回収率KPI */
export interface CollectionRateKpi {
  current: number;
  previous: number;
}

/** KPI全体 */
export interface DashboardKpi {
  revenue: RevenueKpi;
  outstanding: OutstandingKpi;
  collection_rate: CollectionRateKpi;
  projects: Record<string, number>;
}

/** 遅延アラート */
export interface OverdueAlert {
  overdue_count: number;
  overdue_amount: number;
}

/** 売上推移 */
export interface RevenueTrend {
  month: string;
  invoiced: number;
  collected: number;
}

/** 入金予定 */
export interface UpcomingPayment {
  id: string;
  document_number: string;
  customer_name: string | null;
  due_date: string;
  remaining_amount: number;
}

/** 最近の取引 */
export interface RecentTransaction {
  id: string;
  document_number: string;
  document_type: string;
  customer_name: string | null;
  total_amount: number;
  status: string;
  payment_status: string | null;
  updated_at: string;
}

/** パイプライン */
export interface PipelineItem {
  status: string;
  amount: number;
}

/** ダッシュボードレスポンス全体 */
export interface DashboardResponse {
  kpi: DashboardKpi;
  alert: OverdueAlert | null;
  revenue_trend: RevenueTrend[];
  upcoming_payments: UpcomingPayment[];
  recent_transactions: RecentTransaction[];
  pipeline: PipelineItem[];
  period: string;
}
