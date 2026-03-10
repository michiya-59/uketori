"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  Bell,
  Play,
  Settings,
  ChevronLeft,
  ChevronRight,
  CheckCircle2,
  XCircle,
  Clock,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { api, ApiClientError } from "@/lib/api-client";
import { Tenant } from "@/types/tenant";
import type { DunningRule, DunningLog } from "@/types/dunning";

/** 督促ルール一覧レスポンス */
interface RulesResponse {
  rules: DunningRule[];
}

/** 督促ログ一覧レスポンス */
interface LogsResponse {
  logs: DunningLogItem[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** 督促ログ表示用型 */
interface DunningLogItem extends DunningLog {
  customer_name?: string;
  document_number?: string;
  rule_name?: string;
}

/** 督促実行結果レスポンス */
interface ExecuteResponse {
  sent: number;
  skipped: number;
  failed: number;
}

/** アクション種別ラベル */
const ACTION_LABELS: Record<string, string> = {
  email: "メール",
  internal_alert: "社内通知",
  both: "メール＋通知",
};

/** ログステータスラベル */
const STATUS_LABELS: Record<string, string> = {
  sent: "送信済",
  failed: "失敗",
  opened: "開封済",
  clicked: "クリック済",
};

/**
 * 金額をフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatAmount(amount: number): string {
  return `¥${amount.toLocaleString()}`;
}

/**
 * 督促管理ページ
 * 督促ルール一覧、督促履歴の確認、手動実行を行う
 */
export default function DunningPage() {
  const [rules, setRules] = useState<DunningRule[]>([]);
  const [logs, setLogs] = useState<DunningLogItem[]>([]);
  const [logMeta, setLogMeta] = useState({ current_page: 1, total_pages: 1, total_count: 0, per_page: 25 });
  const [loadingRules, setLoadingRules] = useState(true);
  const [loadingLogs, setLoadingLogs] = useState(true);
  const [logPage, setLogPage] = useState(1);

  // プラン制限
  const [tenantPlan, setTenantPlan] = useState<string | null>(null);
  const isFreePlan = tenantPlan === "free";

  useEffect(() => {
    api.get<{ tenant: Tenant }>("/api/v1/tenant")
      .then((data) => setTenantPlan(data.tenant.plan))
      .catch(() => {});
  }, []);

  // 手動実行
  const [executeOpen, setExecuteOpen] = useState(false);
  const [executing, setExecuting] = useState(false);

  /**
   * 督促ルール一覧を取得する
   */
  const fetchRules = useCallback(async () => {
    setLoadingRules(true);
    try {
      const data = await api.get<RulesResponse>("/api/v1/dunning/rules");
      setRules(data.rules);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("督促ルールの取得に失敗しました");
      }
    } finally {
      setLoadingRules(false);
    }
  }, []);

  /**
   * 督促ログ一覧を取得する
   */
  const fetchLogs = useCallback(async () => {
    setLoadingLogs(true);
    try {
      const data = await api.get<LogsResponse>("/api/v1/dunning/logs", {
        page: logPage.toString(),
      });
      setLogs(data.logs);
      setLogMeta(data.meta);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("督促履歴の取得に失敗しました");
      }
    } finally {
      setLoadingLogs(false);
    }
  }, [logPage]);

  useEffect(() => {
    fetchRules();
  }, [fetchRules]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  /**
   * 督促を手動実行する
   */
  const handleExecute = async () => {
    setExecuting(true);
    try {
      const result = await api.post<ExecuteResponse>("/api/v1/dunning/execute", {});
      toast.success(
        `督促実行完了: 送信${result.sent}件 / スキップ${result.skipped}件 / 失敗${result.failed}件`
      );
      setExecuteOpen(false);
      fetchLogs();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "督促実行に失敗しました");
      }
    } finally {
      setExecuting(false);
    }
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      {/* ヘッダー */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight">督促管理</h1>
          <p className="text-sm text-muted-foreground">
            督促ルールの管理と実行履歴を確認できます
          </p>
        </div>
        <div className="flex gap-2 self-start sm:self-auto">
          <Button variant="outline" size="sm" asChild>
            <Link href="/settings/dunning">
              <Settings className="mr-1.5 size-3.5" />
              ルール設定
            </Link>
          </Button>
          <Button size="sm" onClick={() => setExecuteOpen(true)} disabled={isFreePlan}>
            <Play className="mr-1.5 size-3.5" />
            手動実行
          </Button>
        </div>
      </div>

      {/* フリープラン制限 */}
      {isFreePlan && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 dark:border-red-900 dark:bg-red-950/30">
          <p className="text-sm font-medium text-red-700 dark:text-red-400">
            Freeプランでは自動督促機能をご利用いただけません
          </p>
          <p className="mt-1 text-xs text-red-600 dark:text-red-500">
            Starter プラン以上にアップグレードすると、督促ルールの作成・自動実行が利用できます。
          </p>
          <Button
            variant="outline"
            size="sm"
            className="mt-2 border-red-300 text-red-700 hover:bg-red-100 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
            asChild
          >
            <Link href="/settings/billing">プランを確認する</Link>
          </Button>
        </div>
      )}

