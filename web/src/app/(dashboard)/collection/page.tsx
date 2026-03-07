"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  BadgeJapaneseYen,
  AlertTriangle,
  Clock,
  TrendingUp,
  ArrowRight,
  Ban,
  BarChart3,
} from "lucide-react";
import { toast } from "sonner";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Progress } from "@/components/ui/progress";
import { api, ApiClientError } from "@/lib/api-client";
import type {
  CollectionDashboard,
  AtRiskCustomer,
  MonthlyTrend,
  AgingSummary,
} from "@/types/collection";

/**
 * 金額を3桁カンマ区切りでフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatAmount(amount: number): string {
  return `¥${amount.toLocaleString()}`;
}

/**
 * エイジング区分ごとの色を返す
 * @param key - エイジング区分キー
 * @returns Tailwind CSSクラス文字列
 */
function agingColor(key: string): string {
  switch (key) {
    case "current": return "bg-green-500";
    case "days_1_30": return "bg-yellow-500";
    case "days_31_60": return "bg-orange-500";
    case "days_61_90": return "bg-red-400";
    case "days_over_90": return "bg-red-600";
    default: return "bg-gray-300";
  }
}

/** エイジング区分ラベル */
const AGING_LABELS: Record<string, string> = {
  current: "期限内",
  days_1_30: "1〜30日",
  days_31_60: "31〜60日",
  days_61_90: "61〜90日",
  days_over_90: "90日超",
};

/**
 * 回収管理ダッシュボードページ
 * KPI、エイジングサマリー、要注意取引先、月次トレンドを表示する
 */
export default function CollectionDashboardPage() {
  const [data, setData] = useState<CollectionDashboard | null>(null);
  const [loading, setLoading] = useState(true);

  /**
   * ダッシュボードデータを取得する
   */
  const fetchDashboard = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get<CollectionDashboard>("/api/v1/collection/dashboard");
      setData(res);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("ダッシュボードの取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDashboard();
  }, [fetchDashboard]);

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">回収管理</h1>
          <p className="text-sm text-muted-foreground">売掛金の回収状況を一覧で確認できます</p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Card key={i}>
              <CardHeader className="pb-2"><Skeleton className="h-4 w-20" /></CardHeader>
              <CardContent><Skeleton className="h-8 w-32" /></CardContent>
            </Card>
          ))}
        </div>
        <div className="grid gap-4 lg:grid-cols-2">
          <Card><CardContent className="pt-6"><Skeleton className="h-48" /></CardContent></Card>
          <Card><CardContent className="pt-6"><Skeleton className="h-48" /></CardContent></Card>
        </div>
      </div>
    );
  }

  if (!data) return null;

  const agingTotal = data.aging_summary.current + data.aging_summary.days_1_30 +
    data.aging_summary.days_31_60 + data.aging_summary.days_61_90 + data.aging_summary.days_over_90;

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">回収管理</h1>
          <p className="text-sm text-muted-foreground">売掛金の回収状況を一覧で確認できます</p>
        </div>
        <Button variant="outline" asChild className="self-start sm:self-auto">
          <Link href="/collection/aging">
            <BarChart3 className="mr-2 size-4" />
            売掛金年齢表
          </Link>
        </Button>
      </div>

      {/* KPIカード */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">未回収合計</CardTitle>
            <BadgeJapaneseYen className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatAmount(data.outstanding_total)}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">遅延金額</CardTitle>
            <AlertTriangle className="size-4 text-destructive" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-destructive">{formatAmount(data.overdue_amount)}</div>
            <p className="text-xs text-muted-foreground">{data.overdue_count}件の遅延請求書</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">回収率（当月）</CardTitle>
            <TrendingUp className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.collection_rate}%</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">平均DSO</CardTitle>
            <Clock className="size-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.avg_dso}日</div>
            {data.unmatched_count > 0 && (
              <p className="text-xs text-orange-600">
                未消込: {data.unmatched_count}件
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* エイジングサマリー */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base">エイジング分析</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {agingTotal === 0 ? (
              <p className="text-sm text-muted-foreground py-8 text-center">未回収の売掛金はありません</p>
            ) : (
              <>
                <div className="flex h-4 w-full overflow-hidden rounded-full">
                  {(Object.keys(AGING_LABELS) as (keyof AgingSummary)[]).map((key) => {
                    const value = data.aging_summary[key];
                    const pct = agingTotal > 0 ? (value / agingTotal) * 100 : 0;
                    if (pct === 0) return null;
                    return (
                      <div
                        key={key}
                        className={`${agingColor(key)} transition-all`}
                        style={{ width: `${pct}%` }}
                      />
                    );
                  })}
                </div>
                <div className="space-y-2">
                  {(Object.keys(AGING_LABELS) as (keyof AgingSummary)[]).map((key) => (
                    <div key={key} className="flex items-center justify-between text-sm">
                      <div className="flex items-center gap-2">
                        <div className={`size-3 rounded-full ${agingColor(key)}`} />
                        <span>{AGING_LABELS[key]}</span>
                      </div>
                      <span className="font-medium">{formatAmount(data.aging_summary[key])}</span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </CardContent>
        </Card>

        {/* 要注意取引先 */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">要注意取引先</CardTitle>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/collection/aging">
                詳細
                <ArrowRight className="ml-1 size-3" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent>
            {data.at_risk_customers.length === 0 ? (
              <p className="text-sm text-muted-foreground py-8 text-center">リスクの高い取引先はありません</p>
            ) : (
              <div className="space-y-3">
                {data.at_risk_customers.slice(0, 5).map((customer) => (
                  <div key={customer.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-2 min-w-0">
                      <Link
                        href={`/customers/${customer.id}`}
                        className="truncate text-sm font-medium hover:underline"
                      >
                        {customer.company_name}
                      </Link>
                      {customer.has_overdue && (
                        <Badge variant="destructive" className="text-[10px] px-1.5 py-0">
                          遅延
                        </Badge>
                      )}
                    </div>
                    <div className="flex items-center gap-3 shrink-0">
                      <span className="text-xs text-muted-foreground">
                        スコア: {customer.credit_score}
                      </span>
                      <span className="text-sm font-medium">
                        {formatAmount(customer.total_outstanding)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* 月次トレンド */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">回収トレンド（過去6ヶ月）</CardTitle>
        </CardHeader>
        <CardContent>
          {data.monthly_trend.length === 0 ? (
            <p className="text-sm text-muted-foreground py-8 text-center">データがありません</p>
          ) : (
            <div className="space-y-3">
              {data.monthly_trend.map((month) => {
                const rate = month.invoiced > 0
                  ? Math.round((month.collected / month.invoiced) * 100)
                  : 0;
                return (
                  <div key={month.month} className="space-y-1">
                    <div className="flex items-center justify-between text-sm">
                      <span className="font-medium">{month.month}</span>
                      <span className="text-muted-foreground">
                        {formatAmount(month.collected)} / {formatAmount(month.invoiced)}
                        <span className="ml-2 font-medium">
                          ({rate}%)
                        </span>
                      </span>
                    </div>
                    <Progress value={rate} className="h-2" />
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
