"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  Save,
  Loader2,
  Building2,
  Users,
  FileText,
  UserCircle,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { api, ApiClientError } from "@/lib/api-client";

/** テナント詳細の型 */
interface TenantDetail {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  plan: string;
  plan_started_at: string | null;
  industry_type: string;
  import_enabled: boolean;
  dunning_enabled: boolean;
  invoice_registration_number: string | null;
  invoice_number_verified: boolean;
  users_count: number;
  customers_count: number;
  documents_count: number;
  owner: { name: string; email: string } | null;
  created_at: string;
  updated_at: string;
}

/** プランオプション */
const PLAN_OPTIONS = [
  { value: "free", label: "Free" },
  { value: "starter", label: "Starter" },
  { value: "standard", label: "Standard" },
  { value: "professional", label: "Professional" },
];

/**
 * システム管理者用テナント詳細ページ
 * テナントの詳細表示とプラン・フラグの編集を提供する
 * @returns テナント詳細ページ要素
 */
export default function AdminTenantDetailPage() {
  const params = useParams();
  const router = useRouter();
  const uuid = params.uuid as string;

  const [tenant, setTenant] = useState<TenantDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // 編集用state
  const [plan, setPlan] = useState("");
  const [importEnabled, setImportEnabled] = useState(false);
  const [dunningEnabled, setDunningEnabled] = useState(false);

  /** テナント詳細を取得する */
  const loadTenant = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ tenant: TenantDetail }>(
        `/api/v1/admin/tenants/${uuid}`
      );
      setTenant(res.tenant);
      setPlan(res.tenant.plan);
      setImportEnabled(res.tenant.import_enabled);
      setDunningEnabled(res.tenant.dunning_enabled);
    } catch (e) {
      if (e instanceof ApiClientError) {
        if (e.status === 403) {
          toast.error("システム管理者権限が必要です");
          router.push("/dashboard");
          return;
        }
        toast.error(e.body?.error?.message ?? "テナント情報の取得に失敗しました");
      }
      router.push("/admin/tenants");
    } finally {
      setLoading(false);
    }
  }, [uuid, router]);

  useEffect(() => {
    loadTenant();
  }, [loadTenant]);

  /** 変更を保存する */
  const handleSave = async () => {
    try {
      setSaving(true);
      const res = await api.patch<{ tenant: TenantDetail }>(
        `/api/v1/admin/tenants/${uuid}`,
        {
          tenant: {
            plan,
            import_enabled: importEnabled,
            dunning_enabled: dunningEnabled,
          },
        }
      );
      setTenant(res.tenant);
      toast.success("テナント設定を更新しました");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "更新に失敗しました");
      }
    } finally {
      setSaving(false);
    }
  };

  /** 変更があるかどうかを判定する */
  const hasChanges =
    tenant !== null &&
    (plan !== tenant.plan ||
      importEnabled !== tenant.import_enabled ||
      dunningEnabled !== tenant.dunning_enabled);

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }

  if (!tenant) return null;

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" asChild className="mt-1 shrink-0 size-10 sm:size-9">
          <Link href="/admin/tenants">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div className="min-w-0 flex-1">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight">
            {tenant.name}
          </h1>
          <p className="text-sm text-muted-foreground">
            テナントID: {tenant.id}
          </p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* テナント情報 */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <Building2 className="size-5" />
              テナント情報
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <InfoRow label="テナント名" value={tenant.name} />
            <InfoRow label="メール" value={tenant.email ?? "-"} />
            <InfoRow label="電話番号" value={tenant.phone ?? "-"} />
            <InfoRow label="業種" value={tenant.industry_type} />
            <InfoRow
              label="インボイス番号"
              value={
                tenant.invoice_registration_number
                  ? `${tenant.invoice_registration_number}${tenant.invoice_number_verified ? " (検証済)" : ""}`
                  : "-"
              }
            />
            <InfoRow
              label="登録日"
              value={new Date(tenant.created_at).toLocaleDateString("ja-JP")}
            />
          </CardContent>
        </Card>

        {/* オーナー情報 */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <UserCircle className="size-5" />
              オーナー情報
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <InfoRow label="名前" value={tenant.owner?.name ?? "-"} />
            <InfoRow label="メール" value={tenant.owner?.email ?? "-"} />
            <Separator />
            <div className="flex gap-6">
              <div className="flex items-center gap-2">
                <Users className="size-4 text-muted-foreground" />
                <span className="text-muted-foreground">ユーザー:</span>
                <span className="font-medium">{tenant.users_count}名</span>
              </div>
              <div className="flex items-center gap-2">
                <FileText className="size-4 text-muted-foreground" />
                <span className="text-muted-foreground">帳票:</span>
                <span className="font-medium">{tenant.documents_count}件</span>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Users className="size-4 text-muted-foreground" />
              <span className="text-muted-foreground">顧客:</span>
              <span className="font-medium">{tenant.customers_count}社</span>
            </div>
          </CardContent>
        </Card>

        {/* プラン・フラグ設定 */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-lg">プラン・機能設定</CardTitle>
            <CardDescription>
              テナントのプランと機能フラグを変更できます
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* プラン選択 */}
            <div className="space-y-2">
              <Label className="text-[15px]">プラン</Label>
              <div className="flex items-center gap-3">
                <Select value={plan} onValueChange={setPlan}>
                  <SelectTrigger className="w-[200px]">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {PLAN_OPTIONS.map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {plan !== tenant.plan && (
                  <Badge variant="outline" className="text-amber-600 border-amber-300">
                    変更あり
                  </Badge>
                )}
              </div>
              {tenant.plan_started_at && (
                <p className="text-xs text-muted-foreground">
                  現在のプラン開始日: {new Date(tenant.plan_started_at).toLocaleDateString("ja-JP")}
                </p>
              )}
            </div>

            <Separator />

            {/* 機能フラグ */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <Label className="text-[15px]">データ移行</Label>
                  <p className="text-xs text-muted-foreground">
                    CSVインポートによるデータ移行機能を有効にします
                  </p>
                </div>
                <Switch
                  checked={importEnabled}
                  onCheckedChange={setImportEnabled}
                />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <Label className="text-[15px]">自動督促</Label>
                  <p className="text-xs text-muted-foreground">
                    督促ルールによる自動メール送信機能を有効にします
                  </p>
                </div>
                <Switch
                  checked={dunningEnabled}
                  onCheckedChange={setDunningEnabled}
                />
              </div>
            </div>

            <Separator />

            {/* 保存ボタン */}
            <div className="flex justify-end">
              <Button onClick={handleSave} disabled={saving || !hasChanges}>
                {saving && <Loader2 className="mr-2 size-4 animate-spin" />}
                <Save className="mr-2 size-4" />
                変更を保存
              </Button>
            </div>
          </CardContent>
        </Card>
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
      <span className="text-muted-foreground">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  );
}
