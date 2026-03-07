"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Plus,
  Search,
  ChevronLeft,
  ChevronRight,
  Building2,
  User,
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
import type { Customer } from "@/types/customer";

/** 顧客一覧APIレスポンス型 */
interface CustomersResponse {
  customers: Customer[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** 顧客区分のラベルマッピング */
const CUSTOMER_TYPE_LABELS: Record<string, string> = {
  client: "得意先",
  vendor: "仕入先",
  both: "両方",
};

/**
 * 顧客一覧ページ
 * 顧客の検索、フィルタリング、一覧表示を提供する
 * @returns 顧客一覧ページ要素
 */
export default function CustomersPage() {
  const router = useRouter();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [customerType, setCustomerType] = useState<string>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  /**
   * 顧客一覧を取得する
   * @param page - ページ番号
   */
  const loadCustomers = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const params: Record<string, string | number> = { page };
        if (searchQuery) params["filter[q]"] = searchQuery;
        if (customerType !== "all") params["filter[customer_type]"] = customerType;

        const res = await api.get<CustomersResponse>("/api/v1/customers", params);
        setCustomers(res.customers);
        setCurrentPage(res.meta.current_page);
        setTotalPages(res.meta.total_pages);
        setTotalCount(res.meta.total_count);
      } catch (e) {
        if (e instanceof ApiClientError) {
          toast.error(e.body?.error?.message ?? "顧客一覧の取得に失敗しました");
        }
      } finally {
        setLoading(false);
      }
    },
    [searchQuery, customerType]
  );

  useEffect(() => {
    loadCustomers(1);
  }, [loadCustomers]);

  /**
   * 検索フォームの送信を処理する
   * @param e - フォームイベント
   */
  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    loadCustomers(1);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">顧客管理</h1>
          <p className="mt-1 text-muted-foreground">
            顧客情報の登録・管理を行います
          </p>
        </div>
        <Button asChild className="self-start sm:self-auto">
          <Link href="/customers/new">
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
              placeholder="会社名・担当者名で検索..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-10 pl-9 text-[15px]"
            />
          </div>
          <Button type="submit" variant="secondary" size="sm">
            検索
          </Button>
        </form>
        <Select value={customerType} onValueChange={setCustomerType}>
          <SelectTrigger className="w-full sm:w-[140px] h-10">
            <SelectValue placeholder="顧客区分" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">すべて</SelectItem>
            <SelectItem value="client">得意先</SelectItem>
            <SelectItem value="vendor">仕入先</SelectItem>
            <SelectItem value="both">両方</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : customers.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <Building2 className="size-12 text-muted-foreground/50 mb-4" />
          <p className="text-lg font-medium text-muted-foreground">
            顧客が登録されていません
          </p>
          <p className="mt-1 text-sm text-muted-foreground/70">
            「新規登録」ボタンから顧客を登録してください
          </p>
        </div>
      ) : (
        <>
          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>会社名</TableHead>
                  <TableHead>担当者</TableHead>
                  <TableHead>区分</TableHead>
                  <TableHead>メール</TableHead>
                  <TableHead>電話番号</TableHead>
                  <TableHead className="text-right">未回収額</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {customers.map((customer) => (
                  <TableRow
                    key={customer.id}
                    className="cursor-pointer"
                    onClick={() => router.push(`/customers/${customer.id}`)}
                  >
                    <TableCell className="font-medium">
                      {customer.company_name}
                    </TableCell>
                    <TableCell>
                      {customer.contact_name ? (
                        <span className="flex items-center gap-1.5">
                          <User className="size-3.5 text-muted-foreground" />
                          {customer.contact_name}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">
                        {CUSTOMER_TYPE_LABELS[customer.customer_type] ?? customer.customer_type}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm">
                      {customer.email ?? "-"}
                    </TableCell>
                    <TableCell className="text-sm">
                      {customer.phone ?? "-"}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {customer.total_outstanding > 0 ? (
                        <span className="font-medium text-destructive">
                          ¥{customer.total_outstanding.toLocaleString()}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">¥0</span>
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
                onClick={() => loadCustomers(currentPage - 1)}
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
                onClick={() => loadCustomers(currentPage + 1)}
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
