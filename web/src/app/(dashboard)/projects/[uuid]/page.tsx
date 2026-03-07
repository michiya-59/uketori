"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  Pencil,
  Trash2,
  FolderKanban,
  FileText,
  Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { api, ApiClientError } from "@/lib/api-client";
import type { Project, ProjectStatus } from "@/types/project";

/** ステータスラベルマッピング */
const STATUS_LABELS: Record<ProjectStatus, string> = {
  negotiation: "商談中",
  won: "受注",
  lost: "失注",
  in_progress: "進行中",
  delivered: "納品済",
  invoiced: "請求済",
  paid: "入金完了",
  partially_paid: "一部入金",
  overdue: "支払遅延",
  bad_debt: "貸倒",
  cancelled: "キャンセル",
};

/** ステータスのBadgeカラー */
const STATUS_VARIANT: Record<ProjectStatus, "default" | "secondary" | "destructive" | "outline"> = {
  negotiation: "outline",
  won: "default",
  lost: "destructive",
  in_progress: "default",
  delivered: "secondary",
  invoiced: "secondary",
  paid: "default",
  partially_paid: "outline",
  overdue: "destructive",
  bad_debt: "destructive",
  cancelled: "secondary",
};

/** ステータス遷移マップ */
const TRANSITIONS: Record<string, string[]> = {
  negotiation: ["won", "lost"],
  won: ["in_progress", "cancelled"],
  in_progress: ["delivered", "cancelled"],
  delivered: ["invoiced"],
  invoiced: ["paid", "partially_paid", "overdue"],
  partially_paid: ["paid", "overdue"],
  overdue: ["paid", "partially_paid", "bad_debt"],
  bad_debt: ["paid"],
  lost: ["negotiation"],
  cancelled: [],
  paid: [],
};

/** 帳票種別ラベル */
const DOC_TYPE_LABELS: Record<string, string> = {
  estimate: "見積書",
  invoice: "請求書",
  purchase_order: "発注書",
  order_confirmation: "注文請書",
  delivery_note: "納品書",
  receipt: "領収書",
};

/** 帳票サマリー型 */
interface DocumentSummary {
  id: string;
  document_type: string;
  document_number: string;
  status: string;
  total_amount: number | null;
  issue_date: string | null;
  due_date: string | null;
  payment_status: string | null;
}

/** 帳票一覧レスポンス型 */
interface DocumentsResponse {
  documents: DocumentSummary[];
  meta: { total_count: number };
}

/**
 * 案件詳細ページ
 * 案件情報の閲覧・編集・削除・ステータス遷移を提供する
 * @returns 案件詳細ページ要素
 */
