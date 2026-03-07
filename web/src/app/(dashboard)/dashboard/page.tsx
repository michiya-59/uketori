"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  BadgeJapaneseYen,
  TrendingUp,
  TrendingDown,
  AlertTriangle,
  Calendar,
  FileText,
  FolderKanban,
  ArrowUpRight,
  Loader2,
  BarChart3,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import { api } from "@/lib/api-client";
import type { DashboardResponse } from "@/types";
import { toast } from "sonner";

/** 期間オプション */
const PERIOD_OPTIONS = [
  { value: "month", label: "今月" },
  { value: "quarter", label: "四半期" },
  { value: "year", label: "年度" },
] as const;

/** ステータスの日本語ラベル */
const STATUS_LABELS: Record<string, string> = {
  negotiation: "商談中",
  won: "受注",
  in_progress: "進行中",
  delivered: "納品済",
  invoiced: "請求済",
  partially_paid: "一部入金",
  overdue: "遅延",
  draft: "下書き",
  approved: "承認済",
  sent: "送信済",
  paid: "入金済",
  unpaid: "未入金",
  partial: "一部入金",
  bad_debt: "貸倒",
};

/** 帳票種別の日本語ラベル */
const DOC_TYPE_LABELS: Record<string, string> = {
  estimate: "見積書",
  purchase_order: "発注書",
  order_confirmation: "注文請書",
  delivery_note: "納品書",
  invoice: "請求書",
  receipt: "領収書",
};

/**
 * 金額をフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * 前期比の変化率を計算する
 * @param current - 今期の値
 * @param previous - 前期の値
 * @returns 変化率（%）
 */
function calcChange(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100);
}

/**
 * ダッシュボードページ
 * APIからKPI・売上推移・入金予定・最近の取引・パイプラインを取得して表示する
 * @returns ダッシュボードページ要素
 */
