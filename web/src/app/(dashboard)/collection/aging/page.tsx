"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  ChevronLeft,
  ChevronRight,
  ArrowLeft,
  BarChart3,
} from "lucide-react";
import { toast } from "sonner";
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
import { api, ApiClientError } from "@/lib/api-client";
import type { AgingCustomerRow, AgingReportResponse } from "@/types/collection";

/**
 * 金額を3桁カンマ区切りでフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatAmount(amount: number): string {
  if (amount === 0) return "-";
  return `¥${amount.toLocaleString()}`;
}

/**
 * 与信スコアに応じたバッジバリアントを返す
 * @param score - 与信スコア
 * @returns Badgeバリアント
 */
function scoreBadgeVariant(score: number): "default" | "secondary" | "destructive" | "outline" {
  if (score >= 70) return "default";
  if (score >= 50) return "secondary";
  if (score >= 30) return "outline";
  return "destructive";
}

/**
 * 売掛金年齢表ページ
 * 顧客別のエイジング分析を表形式で表示する
 */
export default function AgingReportPage() {
  const [customers, setCustomers] = useState<AgingCustomerRow[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, total_pages: 1, total_count: 0, per_page: 25 });
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);

  /**
   * エイジングレポートを取得する
   */
  const fetchReport = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get<AgingReportResponse>("/api/v1/collection/aging_report", {
        page: page.toString(),
      });
      setCustomers(data.customers);
      setMeta(data.meta);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("エイジングレポートの取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => {
    fetchReport();
  }, [fetchReport]);

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild className="size-10 sm:size-9">
            <Link href="/collection">
              <ArrowLeft className="size-5 sm:size-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">売掛金年齢表</h1>
            <p className="text-sm text-muted-foreground">
              顧客別の未回収売掛金をエイジング区分で確認できます
            </p>
          </div>
        </div>
        <div className="text-sm text-muted-foreground pl-12 sm:pl-0">
          全{meta.total_count}社
        </div>
      </div>

      {/* テーブル */}
      <div className="overflow-x-auto rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>取引先</TableHead>
              <TableHead className="text-center">スコア</TableHead>
              <TableHead className="text-right">期限内</TableHead>
              <TableHead className="text-right">1〜30日</TableHead>
              <TableHead className="text-right">31〜60日</TableHead>
              <TableHead className="text-right">61〜90日</TableHead>
              <TableHead className="text-right">90日超</TableHead>
              <TableHead className="text-right">合計</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              Array.from({ length: 8 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 8 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton className="h-4 w-full" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : customers.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                  <BarChart3 className="mx-auto mb-2 size-8 opacity-50" />
                  未回収の売掛金はありません
                </TableCell>
              </TableRow>
            ) : (
              customers.map((row) => (
                <TableRow key={row.id}>
                  <TableCell>
                    <Link
                      href={`/customers/${row.id}`}
                      className="font-medium text-primary hover:underline"
                    >
                      {row.company_name}
                    </Link>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant={scoreBadgeVariant(row.credit_score)}>
                      {row.credit_score}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">{formatAmount(row.current)}</TableCell>
                  <TableCell className="text-right text-yellow-600">{formatAmount(row.days_1_30)}</TableCell>
                  <TableCell className="text-right text-orange-600">{formatAmount(row.days_31_60)}</TableCell>
                  <TableCell className="text-right text-red-500">{formatAmount(row.days_61_90)}</TableCell>
                  <TableCell className="text-right text-red-700 font-medium">{formatAmount(row.days_over_90)}</TableCell>
                  <TableCell className="text-right font-bold">{formatAmount(row.total_outstanding)}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* ページネーション */}
      {meta.total_pages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
          >
            <ChevronLeft className="size-4" />
          </Button>
          <span className="text-sm text-muted-foreground">
            {meta.current_page} / {meta.total_pages}
          </span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.min(meta.total_pages, p + 1))}
            disabled={page >= meta.total_pages}
          >
            <ChevronRight className="size-4" />
          </Button>
        </div>
      )}
    </div>
  );
}
