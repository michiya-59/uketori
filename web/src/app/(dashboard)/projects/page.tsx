"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Plus,
  Search,
  ChevronLeft,
  ChevronRight,
  FolderKanban,
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
import { api, ApiClientError } from "@/lib/api-client";
import type { Project, ProjectStatus } from "@/types/project";

/** 案件一覧APIレスポンス型 */
interface ProjectsResponse {
  projects: Project[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

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

/**
 * 案件一覧ページ
 * 案件の検索、フィルタリング、一覧表示を提供する
 * @returns 案件一覧ページ要素
 */
export default function ProjectsPage() {
  const router = useRouter();
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  /**
   * 案件一覧を取得する
   * @param page - ページ番号
   */
  const loadProjects = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const params: Record<string, string | number> = { page };
        if (searchQuery) params["filter[q]"] = searchQuery;
        if (statusFilter !== "all") params["filter[status]"] = statusFilter;

        const res = await api.get<ProjectsResponse>("/api/v1/projects", params);
        setProjects(res.projects);
        setCurrentPage(res.meta.current_page);
        setTotalPages(res.meta.total_pages);
        setTotalCount(res.meta.total_count);
      } catch (e) {
        if (e instanceof ApiClientError) {
          toast.error(e.body?.error?.message ?? "案件一覧の取得に失敗しました");
        }
      } finally {
        setLoading(false);
      }
    },
    [searchQuery, statusFilter]
  );

  useEffect(() => {
    loadProjects(1);
  }, [loadProjects]);

  /**
   * 検索フォームの送信を処理する
   * @param e - フォームイベント
   */
  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    loadProjects(1);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">案件管理</h1>
          <p className="mt-1 text-muted-foreground">
            案件の登録・進捗管理を行います
          </p>
        </div>
        <Button asChild className="self-start sm:self-auto">
          <Link href="/projects/new">
            <Plus className="mr-2 size-4" />
            新規登録
          </Link>
        </Button>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <form onSubmit={handleSearch} className="flex flex-1 items-center gap-2">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="案件名で検索..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-10 pl-9 text-[15px]"
            />
          </div>
          <Button type="submit" variant="secondary" size="sm">
            検索
          </Button>
        </form>
        <Select value={statusFilter} onValueChange={setStatusFilter}>
          <SelectTrigger className="w-full sm:w-[150px] h-10">
            <SelectValue placeholder="ステータス" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">すべて</SelectItem>
            <SelectItem value="negotiation">商談中</SelectItem>
            <SelectItem value="won">受注</SelectItem>
            <SelectItem value="in_progress">進行中</SelectItem>
            <SelectItem value="delivered">納品済</SelectItem>
            <SelectItem value="invoiced">請求済</SelectItem>
            <SelectItem value="paid">入金完了</SelectItem>
            <SelectItem value="overdue">支払遅延</SelectItem>
            <SelectItem value="lost">失注</SelectItem>
            <SelectItem value="cancelled">キャンセル</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : projects.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <FolderKanban className="size-12 text-muted-foreground/50 mb-4" />
          <p className="text-lg font-medium text-muted-foreground">
            案件が登録されていません
          </p>
          <p className="mt-1 text-sm text-muted-foreground/70">
            「新規登録」ボタンから案件を登録してください
          </p>
        </div>
      ) : (
        <>
          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>案件番号</TableHead>
                  <TableHead>案件名</TableHead>
                  <TableHead>顧客名</TableHead>
                  <TableHead>ステータス</TableHead>
                  <TableHead className="text-right">金額</TableHead>
                  <TableHead className="text-right">確度</TableHead>
                  <TableHead>期間</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {projects.map((project) => (
                  <TableRow
                    key={project.id}
                    className="cursor-pointer"
                    onClick={() => router.push(`/projects/${project.id}`)}
                  >
                    <TableCell className="text-sm text-muted-foreground">
                      {project.project_number}
                    </TableCell>
                    <TableCell className="font-medium">
                      {project.name}
                    </TableCell>
                    <TableCell>
                      {project.customer_name ?? "-"}
                    </TableCell>
                    <TableCell>
                      <Badge variant={STATUS_VARIANT[project.status]}>
                        {STATUS_LABELS[project.status] ?? project.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {project.amount != null ? (
                        <span className="font-medium">
                          ¥{project.amount.toLocaleString()}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {project.probability != null ? (
                        `${project.probability}%`
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm">
                      {project.start_date || project.end_date ? (
                        <>
                          {project.start_date ?? ""}
                          {project.start_date && project.end_date ? " 〜 " : ""}
                          {project.end_date ?? ""}
                        </>
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              全{totalCount}件中 {(currentPage - 1) * 25 + 1}-
              {Math.min(currentPage * 25, totalCount)}件
            </p>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => loadProjects(currentPage - 1)}
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
                onClick={() => loadProjects(currentPage + 1)}
                disabled={currentPage >= totalPages}
              >
                <ChevronRight className="size-4" />
              </Button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
