"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  Pencil,
  Trash2,
  Copy,
  CheckCircle,
  Send,
  Lock,
  Loader2,
  FileText,
  History,
  Download,
  Mail,
  ArrowRightLeft,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  TableFooter,
} from "@/components/ui/table";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api, ApiClientError } from "@/lib/api-client";
import type { DocumentType, DocumentStatus, DocumentItem } from "@/types/document";
import type { Tenant, TenantPlan } from "@/types/tenant";

/** 帳票詳細APIレスポンスの型 */
interface DocumentDetail {
  id: string;
  document_type: DocumentType;
  document_number: string;
  status: DocumentStatus;
  customer_id: string | null;
  customer_name: string | null;
  title: string | null;
  issue_date: string;
  due_date: string | null;
  valid_until: string | null;
  subtotal_amount: number;
  tax_amount: number;
  total_amount: number;
  tax_summary: { rate: number; subtotal: number; tax: number }[];
  remaining_amount: number;
  paid_amount: number;
  notes: string | null;
  internal_memo: string | null;
  payment_status: string | null;
  sent_at: string | null;
  locked_at: string | null;
  version: number;
  items: DocumentItem[];
  created_at: string;
  updated_at: string;
}

/** バージョン情報型 */
interface DocumentVersion {
  id: number;
  version: number;
  change_reason: string;
  changed_by: string | null;
  created_at: string;
}

/** 帳票種別ラベル */
const DOC_TYPE_LABELS: Record<string, string> = {
  estimate: "見積書",
  purchase_order: "発注書",
  order_confirmation: "注文請書",
  delivery_note: "納品書",
  invoice: "請求書",
  receipt: "領収書",
};

/** ステータスラベル */
const STATUS_LABELS: Record<string, string> = {
  draft: "下書き",
  approved: "承認済",
  sent: "送信済",
  accepted: "受領済",
  rejected: "差戻",
  cancelled: "取消",
  locked: "確定",
};

/** ステータスバッジのvariant */
const STATUS_VARIANTS: Record<string, "default" | "secondary" | "outline" | "destructive"> = {
  draft: "outline",
  approved: "secondary",
  sent: "default",
  accepted: "default",
  rejected: "destructive",
  cancelled: "destructive",
  locked: "secondary",
};

/** 入金ステータスラベル */
const PAYMENT_STATUS_LABELS: Record<string, string> = {
  unpaid: "未入金",
  partial: "一部入金",
  paid: "入金済",
  overdue: "期限超過",
  bad_debt: "貸倒",
};

/** プラン別月間帳票上限 */
const PLAN_DOCUMENT_LIMITS: Record<TenantPlan, number | null> = {
  free: 5,
  starter: 50,
  standard: null,
  professional: null,
};

/** 変換先オプション */
const CONVERSION_OPTIONS: Record<string, { value: string; label: string }[]> = {
  estimate: [
    { value: "invoice", label: "請求書" },
    { value: "purchase_order", label: "発注書" },
  ],
  purchase_order: [
    { value: "delivery_note", label: "納品書" },
    { value: "invoice", label: "請求書" },
  ],
  invoice: [{ value: "receipt", label: "領収書" }],
};

/**
 * 帳票詳細ページ
 * 帳票の閲覧・ステータス操作・PDF・メール送信・変換・複製・削除を提供する
 * @returns 帳票詳細ページ要素
 */
