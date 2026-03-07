"use client";

import { useEffect, useState, useCallback } from "react";
import { BarChart3, TrendingUp, AlertTriangle, DollarSign } from "lucide-react";
import { toast } from "sonner";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { api, ApiClientError } from "@/lib/api-client";
import type { DashboardResponse } from "@/types/dashboard";
import type { CollectionDashboard, AgingSummary } from "@/types/collection";

/**
 * レポートページ
 * 売上KPI、売上推移、エイジング概要を表示する
 * @returns レポートページ要素
 */
export default function ReportsPage() {
  const [dashboard, setDashboard] = useState<DashboardResponse | null>(null);
  const [collection, setCollection] = useState<CollectionDashboard | null>(null);
  const [loading, setLoading] = useState(true);

  /** ダッシュボードデータと回収ダッシュボードを取得する */
  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      const [dashRes, collRes] = await Promise.all([
        api.get<DashboardResponse>("/api/v1/dashboard"),
        api.get<CollectionDashboard>("/api/v1/collection/dashboard"),
      ]);
      setDashboard(dashRes);
      setCollection(collRes);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "レポートデータの取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <div className="grid gap-4 sm:grid-cols-3">
          <Skeleton className="h-32" />
          <Skeleton className="h-32" />
          <Skeleton className="h-32" />
        </div>
        <Skeleton className="h-64" />
      </div>
    );
  }

  const revenue = dashboard?.kpi?.revenue;
  const outstanding = dashboard?.kpi?.outstanding;
  const collectionRate = dashboard?.kpi?.collection_rate;
  const aging = collection?.aging_summary;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">レポート</h1>
        <p className="mt-1 text-muted-foreground">
          売上・回収状況のレポートを確認します
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">月次売上</CardTitle>
            <DollarSign className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold tabular-nums">
              ¥{(revenue?.current ?? 0).toLocaleString()}
            </div>
            {revenue?.previous != null && revenue.previous > 0 && (
              <p className="text-xs text-muted-foreground">
                前月: ¥{revenue.previous.toLocaleString()}
                {revenue.current > revenue.previous ? (
                  <span className="text-green-600 ml-1">
                    (+{Math.round(((revenue.current - revenue.previous) / revenue.previous) * 100)}%)
                  </span>
                ) : revenue.current < revenue.previous ? (
                  <span className="text-red-600 ml-1">
                    ({Math.round(((revenue.current - revenue.previous) / revenue.previous) * 100)}%)
                  </span>
                ) : null}
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">未回収金額</CardTitle>
            <AlertTriangle className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold tabular-nums">
              ¥{(outstanding?.amount ?? collection?.outstanding_total ?? 0).toLocaleString()}
            </div>
            <p className="text-xs text-muted-foreground">
              期限超過: {outstanding?.overdue_count ?? collection?.overdue_count ?? 0}件
              {collection?.overdue_amount != null && (
                <span> (¥{collection.overdue_amount.toLocaleString()})</span>
              )}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">回収率</CardTitle>
            <TrendingUp className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold tabular-nums">
              {(collectionRate?.current ?? collection?.collection_rate ?? 0).toFixed(1)}%
            </div>
            {collectionRate?.previous != null && (
              <p className="text-xs text-muted-foreground">
                前月: {collectionRate.previous.toFixed(1)}%
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {dashboard?.revenue_trend && dashboard.revenue_trend.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <BarChart3 className="size-5" />
              売上推移
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>月</TableHead>
                  <TableHead className="text-right">請求額</TableHead>
                  <TableHead className="text-right">回収額</TableHead>
                  <TableHead className="text-right">回収率</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {dashboard.revenue_trend.map((trend) => {
                  const rate =
                    trend.invoiced > 0
                      ? ((trend.collected / trend.invoiced) * 100).toFixed(1)
                      : "-";
                  return (
                    <TableRow key={trend.month}>
                      <TableCell className="font-medium">
                        {trend.month}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        ¥{trend.invoiced.toLocaleString()}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        ¥{trend.collected.toLocaleString()}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {rate === "-" ? "-" : `${rate}%`}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {aging && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">エイジング概要</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 grid-cols-2 sm:grid-cols-3 lg:grid-cols-5">
              <AgingCard label="未到来" amount={aging.current} />
              <AgingCard label="1-30日" amount={aging.days_1_30} />
              <AgingCard label="31-60日" amount={aging.days_31_60} warn />
              <AgingCard label="61-90日" amount={aging.days_61_90} warn />
              <AgingCard label="90日超" amount={aging.days_over_90} critical />
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

/**
 * エイジングカードコンポーネント
 * @param label - ラベル
 * @param amount - 金額
 * @param warn - 警告色で表示するか
 * @param critical - 危険色で表示するか
 * @returns エイジングカード要素
 */
function AgingCard({
  label,
  amount,
  warn,
  critical,
}: {
  label: string;
  amount: number;
  warn?: boolean;
  critical?: boolean;
}) {
  const colorClass = critical
    ? "text-red-600"
    : warn
      ? "text-amber-600"
      : "";

  return (
    <div className="text-center">
      <p className="text-xs text-muted-foreground mb-1">{label}</p>
      <p className={`text-lg font-bold tabular-nums ${colorClass}`}>
        ¥{amount.toLocaleString()}
      </p>
    </div>
  );
}
