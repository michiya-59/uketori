"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  Pencil,
  Trash2,
  Building2,
  Mail,
  Phone,
  MapPin,
  FileText,
  CreditCard,
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
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { api, ApiClientError } from "@/lib/api-client";
import type { Customer } from "@/types/customer";

/** 顧客区分のラベルマッピング */
const CUSTOMER_TYPE_LABELS: Record<string, string> = {
  client: "得意先",
  vendor: "仕入先",
  both: "両方",
};

/** 顧客詳細APIレスポンス型 */
interface CustomerDetailResponse {
  customer: Customer;
}

/**
 * 顧客詳細ページ
 * 顧客情報の閲覧・編集・削除を提供する
 * @returns 顧客詳細ページ要素
 */
export default function CustomerDetailPage() {
  const params = useParams();
  const router = useRouter();
  const uuid = params.uuid as string;
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  /** 顧客詳細を取得する */
  const loadCustomer = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<CustomerDetailResponse>(
        `/api/v1/customers/${uuid}`
      );
      setCustomer(res.customer);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "顧客情報の取得に失敗しました");
      }
      router.push("/customers");
    } finally {
      setLoading(false);
    }
  }, [uuid, router]);

  useEffect(() => {
    loadCustomer();
  }, [loadCustomer]);

  /** 顧客を削除する */
  const handleDelete = async () => {
    try {
      setDeleting(true);
      await api.delete(`/api/v1/customers/${uuid}`);
      toast.success("顧客を削除しました");
      router.push("/customers");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "削除に失敗しました");
      }
    } finally {
      setDeleting(false);
      setDeleteOpen(false);
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

  if (!customer) return null;

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" asChild className="mt-1 shrink-0 size-10 sm:size-9">
          <Link href="/customers">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div className="min-w-0 flex-1">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight break-words">
            {customer.company_name}
          </h1>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <Badge variant="outline">
              {CUSTOMER_TYPE_LABELS[customer.customer_type] ?? customer.customer_type}
            </Badge>
            {customer.invoice_registration_number && (
              <Badge variant="secondary">
                適格 {customer.invoice_registration_number}
              </Badge>
            )}
          </div>
          {/* アクションボタン */}
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button variant="outline" size="sm" asChild>
              <Link href={`/customers/${uuid}/edit`}>
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
                  <DialogTitle>顧客を削除</DialogTitle>
                  <DialogDescription>
                    「{customer.company_name}」を削除します。この操作は取り消せません。
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

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <Building2 className="size-5" />
              基本情報
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <InfoRow label="会社名" value={customer.company_name} />
            {customer.company_name_kana && (
              <InfoRow label="フリガナ" value={customer.company_name_kana} />
            )}
            {customer.department && (
              <InfoRow label="部署" value={customer.department} />
            )}
            {customer.contact_name && (
              <InfoRow label="担当者" value={customer.contact_name} />
            )}
            {customer.title && (
              <InfoRow label="役職" value={customer.title} />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <Mail className="size-5" />
              連絡先
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {customer.email && (
              <InfoRow label="メール" value={customer.email} icon={<Mail className="size-4" />} />
            )}
            {customer.phone && (
              <InfoRow label="電話" value={customer.phone} icon={<Phone className="size-4" />} />
            )}
            {customer.fax && <InfoRow label="FAX" value={customer.fax} />}
            {(customer.postal_code || customer.prefecture) && (
              <div className="flex items-start gap-3">
                <MapPin className="mt-0.5 size-4 text-muted-foreground" />
                <div>
                  <p className="text-xs text-muted-foreground">住所</p>
                  <p className="text-[15px]">
                    {customer.postal_code && `〒${customer.postal_code} `}
                    {customer.prefecture}
                    {customer.city}
                    {customer.address_line1}
                    {customer.address_line2 && <br />}
                    {customer.address_line2}
                  </p>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <CreditCard className="size-5" />
              取引情報
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {customer.payment_terms_days != null && (
              <InfoRow
                label="支払サイト"
                value={`${customer.payment_terms_days}日`}
              />
            )}
            {customer.credit_score != null && (
              <InfoRow
                label="与信スコア"
                value={String(customer.credit_score)}
              />
            )}
            <InfoRow
              label="未回収残高"
              value={`¥${customer.total_outstanding.toLocaleString()}`}
            />
            {customer.avg_payment_days != null && (
              <InfoRow
                label="平均支払日数"
                value={`${customer.avg_payment_days}日`}
              />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <FileText className="size-5" />
              メモ
            </CardTitle>
          </CardHeader>
          <CardContent>
            {customer.memo ? (
              <p className="whitespace-pre-wrap text-[15px]">{customer.memo}</p>
            ) : (
              <p className="text-muted-foreground">メモなし</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

/**
 * 情報行を表示するコンポーネント
 * @param label - ラベル
 * @param value - 値
 * @param icon - アイコン要素
 * @returns 情報行要素
 */
function InfoRow({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-3">
      {icon && <span className="mt-0.5 text-muted-foreground">{icon}</span>}
      <div>
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="text-[15px]">{value}</p>
      </div>
    </div>
  );
}