export default function DocumentDetailPage() {
  const params = useParams();
  const router = useRouter();
  const uuid = params.uuid as string;
  const [doc, setDoc] = useState<DocumentDetail | null>(null);
  const [versions, setVersions] = useState<DocumentVersion[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [showVersions, setShowVersions] = useState(false);
  const [emailOpen, setEmailOpen] = useState(false);
  const [emailTo, setEmailTo] = useState("");
  const [emailSubject, setEmailSubject] = useState("");
  const [emailBody, setEmailBody] = useState("");
  const [convertOpen, setConvertOpen] = useState(false);
  const [convertTarget, setConvertTarget] = useState("");
  const [pdfLoading, setPdfLoading] = useState(false);
  const [isLimitReached, setIsLimitReached] = useState(false);

  /** 帳票詳細を取得する */
  const loadDocument = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ document: DocumentDetail }>(
        `/api/v1/documents/${uuid}`
      );
      setDoc(res.document);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "帳票の取得に失敗しました");
      }
      router.push("/documents");
    } finally {
      setLoading(false);
    }
  }, [uuid, router]);

  useEffect(() => {
    loadDocument();
  }, [loadDocument]);

  /** プラン制限を確認する */
  useEffect(() => {
    const checkLimit = async () => {
      try {
        const tenantRes = await api.get<{ tenant: Tenant }>("/api/v1/tenant");
        const plan = tenantRes.tenant.plan;
        const limit = PLAN_DOCUMENT_LIMITS[plan];
        if (limit === null) return;

        const now = new Date();
        const from = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
        const to = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()).padStart(2, "0")}`;
        const docsRes = await api.get<{ meta: { total_count: number } }>("/api/v1/documents", {
          "filter[issue_date_from]": from,
          "filter[issue_date_to]": to,
          per_page: 1,
        });
        setIsLimitReached(docsRes.meta.total_count >= limit);
      } catch {
        // ignore
      }
    };
    checkLimit();
  }, []);

  /** バージョン履歴を取得する */
  const loadVersions = async () => {
    try {
      const res = await api.get<{ versions: DocumentVersion[] }>(
        `/api/v1/documents/${uuid}/versions`
      );
      setVersions(res.versions);
      setShowVersions(true);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("バージョン履歴の取得に失敗しました");
      }
    }
  };

  /**
   * ステータスアクションを実行する
   * @param action - アクション名
   * @param label - 表示用ラベル
   * @param body - リクエストボディ
   */
  const performAction = async (action: string, label: string, body?: Record<string, string>) => {
    try {
      setActionLoading(true);
      await api.post(`/api/v1/documents/${uuid}/${action}`, body);
      toast.success(`${label}しました`);
      await loadDocument();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? `${label}に失敗しました`);
      }
    } finally {
      setActionLoading(false);
    }
  };

  /** PDFをダウンロードする */
  const handlePdfDownload = async () => {
    try {
      setPdfLoading(true);
      const res = await api.get<{ pdf_url: string }>(
        `/api/v1/documents/${uuid}/pdf`
      );
      if (res.pdf_url) {
        window.open(res.pdf_url, "_blank");
      }
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "PDFの取得に失敗しました");
      }
    } finally {
      setPdfLoading(false);
    }
  };

  /** メールを送信する */
  const handleSendEmail = async () => {
    if (!emailTo) {
      toast.error("送信先メールアドレスを入力してください");
      return;
    }
    try {
      setActionLoading(true);
      await api.post(`/api/v1/documents/${uuid}/send_document`, {
        method: "email",
        recipient_email: emailTo,
        email_subject: emailSubject || undefined,
        email_body: emailBody || undefined,
      });
      toast.success("メールを送信しました");
      setEmailOpen(false);
      setEmailTo("");
      setEmailSubject("");
      setEmailBody("");
      await loadDocument();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "送信に失敗しました");
      }
    } finally {
      setActionLoading(false);
    }
  };

  /** 帳票を変換する */
  const handleConvert = async () => {
    if (!convertTarget) {
      toast.error("変換先を選択してください");
      return;
    }
    try {
      setActionLoading(true);
      const res = await api.post<{ document: DocumentDetail }>(
        `/api/v1/documents/${uuid}/convert`,
        { target_type: convertTarget }
      );
      toast.success(
        `${DOC_TYPE_LABELS[convertTarget] ?? convertTarget}に変換しました`
      );
      setConvertOpen(false);
      router.push(`/documents/${res.document.id}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "変換に失敗しました");
      }
    } finally {
      setActionLoading(false);
    }
  };

  /** 帳票を複製する */
  const handleDuplicate = async () => {
    try {
      setActionLoading(true);
      const res = await api.post<{ document: DocumentDetail }>(
        `/api/v1/documents/${uuid}/duplicate`
      );
      toast.success("帳票を複製しました");
      router.push(`/documents/${res.document.id}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "複製に失敗しました");
      }
    } finally {
      setActionLoading(false);
    }
  };

  /** 帳票を削除する */
  const handleDelete = async () => {
    try {
      setActionLoading(true);
      await api.delete(`/api/v1/documents/${uuid}`);
      toast.success("帳票を削除しました");
      router.push("/documents");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "削除に失敗しました");
      }
    } finally {
      setActionLoading(false);
      setDeleteOpen(false);
    }
  };

  /**
   * 日付をフォーマットする
   * @param dateStr - ISO日付文字列
   * @returns フォーマットされた日付
   */
  const formatDate = (dateStr: string | null): string => {
    if (!dateStr) return "-";
    return new Date(dateStr).toLocaleDateString("ja-JP");
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }

  if (!doc) return null;

  const conversionOptions = CONVERSION_OPTIONS[doc.document_type];

  return (
    <div className="space-y-6 overflow-hidden">
      {/* ヘッダー */}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" asChild className="mt-1 shrink-0 size-10 sm:size-9">
          <Link href="/documents">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div className="min-w-0 flex-1">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight break-words">
            {doc.document_number}
          </h1>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <Badge variant="outline">
              {DOC_TYPE_LABELS[doc.document_type] ?? doc.document_type}
            </Badge>
            <Badge variant={STATUS_VARIANTS[doc.status] ?? "outline"}>
              {STATUS_LABELS[doc.status] ?? doc.status}
            </Badge>
          </div>
          {doc.title && (
            <p className="mt-1 text-sm text-muted-foreground break-words">{doc.title}</p>
          )}

          {/* アクションボタン */}
          <div className="mt-3 flex flex-wrap items-center gap-2">
            {/* PDF */}
            <Button
              variant="outline"
              size="sm"
              onClick={handlePdfDownload}
              disabled={pdfLoading}
            >
              {pdfLoading ? (
                <Loader2 className="mr-1.5 size-3.5 animate-spin" />
              ) : (
                <Download className="mr-1.5 size-3.5" />
              )}
              PDF
            </Button>

            {/* ステータス操作 */}
            {doc.status === "draft" && (
              <>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => performAction("approve", "承認")}
                  disabled={actionLoading}
                >
                  <CheckCircle className="mr-1.5 size-3.5" />
                  承認
                </Button>
                <Button variant="outline" size="sm" asChild>
                  <Link href={`/documents/${uuid}/edit`}>
                    <Pencil className="mr-1.5 size-3.5" />
                    編集
                  </Link>
                </Button>
              </>
            )}

            {doc.status === "approved" && (
              <Dialog open={emailOpen} onOpenChange={setEmailOpen}>
                <DialogTrigger asChild>
                  <Button variant="outline" size="sm">
                    <Mail className="mr-1.5 size-3.5" />
                    メール送信
                  </Button>
                </DialogTrigger>
                <DialogContent className="sm:max-w-[480px]">
                  <DialogHeader>
                    <DialogTitle>帳票をメール送信</DialogTitle>
                    <DialogDescription>
                      {doc.document_number}をメールで送信します。PDFが自動的に添付されます。
                    </DialogDescription>
                  </DialogHeader>
                  <div className="space-y-4 py-2">
                    <div className="space-y-2">
                      <Label className="text-[15px]">
                        送信先 <span className="text-destructive">*</span>
                      </Label>
                      <Input
                        type="email"
                        value={emailTo}
                        onChange={(e) => setEmailTo(e.target.value)}
                        placeholder="customer@example.com"
                        className="h-11 text-[15px]"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label className="text-[15px]">件名（任意）</Label>
                      <Input
                        value={emailSubject}
                        onChange={(e) => setEmailSubject(e.target.value)}
                        placeholder="自動生成されます"
                        className="h-11 text-[15px]"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label className="text-[15px]">本文（任意）</Label>
                      <textarea
                        value={emailBody}
                        onChange={(e) => setEmailBody(e.target.value)}
                        className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                        placeholder="追加メッセージ"
                      />
                    </div>
                  </div>
                  <DialogFooter>
                    <Button variant="outline" onClick={() => setEmailOpen(false)}>
                      キャンセル
                    </Button>
                    <Button onClick={handleSendEmail} disabled={actionLoading}>
                      {actionLoading && (
                        <Loader2 className="mr-2 size-4 animate-spin" />
                      )}
                      <Send className="mr-2 size-4" />
                      送信する
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            )}

            {doc.status === "sent" && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => performAction("lock", "ロック")}
                disabled={actionLoading}
              >
                <Lock className="mr-1.5 size-3.5" />
                確定
              </Button>
            )}

            {/* 変換 */}
            {conversionOptions && conversionOptions.length > 0 && (
              <Dialog open={convertOpen} onOpenChange={setConvertOpen}>
                <DialogTrigger asChild>
                  <Button variant="outline" size="sm" disabled={isLimitReached}>
                    <ArrowRightLeft className="mr-1.5 size-3.5" />
                    変換
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>帳票を変換</DialogTitle>
                    <DialogDescription>
                      {DOC_TYPE_LABELS[doc.document_type]}を別の帳票タイプに変換します。
                      元の帳票はそのまま残ります。
                    </DialogDescription>
                  </DialogHeader>
                  <div className="py-4">
                    <Label className="text-[15px]">変換先</Label>
                    <Select value={convertTarget} onValueChange={setConvertTarget}>
                      <SelectTrigger className="mt-2 h-11">
                        <SelectValue placeholder="変換先を選択" />
                      </SelectTrigger>
                      <SelectContent>
                        {conversionOptions.map((opt) => (
                          <SelectItem key={opt.value} value={opt.value}>
                            {opt.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <DialogFooter>
                    <Button
                      variant="outline"
                      onClick={() => setConvertOpen(false)}
                    >
                      キャンセル
                    </Button>
                    <Button onClick={handleConvert} disabled={actionLoading}>
                      {actionLoading && (
                        <Loader2 className="mr-2 size-4 animate-spin" />
                      )}
                      変換する
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            )}

            <Button
              variant="outline"
              size="sm"
              onClick={handleDuplicate}
              disabled={actionLoading || isLimitReached}
              title={isLimitReached ? "月間帳票数の上限に達しています" : undefined}
            >
              <Copy className="mr-1.5 size-3.5" />
              複製
            </Button>
            <Button variant="outline" size="sm" onClick={loadVersions}>
              <History className="mr-1.5 size-3.5" />
              履歴
            </Button>
            <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
              <DialogTrigger asChild>
                <Button variant="outline" size="sm" className="text-destructive">
                  <Trash2 className="mr-1.5 size-3.5" />
                  削除
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>帳票を削除</DialogTitle>
                  <DialogDescription>
                    「{doc.document_number}」を削除します。この操作は取り消せません。
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDeleteOpen(false)}>
                    キャンセル
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={handleDelete}
                    disabled={actionLoading}
                  >
                    {actionLoading && (
                      <Loader2 className="mr-2 size-4 animate-spin" />
                    )}
                    削除する
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* SP: 概要を先に表示 → 明細は後 */}
        <div className="order-2 lg:order-1 lg:col-span-2 min-w-0 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">明細</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-[40px]">#</TableHead>
                      <TableHead>品名</TableHead>
                      <TableHead className="text-right">数量</TableHead>
                      <TableHead className="text-right">単価</TableHead>
                      <TableHead className="text-right">税率</TableHead>
                      <TableHead className="text-right">金額</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {doc.items.map((item, idx) => (
                      <TableRow key={item.id}>
                        <TableCell className="text-muted-foreground">
                          {idx + 1}
                        </TableCell>
                        <TableCell>
                          <p className="font-medium">{item.name}</p>
                          {item.description && (
                            <p className="text-sm text-muted-foreground">
                              {item.description}
                            </p>
                          )}
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {item.quantity}
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          ¥{item.unit_price.toLocaleString()}
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {item.tax_rate}%
                        </TableCell>
                        <TableCell className="text-right tabular-nums font-medium">
                          ¥{item.amount.toLocaleString()}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                  <TableFooter>
                    <TableRow>
                      <TableCell colSpan={5} className="text-right">
                        小計
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        ¥{doc.subtotal_amount.toLocaleString()}
                      </TableCell>
                    </TableRow>
                    {doc.tax_summary.map((ts) => (
                      <TableRow key={ts.rate}>
                        <TableCell colSpan={5} className="text-right">
                          消費税（{ts.rate}%）
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          ¥{ts.tax.toLocaleString()}
                        </TableCell>
                      </TableRow>
                    ))}
                    <TableRow>
                      <TableCell colSpan={5} className="text-right font-bold">
                        合計
                      </TableCell>
                      <TableCell className="text-right tabular-nums font-bold text-lg">
                        ¥{doc.total_amount.toLocaleString()}
                      </TableCell>
                    </TableRow>
                  </TableFooter>
                </Table>
              </div>
            </CardContent>
          </Card>

          {(doc.notes || doc.internal_memo) && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">備考</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {doc.notes && (
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">
                      備考（顧客表示）
                    </p>
                    <p className="whitespace-pre-wrap text-[15px]">
                      {doc.notes}
                    </p>
                  </div>
                )}
                {doc.internal_memo && (
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">
                      社内メモ
                    </p>
                    <p className="whitespace-pre-wrap text-[15px]">
                      {doc.internal_memo}
                    </p>
                  </div>
                )}
              </CardContent>
            </Card>
          )}
        </div>

        <div className="order-1 lg:order-2 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">概要</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <InfoRow label="顧客" value={doc.customer_name ?? "-"} />
              <InfoRow label="発行日" value={formatDate(doc.issue_date)} />
              {doc.due_date && (
                <InfoRow label="支払期限" value={formatDate(doc.due_date)} />
              )}
              {doc.valid_until && (
                <InfoRow label="有効期限" value={formatDate(doc.valid_until)} />
              )}
              <InfoRow label="バージョン" value={`v${doc.version}`} />
              {doc.sent_at && (
                <InfoRow label="送信日" value={formatDate(doc.sent_at)} />
              )}
              {doc.locked_at && (
                <InfoRow label="確定日" value={formatDate(doc.locked_at)} />
              )}
              <Separator />
              {doc.payment_status && (
                <InfoRow
                  label="入金状況"
                  value={
                    PAYMENT_STATUS_LABELS[doc.payment_status] ??
                    doc.payment_status
                  }
                />
              )}
              {doc.paid_amount > 0 && (
                <InfoRow
                  label="入金済"
                  value={`¥${doc.paid_amount.toLocaleString()}`}
                />
              )}
              {doc.remaining_amount > 0 && (
                <InfoRow
                  label="残額"
                  value={`¥${doc.remaining_amount.toLocaleString()}`}
                />
              )}
            </CardContent>
          </Card>

          {showVersions && versions.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">変更履歴</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {versions.map((v) => (
                    <div
                      key={v.id}
                      className="flex items-start justify-between text-sm"
                    >
                      <div>
                        <p className="font-medium">
                          v{v.version} - {v.change_reason}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {v.changed_by ?? "不明"} ・{" "}
                          {new Date(v.created_at).toLocaleString("ja-JP")}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * 情報行コンポーネント
 * @param label - ラベル
 * @param value - 値
 * @returns 情報行要素
 */
function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="text-[15px] font-medium">{value}</span>
    </div>
  );
}
