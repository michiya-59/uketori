"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Plus,
  Search,
  ChevronLeft,
  ChevronRight,
  FileText,
  Trash2,
  Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
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
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { api, ApiClientError } from "@/lib/api-client";
import type { DocumentType, DocumentStatus, PaymentStatus } from "@/types/document";

/** 帳票一覧の個別アイテム型 */
interface DocumentSummary {
  id: string;
  document_type: DocumentType;
  document_number: string;
  status: DocumentStatus;
  customer_name: string | null;
  title: string | null;
  total_amount: number;
  issue_date: string;
  due_date: string | null;
  payment_status: PaymentStatus | null;
  created_at: string;
}

/** 帳票一覧APIレスポンス型 */
interface DocumentsResponse {
  documents: DocumentSummary[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
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

/** 帳票タブ */
const DOC_TABS = [
  { value: "all", label: "すべて" },
  { value: "estimate", label: "見積書" },
  { value: "invoice", label: "請求書" },
  { value: "purchase_order", label: "発注書" },
  { value: "delivery_note", label: "納品書" },
  { value: "receipt", label: "領収書" },
];

/**
 * 帳票一覧ページ
 * 帳票の検索、タイプ別タブ表示、フィルタリングを提供する
 * @returns 帳票一覧ページ要素
 */
export default function DocumentsPage() {
  const router = useRouter();
  const [documents, setDocuments] = useState<DocumentSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  /**
   * 帳票一覧を取得する
   * @param page - ページ番号
   */
  const loadDocuments = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const params: Record<string, string | number> = { page };
        if (activeTab !== "all") params["filter[document_type]"] = activeTab;
        if (statusFilter !== "all") params["filter[status]"] = statusFilter;

        const res = await api.get<DocumentsResponse>("/api/v1/documents", params);
        setDocuments(res.documents);
        setCurrentPage(res.meta.current_page);
        setTotalPages(res.meta.total_pages);
        setTotalCount(res.meta.total_count);
      } catch (e) {
        if (e instanceof ApiClientError) {
          toast.error(e.body?.error?.message ?? "帳票一覧の取得に失敗しました");
        }
      } finally {
        setLoading(false);
      }
    },
    [activeTab, statusFilter]
  );

  useEffect(() => {
    loadDocuments(1);
  }, [loadDocuments]);

  /**
   * 日付を表示用にフォーマットする
   * @param dateStr - ISO日付文字列
   * @returns フォーマットされた日付
   */
  const formatDate = (dateStr: string | null): string => {
    if (!dateStr) return "-";
    return new Date(dateStr).toLocaleDateString("ja-JP");
  };

  /**
   * 個別の帳票の選択状態を切り替える
   * @param id - 帳票ID
   */
  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  /**
   * 全件の選択状態を切り替える
   */
  const toggleSelectAll = () => {
    if (selectedIds.size === documents.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(documents.map((d) => d.id)));
    }
  };

  /**
   * 選択された帳票を一括削除する
   */
  const handleBulkDelete = async () => {
    try {
      setDeleting(true);
      await Promise.all(
        Array.from(selectedIds).map((id) => api.delete(`/api/v1/documents/${id}`))
      );
      toast.success(`${selectedIds.size}件の帳票を削除しました`);
      setSelectedIds(new Set());
      setDeleteOpen(false);
      loadDocuments(currentPage);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "削除に失敗しました");
      }
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">帳票管理</h1>
          <p className="mt-1 text-muted-foreground">
            見積書・請求書等の作成・管理を行います
          </p>
        </div>
        <div className="flex items-center gap-2 self-start sm:self-auto">
          {selectedIds.size > 0 && (
            <Button
              variant="destructive"
              onClick={() => setDeleteOpen(true)}
            >
              <Trash2 className="mr-2 size-4" />
              {selectedIds.size}件を削除
            </Button>
          )}
          <Button asChild>
            <Link href="/documents/new">
              <Plus className="mr-2 size-4" />
              新規作成
            </Link>
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <TabsList className="w-full sm:w-auto overflow-x-auto">
            {DOC_TABS.map((tab) => (
              <TabsTrigger key={tab.value} value={tab.value}>
                {tab.label}
              </TabsTrigger>
            ))}
          </TabsList>
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-full sm:w-[140px] h-9">
              <SelectValue placeholder="ステータス" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">すべて</SelectItem>
              <SelectItem value="draft">下書き</SelectItem>
              <SelectItem value="approved">承認済</SelectItem>
              <SelectItem value="sent">送信済</SelectItem>
              <SelectItem value="locked">確定</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {DOC_TABS.map((tab) => (
          <TabsContent key={tab.value} value={tab.value}>
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-16 w-full" />
                ))}
              </div>
            ) : documents.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 text-center">
                <FileText className="size-12 text-muted-foreground/50 mb-4" />
                <p className="text-lg font-medium text-muted-foreground">
                  帳票がありません
                </p>
                <p className="mt-1 text-sm text-muted-foreground/70">
                  「新規作成」ボタンから帳票を作成してください
                </p>
              </div>
            ) : (
              <>
                <div className="overflow-x-auto rounded-md border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="w-10">
                          <Checkbox
                            checked={documents.length > 0 && selectedIds.size === documents.length}
                            onCheckedChange={toggleSelectAll}
                          />
                        </TableHead>
                        <TableHead>帳票番号</TableHead>
                        <TableHead>種別</TableHead>
                        <TableHead>顧客名</TableHead>
                        <TableHead>タイトル</TableHead>
                        <TableHead>ステータス</TableHead>
                        <TableHead>発行日</TableHead>
                        <TableHead className="text-right">合計金額</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {documents.map((doc) => (
                        <TableRow
                          key={doc.id}
                          className="cursor-pointer"
                          data-state={selectedIds.has(doc.id) ? "selected" : undefined}
                          onClick={() => router.push(`/documents/${doc.id}`)}
                        >
                          <TableCell onClick={(e) => e.stopPropagation()}>
                            <Checkbox
                              checked={selectedIds.has(doc.id)}
                              onCheckedChange={() => toggleSelect(doc.id)}
                            />
                          </TableCell>
                          <TableCell className="font-mono text-sm">
                            {doc.document_number}
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline" className="text-xs">
                              {DOC_TYPE_LABELS[doc.document_type] ?? doc.document_type}
                            </Badge>
                          </TableCell>
                          <TableCell>{doc.customer_name ?? "-"}</TableCell>
                          <TableCell className="max-w-[200px] truncate">
                            {doc.title ?? "-"}
                          </TableCell>
                          <TableCell>
                            <Badge variant={STATUS_VARIANTS[doc.status] ?? "outline"}>
                              {STATUS_LABELS[doc.status] ?? doc.status}
                            </Badge>
                            {doc.payment_status && doc.document_type === "invoice" && (
                              <Badge
                                variant={doc.payment_status === "paid" ? "default" : "outline"}
                                className="ml-1 text-xs"
                              >
                                {PAYMENT_STATUS_LABELS[doc.payment_status] ?? doc.payment_status}
                              </Badge>
                            )}
                          </TableCell>
                          <TableCell className="text-sm">
                            {formatDate(doc.issue_date)}
                          </TableCell>
                          <TableCell className="text-right tabular-nums font-medium">
                            ¥{doc.total_amount.toLocaleString()}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>

                <div className="flex items-center justify-between pt-2">
                  <p className="text-sm text-muted-foreground">
                    全{totalCount}件中 {(currentPage - 1) * 25 + 1}-
                    {Math.min(currentPage * 25, totalCount)}件
                  </p>
                  <div className="flex items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => loadDocuments(currentPage - 1)}
                      disabled={currentPage <= 1}
                    >
                      <ChevronLeft className="size-4" />
                    </Button>
                    <span className="text-sm">
                      {currentPage} / {totalPages}
                    </span>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => loadDocuments(currentPage + 1)}
                      disabled={currentPage >= totalPages}
                    >
                      <ChevronRight className="size-4" />
                    </Button>
                  </div>
                </div>
              </>
            )}
          </TabsContent>
        ))}
      </Tabs>

      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>帳票の一括削除</DialogTitle>
            <DialogDescription>
              {selectedIds.size}件の帳票を削除します。この操作は取り消せません。
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteOpen(false)}>
              キャンセル
            </Button>
            <Button
              variant="destructive"
              onClick={handleBulkDelete}
              disabled={deleting}
            >
              {deleting && <Loader2 className="mr-2 size-4 animate-spin" />}
              削除する
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