      {/* タブ */}
      <Tabs defaultValue="rules">
        <TabsList>
          <TabsTrigger value="rules">ルール一覧</TabsTrigger>
          <TabsTrigger value="logs">実行履歴</TabsTrigger>
        </TabsList>

        {/* ルール一覧タブ */}
        <TabsContent value="rules" className="mt-3 sm:mt-4">
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {loadingRules ? (
              Array.from({ length: 3 }).map((_, i) => (
                <Card key={i}>
                  <CardContent className="py-4">
                    <Skeleton className="h-5 w-32 mb-3" />
                    <Skeleton className="h-4 w-full" />
                  </CardContent>
                </Card>
              ))
            ) : rules.length === 0 ? (
              <div className="col-span-full py-8 text-center text-muted-foreground">
                <Bell className="mx-auto mb-2 size-8 opacity-50" />
                <p>督促ルールが設定されていません</p>
                <Button variant="outline" size="sm" className="mt-3" asChild>
                  <Link href="/settings/dunning">ルールを追加</Link>
                </Button>
              </div>
            ) : (
              rules.map((rule) => (
                <Card key={rule.id} className={`py-0 gap-0 ${!rule.is_active ? "opacity-60" : ""}`}>
                  <CardContent className="py-3 px-4">
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="font-semibold text-sm">{rule.name}</span>
                      <Badge variant={rule.is_active ? "default" : "secondary"} className="text-xs">
                        {rule.is_active ? "有効" : "無効"}
                      </Badge>
                    </div>
                    <div className="space-y-0.5 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">トリガー</span>
                        <span>期限超過 {rule.trigger_days_after_due}日後</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">アクション</span>
                        <span>{ACTION_LABELS[rule.action_type] || rule.action_type}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">最大回数</span>
                        <span>{rule.max_dunning_count}回（{rule.interval_days}日間隔）</span>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </TabsContent>

        {/* 実行履歴タブ */}
        <TabsContent value="logs" className="mt-3 sm:mt-4">
          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>実行日時</TableHead>
                  <TableHead>取引先</TableHead>
                  <TableHead>帳票番号</TableHead>
                  <TableHead className="text-right">未回収額</TableHead>
                  <TableHead className="text-center">遅延日数</TableHead>
                  <TableHead>アクション</TableHead>
                  <TableHead>ステータス</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {loadingLogs ? (
                  Array.from({ length: 5 }).map((_, i) => (
                    <TableRow key={i}>
                      {Array.from({ length: 7 }).map((_, j) => (
                        <TableCell key={j}>
                          <Skeleton className="h-4 w-full" />
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                ) : logs.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                      <Clock className="mx-auto mb-2 size-8 opacity-50" />
                      督促履歴がありません
                    </TableCell>
                  </TableRow>
                ) : (
                  logs.map((log) => (
                    <TableRow key={log.id}>
                      <TableCell className="whitespace-nowrap text-sm">
                        {new Date(log.created_at).toLocaleString("ja-JP", {
                          month: "2-digit",
                          day: "2-digit",
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </TableCell>
                      <TableCell>
                        {log.customer_uuid ? (
                          <Link
                            href={`/customers/${log.customer_uuid}`}
                            className="text-primary hover:underline"
                          >
                            {log.customer_name || log.customer_uuid}
                          </Link>
                        ) : (
                          "-"
                        )}
                      </TableCell>
                      <TableCell>
                        {log.document_uuid ? (
                          <Link
                            href={`/documents/${log.document_uuid}`}
                            className="text-primary hover:underline"
                          >
                            {log.document_number || log.document_uuid}
                          </Link>
                        ) : (
                          "-"
                        )}
                      </TableCell>
                      <TableCell className="text-right font-medium">
                        {formatAmount(log.remaining_amount)}
                      </TableCell>
                      <TableCell className="text-center">
                        <Badge variant="outline">{log.overdue_days}日</Badge>
                      </TableCell>
                      <TableCell>
                        {ACTION_LABELS[log.action_type] || log.action_type}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={log.status === "sent" ? "default" : log.status === "failed" ? "destructive" : "secondary"}
                        >
                          {log.status === "sent" && <CheckCircle2 className="mr-1 size-3" />}
                          {log.status === "failed" && <XCircle className="mr-1 size-3" />}
                          {STATUS_LABELS[log.status] || log.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>

          {/* ページネーション */}
          {logMeta.total_pages > 1 && (
            <div className="flex items-center justify-center gap-2 mt-4">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setLogPage((p) => Math.max(1, p - 1))}
                disabled={logPage <= 1}
              >
                <ChevronLeft className="size-4" />
              </Button>
              <span className="text-sm text-muted-foreground">
                {logMeta.current_page} / {logMeta.total_pages}
              </span>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setLogPage((p) => Math.min(logMeta.total_pages, p + 1))}
                disabled={logPage >= logMeta.total_pages}
              >
                <ChevronRight className="size-4" />
              </Button>
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* 手動実行確認ダイアログ */}
      <AlertDialog open={executeOpen} onOpenChange={setExecuteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>督促を手動実行</AlertDialogTitle>
            <AlertDialogDescription>
              有効な督促ルールに基づいて、期限超過の請求書に対する督促を実行します。
              条件に合致する顧客にメールが送信されます。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction onClick={handleExecute} disabled={executing}>
              {executing ? "実行中..." : "実行する"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