export default function DashboardPage() {
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState<string>("month");

  const fetchDashboard = useCallback(async (p: string) => {
    try {
      setLoading(true);
      const res = await api.get<DashboardResponse>("/api/v1/dashboard", { period: p });
      setData(res);
    } catch {
      toast.error("ダッシュボードの取得に失敗しました");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchDashboard(period);
  }, [period, fetchDashboard]);

  if (loading && data == null) {
    return (
      <div className="flex items-center justify-center py-32">
        <Loader2 className="size-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (data == null) return null;

  const revenueChange = calcChange(
    Number(data.kpi.revenue.current),
    Number(data.kpi.revenue.previous)
  );
  const collectionChange = data.kpi.collection_rate.current - data.kpi.collection_rate.previous;

  return (
    <div className="space-y-6">
      {/* ヘッダー + 期間切替 */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">ダッシュボード</h1>
          <p className="mt-1 text-muted-foreground">ビジネスの概要を確認できます</p>
        </div>
        <div className="flex gap-1 rounded-lg border p-1 self-start">
          {PERIOD_OPTIONS.map((opt) => (
            <Button
              key={opt.value}
              variant={period === opt.value ? "default" : "ghost"}
              size="sm"
              onClick={() => setPeriod(opt.value)}
              className="text-sm"
            >
              {opt.label}
            </Button>
          ))}
        </div>
      </div>

      {/* 遅延アラート */}
      {data.alert != null && (
        <Card className="border-destructive bg-destructive/5">
          <CardContent className="flex items-center gap-3 py-4">
            <AlertTriangle className="size-5 text-destructive" />
            <p className="text-[15px] font-medium text-destructive">
              {data.alert.overdue_count}件の請求書が支払い期限を超過しています（合計 {formatCurrency(data.alert.overdue_amount)}）
            </p>
            <Link href="/collection" className="ml-auto">
              <Button variant="destructive" size="sm">回収管理を確認</Button>
            </Link>
          </CardContent>
        </Card>
      )}

      {/* KPIカード */}
      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">今月の売上</CardTitle>
            <TrendingUp className="size-5 text-muted-foreground/50" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatCurrency(Number(data.kpi.revenue.current))}</div>
            <p className={`mt-1 text-sm ${revenueChange >= 0 ? "text-green-600" : "text-red-600"}`}>
              {revenueChange >= 0 ? "+" : ""}{revenueChange}% 前期比
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">未回収額</CardTitle>
            <BadgeJapaneseYen className="size-5 text-muted-foreground/50" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatCurrency(Number(data.kpi.outstanding.amount))}</div>
            <p className="mt-1 text-sm text-muted-foreground">
              {data.kpi.outstanding.overdue_count > 0 && (
                <span className="text-destructive font-medium">{data.kpi.outstanding.overdue_count}件遅延</span>
              )}
              {data.kpi.outstanding.overdue_count === 0 && "遅延なし"}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">回収率</CardTitle>
            <BarChart3 className="size-5 text-muted-foreground/50" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.kpi.collection_rate.current}%</div>
            <p className={`mt-1 text-sm ${collectionChange >= 0 ? "text-green-600" : "text-red-600"}`}>
              {collectionChange >= 0 ? "+" : ""}{collectionChange.toFixed(1)}pt 前期比
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">案件数</CardTitle>
            <FolderKanban className="size-5 text-muted-foreground/50" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {Object.values(data.kpi.projects).reduce((sum, c) => sum + c, 0)}
            </div>
            <p className="mt-1 text-sm text-muted-foreground">
              {Object.entries(data.kpi.projects).map(([s, c]) => `${STATUS_LABELS[s] ?? s}: ${c}`).join("、") || "なし"}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* 売上推移グラフ + 入金予定 */}
      <div className="grid gap-5 lg:grid-cols-3">
        <Card className="lg:col-span-2 min-w-0">
          <CardHeader>
            <CardTitle className="text-lg">売上推移</CardTitle>
            <CardDescription>過去6ヶ月の請求額と回収額</CardDescription>
          </CardHeader>
          <CardContent>
            {data.revenue_trend.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={data.revenue_trend}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="month" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(v: number) => `${(v / 10000).toFixed(0)}万`} />
                  <Tooltip formatter={(value) => formatCurrency(Number(value))} />
                  <Legend />
                  <Bar dataKey="invoiced" name="請求額" fill="hsl(220 70% 55%)" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="collected" name="回収額" fill="hsl(160 60% 45%)" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex items-center justify-center py-16 text-muted-foreground">
                データがありません
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <Calendar className="size-5 text-primary" />
              入金予定
            </CardTitle>
            <CardDescription>直近14日間</CardDescription>
          </CardHeader>
          <CardContent>
            {data.upcoming_payments.length > 0 ? (
              <div className="space-y-3">
                {data.upcoming_payments.map((p) => (
                  <Link
                    key={p.id}
                    href={`/documents/${p.id}`}
                    className="flex items-center justify-between rounded-lg border p-3 transition-colors hover:bg-accent"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">{p.document_number}</p>
                      <p className="truncate text-xs text-muted-foreground">{p.customer_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-semibold">{formatCurrency(Number(p.remaining_amount))}</p>
                      <p className="text-xs text-muted-foreground">{p.due_date}</p>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">予定なし</p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* 最近の取引 + パイプライン */}
      <div className="grid gap-5 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <FileText className="size-5 text-primary" />
              最近の取引
            </CardTitle>
            <CardDescription>直近10件</CardDescription>
          </CardHeader>
          <CardContent>
            {data.recent_transactions.length > 0 ? (
              <div className="space-y-2">
                {data.recent_transactions.map((tx) => (
                  <Link
                    key={tx.id}
                    href={`/documents/${tx.id}`}
                    className="flex items-center justify-between rounded-lg border p-3 transition-colors hover:bg-accent"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-medium">{tx.document_number}</p>
                        <Badge variant="outline" className="text-xs">
                          {DOC_TYPE_LABELS[tx.document_type] ?? tx.document_type}
                        </Badge>
                      </div>
                      <p className="truncate text-xs text-muted-foreground">{tx.customer_name}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-semibold">{formatCurrency(Number(tx.total_amount))}</p>
                      {tx.payment_status != null && (
                        <Badge
                          variant={tx.payment_status === "paid" ? "default" : tx.payment_status === "overdue" ? "destructive" : "secondary"}
                          className="text-xs"
                        >
                          {STATUS_LABELS[tx.payment_status] ?? tx.payment_status}
                        </Badge>
                      )}
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">取引がありません</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <FolderKanban className="size-5 text-primary" />
              案件パイプライン
            </CardTitle>
            <CardDescription>ステータス別の金額</CardDescription>
          </CardHeader>
          <CardContent>
            {data.pipeline.length > 0 ? (
              <div className="space-y-4">
                {data.pipeline.map((item) => {
                  const maxAmount = Math.max(...data.pipeline.map((p) => Number(p.amount)));
                  const pct = maxAmount > 0 ? (Number(item.amount) / maxAmount) * 100 : 0;
                  return (
                    <div key={item.status}>
                      <div className="mb-1 flex items-center justify-between text-sm">
                        <span className="font-medium">{STATUS_LABELS[item.status] ?? item.status}</span>
                        <span className="text-muted-foreground">{formatCurrency(Number(item.amount))}</span>
                      </div>
                      <div className="h-3 overflow-hidden rounded-full bg-muted">
                        <div
                          className="h-full rounded-full bg-primary transition-all"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">案件がありません</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
