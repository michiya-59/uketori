"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Search, ChevronLeft, ChevronRight } from "lucide-react";
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

/** テナント一覧の型 */
interface TenantSummary {
  id: string;
  name: string;
  plan: string;
  import_enabled: boolean;
  dunning_enabled: boolean;
  users_count: number;
  customers_count: number;
  documents_count: number;
  created_at: string;
}

/** プランのバッジvariant */
const PLAN_VARIANTS: Record<string, "default" | "secondary" | "outline"> = {
  free: "outline",
  starter: "secondary",
  standard: "default",
  professional: "default",
};

/**
 * システム管理者用テナント一覧ページ
 * テナントの検索、プランフィルタ、一覧表示を提供する
 * @returns テナント一覧ページ要素
 */
export default function AdminTenantsPage() {
  const router = useRouter();
  const [tenants, setTenants] = useState<TenantSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [planFilter, setPlanFilter] = useState("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  /** テナント一覧を取得する */
  const loadTenants = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const params: Record<string, string | number> = { page };
        if (search) params.search = search;
        if (planFilter !== "all") params.plan = planFilter;

        const res = await api.get<{
          tenants: TenantSummary[];
          meta: { current_page: number; total_pages: number; total_count: number };
        }>("/api/v1/admin/tenants", params);

        setTenants(res.tenants);
        setCurrentPage(res.meta.current_page);
        setTotalPages(res.meta.total_pages);
        setTotalCount(res.meta.total_count);
      } catch (e) {
        if (e instanceof ApiClientError) {
          if (e.status === 403) {
            toast.error("システム管理者権限が必要です");
            router.push("/dashboard");
            return;
          }
          toast.error(e.body?.error?.message ?? "テナント一覧の取得に失敗しました");
        }
      } finally {
        setLoading(false);
      }
    },
    [search, planFilter, router]
  );

  useEffect(() => {
    loadTenants(1);
  }, [loadTenants]);

  /**
   * 検索を実行する
   */
  const handleSearch = () => {
    loadTenants(1);
  };

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-2">
          <ShieldCheck className="size-6 text-primary" />
          <h1 className="text-2xl font-bold tracking-tight">システム管理</h1>
        </div>
        <p className="mt-1 text-muted-foreground">
          テナントの管理・プラン変更・機能フラグの設定を行います
        </p>
      </div>

      {/* フィルタ */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="flex flex-1 gap-2">
          <Input
            placeholder="テナント名で検索..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSearch()}
            className="max-w-sm"
          />
          <Button variant="outline" size="icon" onClick={handleSearch}>
            <Search className="size-4" />
          </Button>
        </div>
        <Select value={planFilter} onValueChange={setPlanFilter}>
          <SelectTrigger className="w-full sm:w-[160px]">
            <SelectValue placeholder="プラン" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">すべてのプラン</SelectItem>
            <SelectItem value="free">Free</SelectItem>
            <SelectItem value="starter">Starter</SelectItem>
            <SelectItem value="standard">Standard</SelectItem>
            <SelectItem value="professional">Professional</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* テナント一覧 */}
      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : tenants.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <p className="text-lg font-medium text-muted-foreground">
            テナントが見つかりません
          </p>
        </div>
      ) : (
        <>
          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>テナント名</TableHead>
                  <TableHead>プラン</TableHead>
                  <TableHead className="text-center">ユーザー</TableHead>
                  <TableHead className="text-center">顧客</TableHead>
                  <TableHead className="text-center">帳票</TableHead>
                  <TableHead className="text-center">データ移行</TableHead>
                  <TableHead className="text-center">自動督促</TableHead>
                  <TableHead>登録日</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {tenants.map((t) => (
                  <TableRow
                    key={t.id}
                    className="cursor-pointer"
                    onClick={() => router.push(`/admin/tenants/${t.id}`)}
                  >
                    <TableCell className="font-medium">{t.name}</TableCell>
                    <TableCell>
                      <Badge variant={PLAN_VARIANTS[t.plan] ?? "outline"}>
                        {t.plan}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      {t.users_count}
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      {t.customers_count}
                    </TableCell>
                    <TableCell className="text-center tabular-nums">
                      {t.documents_count}
                    </TableCell>
                    <TableCell className="text-center">
                      <FlagBadge enabled={t.import_enabled} />
                    </TableCell>
                    <TableCell className="text-center">
                      <FlagBadge enabled={t.dunning_enabled} />
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {new Date(t.created_at).toLocaleDateString("ja-JP")}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {/* ページネーション */}
          <div className="flex items-center justify-between pt-2">
            <p className="text-sm text-muted-foreground">
              全{totalCount}件
            </p>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => loadTenants(currentPage - 1)}
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
                onClick={() => loadTenants(currentPage + 1)}
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

/**
 * 有効/無効バッジコンポーネント
 * @param enabled - 有効かどうか
 * @returns バッジ要素
 */
function FlagBadge({ enabled }: { enabled: boolean }) {
  return (
    <Badge variant={enabled ? "default" : "outline"} className="text-xs">
      {enabled ? "ON" : "OFF"}
    </Badge>
  );
}
