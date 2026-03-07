"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import {
  Plus,
  Search,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  Trash2,
  Upload,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { api, ApiClientError } from "@/lib/api-client";

/** APIレスポンスの入金レコード型 */
interface PaymentItem {
  id: string;
  document_uuid: string | null;
  document_number: string | null;
  customer_name: string | null;
  amount: number;
  payment_date: string;
  payment_method: string;
  matched_by: string;
  match_confidence: number | null;
  memo: string | null;
  recorded_by: string | null;
  created_at: string;
}

/** 入金一覧APIレスポンス型 */
interface PaymentsResponse {
  payments: PaymentItem[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** 請求書サマリー型 */
interface InvoiceSummary {
  id: string;
  document_number: string;
  customer_name: string | null;
  total_amount: number;
  remaining_amount: number;
  payment_status: string;
}

/** 請求書一覧APIレスポンス型 */
interface InvoicesResponse {
  documents: InvoiceSummary[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** 支払い方法のラベルマップ */
const PAYMENT_METHOD_LABELS: Record<string, string> = {
  bank_transfer: "銀行振込",
  cash: "現金",
  credit_card: "クレジットカード",
  other: "その他",
};

/** マッチング種別のラベルマップ */
const MATCH_TYPE_LABELS: Record<string, string> = {
  manual: "手動",
  ai_auto: "AI自動",
  ai_suggested: "AI提案",
};

/**
 * 金額を3桁カンマ区切りでフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatAmount(amount: number | undefined | null): string {
  return `¥${(amount ?? 0).toLocaleString()}`;
}

/**
 * 入金管理ページ
 * 入金記録の一覧表示・新規登録・削除を行う
 */
export default function PaymentsPage() {
  const [payments, setPayments] = useState<PaymentItem[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, total_pages: 1, total_count: 0, per_page: 25 });
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [methodFilter, setMethodFilter] = useState("all");

  // 新規入金ダイアログ
  const [createOpen, setCreateOpen] = useState(false);
  const [invoices, setInvoices] = useState<InvoiceSummary[]>([]);
  const [selectedInvoice, setSelectedInvoice] = useState("");
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split("T")[0]);
  const [paymentMethod, setPaymentMethod] = useState("bank_transfer");
  const [paymentMemo, setPaymentMemo] = useState("");
  const [creating, setCreating] = useState(false);

  // 削除ダイアログ
  const [deleteTarget, setDeleteTarget] = useState<PaymentItem | null>(null);
  const [deleting, setDeleting] = useState(false);

  /**
   * 入金一覧を取得する
   */
  const fetchPayments = useCallback(async () => {
    setLoading(true);
    try {
      const params: Record<string, string> = { page: page.toString() };
      if (methodFilter !== "all") {
        params["filter[payment_method]"] = methodFilter;
      }
      const data = await api.get<PaymentsResponse>("/api/v1/payments", params);
      setPayments(data.payments);
      setMeta(data.meta);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("入金一覧の取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, [page, methodFilter]);

  useEffect(() => {
    fetchPayments();
  }, [fetchPayments]);

  /**
   * 未払い請求書一覧を取得する（新規入金ダイアログ用）
   */
  const fetchInvoices = async () => {
    try {
      const data = await api.get<InvoicesResponse>("/api/v1/documents", {
        "filter[document_type]": "invoice",
        "filter[payment_status]": "unpaid,partial,overdue",
        per_page: "100",
      });
      setInvoices(data.documents);
    } catch {
      toast.error("請求書一覧の取得に失敗しました");
    }
  };

  /**
   * 入金を記録する
   */
  const handleCreate = async () => {
    const selected = invoices.find((inv) => inv.id === selectedInvoice);
    if (!selectedInvoice || !selected || !paymentDate) {
      toast.error("必須項目を入力してください");
      return;
    }
    setCreating(true);
    try {
      await api.post("/api/v1/payments", {
        document_uuid: selectedInvoice,
        payment: {
          amount: selected.remaining_amount || selected.total_amount,
          payment_date: paymentDate,
          payment_method: paymentMethod,
          matched_by: "manual",
          memo: paymentMemo || null,
        },
      });
      toast.success("入金を記録しました");
      setCreateOpen(false);
      resetForm();
      fetchPayments();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "入金の記録に失敗しました");
      }
    } finally {
      setCreating(false);
    }
  };

  /**
   * 入金記録を削除する
   */
  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.delete(`/api/v1/payments/${deleteTarget.id}`);
      toast.success("入金記録を削除しました");
      setDeleteTarget(null);
      fetchPayments();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "削除に失敗しました");
      }
    } finally {
      setDeleting(false);
    }
  };