export default function ProjectDetailPage() {
  const params = useParams();
  const router = useRouter();
  const uuid = params.uuid as string;
  const [project, setProject] = useState<Project | null>(null);
  const [documents, setDocuments] = useState<DocumentSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [transitioning, setTransitioning] = useState<string | null>(null);

  /** 案件詳細を取得する */
  const loadProject = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ project: Project }>(
        `/api/v1/projects/${uuid}`
      );
      setProject(res.project);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "案件情報の取得に失敗しました");
      }
      router.push("/projects");
    } finally {
      setLoading(false);
    }
  }, [uuid, router]);

  /** 関連帳票を取得する */
  const loadDocuments = useCallback(async () => {
    try {
      const res = await api.get<DocumentsResponse>(
        `/api/v1/projects/${uuid}/documents`
      );
      setDocuments(res.documents);
    } catch {
      // silently fail for documents
    }
  }, [uuid]);

  useEffect(() => {
    loadProject();
    loadDocuments();
  }, [loadProject, loadDocuments]);

  /** 案件を削除する */
  const handleDelete = async () => {
    try {
      setDeleting(true);
      await api.delete(`/api/v1/projects/${uuid}`);
      toast.success("案件を削除しました");
      router.push("/projects");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "削除に失敗しました");
      }
    } finally {
      setDeleting(false);
      setDeleteOpen(false);
    }
  };

  /**
   * ステータスを遷移させる
   * @param newStatus - 遷移先ステータス
   */
  const handleTransition = async (newStatus: string) => {
    try {
      setTransitioning(newStatus);
      const res = await api.patch<{ project: Project }>(
        `/api/v1/projects/${uuid}/status`,
        { status: newStatus }
      );
      setProject(res.project);
      toast.success(`ステータスを「${STATUS_LABELS[newStatus as ProjectStatus] ?? newStatus}」に変更しました`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "ステータスの変更に失敗しました");
      }
    } finally {
      setTransitioning(null);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  if (!project) return null;

  const allowedTransitions = TRANSITIONS[project.status] ?? [];

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" asChild className="mt-1 shrink-0 size-10 sm:size-9">
          <Link href="/projects">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div className="min-w-0 flex-1">
          <p className="text-sm text-muted-foreground">
            {project.project_number}
          </p>
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight break-words">
            {project.name}
          </h1>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <Badge variant={STATUS_VARIANT[project.status]}>
              {STATUS_LABELS[project.status] ?? project.status}
            </Badge>
            {project.customer_name && (
              <span className="text-sm text-muted-foreground">
                {project.customer_name}
              </span>
            )}
          </div>
          {/* アクションボタン */}
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button variant="outline" size="sm" asChild>
              <Link href={`/projects/${uuid}/edit`}>
                <Pencil className="mr-1.5 size-3.5" />
                編集
              </Link>
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
                  <DialogTitle>案件を削除</DialogTitle>
                  <DialogDescription>
                    「{project.name}」を削除します。この操作は取り消せません。
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setDeleteOpen(false)}>
                    キャンセル
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={handleDelete}
                    disabled={deleting}
                  >
                    {deleting && <Loader2 className="mr-2 size-4 animate-spin" />}
                    削除する
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </div>

      {/* ステータス遷移ボタン */}
      {allowedTransitions.length > 0 && (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm text-muted-foreground mr-1">ステータス変更:</span>
          {allowedTransitions.map((status) => (
            <Button
              key={status}
              variant="outline"
              size="sm"
              onClick={() => handleTransition(status)}
              disabled={transitioning !== null}
            >
              {transitioning === status && (
                <Loader2 className="mr-1.5 size-3 animate-spin" />
              )}
              {STATUS_LABELS[status as ProjectStatus] ?? status}
            </Button>
          ))}
        </div>
      )}

      {/* 案件情報 + 関連帳票 */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* SP: 案件情報を先に表示 → 帳票は後 */}
        <div className="order-1 lg:order-2 space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <FolderKanban className="size-5" />
                案件情報
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <InfoRow label="案件番号" value={project.project_number} />
              <InfoRow label="案件名" value={project.name} />
              {project.customer_name && (
                <InfoRow label="顧客" value={project.customer_name} />
              )}
              {project.assigned_user_name && (
                <InfoRow label="担当者" value={project.assigned_user_name} />
              )}
              {project.amount != null && (
                <InfoRow
                  label="見込金額"
                  value={`¥${project.amount.toLocaleString()}`}
                />
              )}
              {project.cost != null && (
                <InfoRow
                  label="原価"
                  value={`¥${project.cost.toLocaleString()}`}
                />
              )}
              {project.probability != null && (
                <InfoRow label="受注確度" value={`${project.probability}%`} />
              )}
              {project.start_date && (
                <InfoRow label="開始日" value={project.start_date} />
              )}
              {project.end_date && (
                <InfoRow label="終了日" value={project.end_date} />
              )}
            </CardContent>
          </Card>

          {project.description && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">説明</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="whitespace-pre-wrap text-[15px]">
                  {project.description}
                </p>
              </CardContent>
            </Card>
          )}
        </div>

        <div className="order-2 lg:order-1 lg:col-span-2 min-w-0">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <FileText className="size-5" />
                関連帳票
              </CardTitle>
            </CardHeader>
            <CardContent>
              {documents.length === 0 ? (
                <p className="text-muted-foreground py-4 text-center">
                  関連する帳票はありません
                </p>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>帳票番号</TableHead>
                        <TableHead>種別</TableHead>
                        <TableHead>ステータス</TableHead>
                        <TableHead className="text-right">金額</TableHead>
                        <TableHead>発行日</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {documents.map((doc) => (
                        <TableRow
                          key={doc.id}
                          className="cursor-pointer"
                          onClick={() => router.push(`/documents/${doc.id}`)}
                        >
                          <TableCell className="font-medium">
                            {doc.document_number}
                          </TableCell>
                          <TableCell>
                            {DOC_TYPE_LABELS[doc.document_type] ?? doc.document_type}
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline">{doc.status}</Badge>
                          </TableCell>
                          <TableCell className="text-right tabular-nums">
                            {doc.total_amount != null
                              ? `¥${doc.total_amount.toLocaleString()}`
                              : "-"}
                          </TableCell>
                          <TableCell>{doc.issue_date ?? "-"}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

/**
 * 情報行を表示するコンポーネント
 * @param label - ラベル
 * @param value - 値
 * @returns 情報行要素
 */
function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-[15px]">{value}</p>
    </div>
  );
}