  /**
   * フォームをリセットする
   */
  const resetForm = () => {
    setSelectedInvoice("");
    setPaymentDate(new Date().toISOString().split("T")[0]);
    setPaymentMethod("bank_transfer");
    setPaymentMemo("");
  };

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">入金管理</h1>
          <p className="text-sm text-muted-foreground">
            入金記録の一覧・登録・削除を管理します
          </p>
        </div>
        <div className="flex gap-2 self-start sm:self-auto">
          <Button variant="outline" asChild>
            <Link href="/payments/bank-import">
              <Upload className="mr-2 size-4" />
              銀行明細取込
            </Link>
          </Button>
          <Dialog
            open={createOpen}
            onOpenChange={(open) => {
              setCreateOpen(open);
              if (open) fetchInvoices();
            }}
          >
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 size-4" />
                入金記録
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-lg overflow-hidden">
              <DialogHeader>
                <DialogTitle>入金記録</DialogTitle>
                <DialogDescription>
                  請求書に対する入金を記録します
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-4 min-w-0">
                <div className="space-y-2 min-w-0">
                  <Label>請求書 *</Label>
                  <Select value={selectedInvoice} onValueChange={setSelectedInvoice}>
                    <SelectTrigger className="w-full truncate">
                      <SelectValue placeholder="請求書を選択" />
                    </SelectTrigger>
                    <SelectContent>
                      {invoices.map((inv) => (
                        <SelectItem key={inv.id} value={inv.id}>
                          <span className="block truncate">
                            {inv.document_number} - {inv.customer_name}
                          </span>
                          <span className="block text-xs text-muted-foreground">
                            残高: {formatAmount(inv.remaining_amount)}
                          </span>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                {selectedInvoice && (() => {
                  const selected = invoices.find((inv) => inv.id === selectedInvoice);
                  if (!selected) return null;
                  const amount = selected.remaining_amount || selected.total_amount;
                  return (
                    <div className="rounded-md border bg-muted/50 p-3">
                      <div className="flex justify-between items-center gap-2">
                        <span className="text-sm text-muted-foreground shrink-0">入金額</span>
                        <span className="text-lg font-bold text-primary tabular-nums">{formatAmount(amount)}</span>
                      </div>
                    </div>
                  );
                })()}
                <div className="space-y-2">
                  <Label>入金日 *</Label>
                  <Input
                    type="date"
                    value={paymentDate}
                    onChange={(e) => setPaymentDate(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label>支払方法</Label>
                  <Select value={paymentMethod} onValueChange={setPaymentMethod}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="bank_transfer">銀行振込</SelectItem>
                      <SelectItem value="cash">現金</SelectItem>
                      <SelectItem value="credit_card">クレジットカード</SelectItem>
                      <SelectItem value="other">その他</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>メモ</Label>
                  <Textarea
                    value={paymentMemo}
                    onChange={(e) => setPaymentMemo(e.target.value)}
                    placeholder="入金に関するメモ"
                    rows={2}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setCreateOpen(false)}>
                  キャンセル
                </Button>
                <Button onClick={handleCreate} disabled={creating}>
                  {creating ? "記録中..." : "入金を記録"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* フィルタ */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <Select value={methodFilter} onValueChange={(v) => { setMethodFilter(v); setPage(1); }}>
          <SelectTrigger className="w-full sm:w-[180px]">
            <SelectValue placeholder="支払方法" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">すべての方法</SelectItem>
            <SelectItem value="bank_transfer">銀行振込</SelectItem>
            <SelectItem value="cash">現金</SelectItem>
            <SelectItem value="credit_card">クレジットカード</SelectItem>
            <SelectItem value="other">その他</SelectItem>
          </SelectContent>
        </Select>
        <div className="ml-auto text-sm text-muted-foreground">
          全{meta.total_count}件
        </div>
      </div>

      {/* テーブル */}
      <div className="overflow-x-auto rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>入金日</TableHead>
              <TableHead>請求書番号</TableHead>
              <TableHead>顧客</TableHead>
              <TableHead className="text-right">金額</TableHead>
              <TableHead>方法</TableHead>
              <TableHead>マッチ</TableHead>
              <TableHead>記録者</TableHead>
              <TableHead className="w-[50px]" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 8 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton className="h-4 w-full" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : payments.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                  <CreditCard className="mx-auto mb-2 size-8 opacity-50" />
                  入金記録がありません
                </TableCell>
              </TableRow>
            ) : (
              payments.map((payment) => (
                <TableRow key={payment.id}>
                  <TableCell className="whitespace-nowrap">
                    {payment.payment_date}
                  </TableCell>
                  <TableCell>
                    {payment.document_uuid ? (
                      <Link
                        href={`/documents/${payment.document_uuid}`}
                        className="text-primary hover:underline"
                      >
                        {payment.document_number}
                      </Link>
                    ) : (
                      "-"
                    )}
                  </TableCell>
                  <TableCell>{payment.customer_name || "-"}</TableCell>
                  <TableCell className="text-right font-medium">
                    {formatAmount(payment.amount)}
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">
                      {PAYMENT_METHOD_LABELS[payment.payment_method] || payment.payment_method}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={payment.matched_by === "ai_auto" ? "default" : "secondary"}
                    >
                      {MATCH_TYPE_LABELS[payment.matched_by] || payment.matched_by}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm text-muted-foreground">
                    {payment.recorded_by || "-"}
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-8 text-destructive"
                      onClick={() => setDeleteTarget(payment)}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </TableCell>
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

      {/* 削除確認ダイアログ */}
      <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>入金記録を削除</AlertDialogTitle>
            <AlertDialogDescription>
              {deleteTarget && (
                <>
                  {deleteTarget.document_number} への入金 {formatAmount(deleteTarget.amount)} を削除しますか？
                  この操作は取り消せません。請求書の入金ステータスも自動的に更新されます。
                </>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {deleting ? "削除中..." : "削除する"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
