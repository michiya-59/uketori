"use client";

import { useEffect, useState, useCallback } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2, Building2, Landmark, FileText, Save } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { api, ApiClientError } from "@/lib/api-client";
import { SettingsNav } from "@/components/settings/settings-nav";

/** 会社情報フォームのバリデーションスキーマ */
const companySchema = z.object({
  name: z.string().min(1, "会社名を入力してください"),
  name_kana: z.string().optional(),
  postal_code: z.string().optional(),
  prefecture: z.string().optional(),
  city: z.string().optional(),
  address_line1: z.string().optional(),
  address_line2: z.string().optional(),
  phone: z.string().optional(),
  fax: z.string().optional(),
  email: z.string().email("有効なメールアドレスを入力してください").optional().or(z.literal("")),
  website: z.string().optional(),
  invoice_registration_number: z.string().optional(),
});

/** 振込先フォームのバリデーションスキーマ */
const bankSchema = z.object({
  bank_name: z.string().optional(),
  bank_branch_name: z.string().optional(),
  bank_account_type: z.string().optional(),
  bank_account_number: z.string().optional(),
  bank_account_holder: z.string().optional(),
});

/** 帳票設定フォームのバリデーションスキーマ */
const documentSchema = z.object({
  document_sequence_format: z.string().min(1, "採番フォーマットを入力してください"),
  default_tax_rate: z.number().min(0, "0以上で入力してください"),
  default_payment_terms_days: z.number().min(1, "1以上で入力してください"),
  fiscal_year_start_month: z.number().min(1).max(12),
});

type CompanyFormData = z.infer<typeof companySchema>;
type BankFormData = z.infer<typeof bankSchema>;
type DocumentFormData = z.infer<typeof documentSchema>;

/** テナントAPIのレスポンス型 */
interface TenantData {
  tenant: Record<string, unknown>;
}

/** 都道府県の一覧 */
const PREFECTURES = [
  "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
  "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
  "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
  "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
  "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
  "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
  "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
];

/**
 * 会社設定ページ
 * 会社情報・振込先・帳票設定をタブ形式で管理する
 * @returns 会社設定ページ要素
 */
export default function CompanySettingsPage() {
  const [loading, setLoading] = useState(true);
  const [tenantData, setTenantData] = useState<Record<string, unknown> | null>(null);

  const loadTenant = useCallback(async () => {
    try {
      const result = await api.get<TenantData>("/api/v1/tenant");
      setTenantData(result.tenant);
    } catch {
      toast.error("設定の読み込みに失敗しました");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTenant();
  }, [loadTenant]);

  if (loading) {
    return (
      <div className="space-y-4 sm:space-y-6">
        <div>
          <Skeleton className="h-8 w-40" />
          <Skeleton className="mt-2 h-5 w-64" />
        </div>
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      <SettingsNav />
      <div>
        <h1 className="text-xl sm:text-2xl font-bold tracking-tight">会社設定</h1>
        <p className="text-sm text-muted-foreground">
          会社情報・振込先・帳票設定を管理します
        </p>
      </div>
      <Tabs defaultValue="company" className="space-y-4 sm:space-y-6">
        <TabsList className="h-10 sm:h-11 w-full sm:w-auto">
          <TabsTrigger value="company" className="gap-1.5 sm:gap-2 text-[13px] sm:text-[14px]">
            <Building2 className="size-3.5 sm:size-4" />
            会社情報
          </TabsTrigger>
          <TabsTrigger value="bank" className="gap-1.5 sm:gap-2 text-[13px] sm:text-[14px]">
            <Landmark className="size-3.5 sm:size-4" />
            振込先
          </TabsTrigger>
          <TabsTrigger value="document" className="gap-1.5 sm:gap-2 text-[13px] sm:text-[14px]">
            <FileText className="size-3.5 sm:size-4" />
            帳票設定
          </TabsTrigger>
        </TabsList>
        <TabsContent value="company">
          <CompanyInfoForm data={tenantData} onSaved={loadTenant} />
        </TabsContent>
        <TabsContent value="bank">
          <BankInfoForm data={tenantData} onSaved={loadTenant} />
        </TabsContent>
        <TabsContent value="document">
          <DocumentSettingsForm data={tenantData} onSaved={loadTenant} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

/**
 * 会社情報フォーム
 * @param data - テナントデータ
 * @param onSaved - 保存後のコールバック
 * @returns 会社情報フォーム要素
 */
function CompanyInfoForm({
  data,
  onSaved,
}: {
  data: Record<string, unknown> | null;
  onSaved: () => void;
}) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<CompanyFormData>({
    resolver: zodResolver(companySchema),
    defaultValues: {
      name: (data?.name as string) ?? "",
      name_kana: (data?.name_kana as string) ?? "",
      postal_code: (data?.postal_code as string) ?? "",
      prefecture: (data?.prefecture as string) ?? "",
      city: (data?.city as string) ?? "",
      address_line1: (data?.address_line1 as string) ?? "",
      address_line2: (data?.address_line2 as string) ?? "",
      phone: (data?.phone as string) ?? "",
      fax: (data?.fax as string) ?? "",
      email: (data?.email as string) ?? "",
      website: (data?.website as string) ?? "",
      invoice_registration_number: (data?.invoice_registration_number as string) ?? "",
    },
  });

  const onSubmit = async (formData: CompanyFormData) => {
    try {
      await api.patch("/api/v1/tenant", { tenant: formData });
      toast.success("会社情報を保存しました");
      onSaved();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "保存に失敗しました");
      }
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">会社情報</CardTitle>
        <CardDescription>帳票に印字される会社情報を設定します</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">会社名</Label>
              <Input className="h-11 text-[15px]" {...register("name")} />
              {errors.name && <p className="text-sm text-destructive">{errors.name.message}</p>}
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">会社名（カナ）</Label>
              <Input className="h-11 text-[15px]" placeholder="カブシキガイシャ サンプル" {...register("name_kana")} />
            </div>
          </div>

          <Separator />

          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">郵便番号</Label>
              <Input className="h-11 text-[15px]" placeholder="100-0001" {...register("postal_code")} />
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">都道府県</Label>
              <Input className="h-11 text-[15px]" placeholder="東京都" {...register("prefecture")} />
            </div>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">市区町村</Label>
              <Input className="h-11 text-[15px]" placeholder="千代田区" {...register("city")} />
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">番地</Label>
              <Input className="h-11 text-[15px]" placeholder="丸の内1-1-1" {...register("address_line1")} />
            </div>
          </div>
          <div className="space-y-2">
            <Label className="text-[15px]">建物名・部屋番号</Label>
            <Input className="h-11 text-[15px]" placeholder="サンプルビル 3F" {...register("address_line2")} />
          </div>

          <Separator />

          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">電話番号</Label>
              <Input className="h-11 text-[15px]" placeholder="03-1234-5678" {...register("phone")} />
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">FAX番号</Label>
              <Input className="h-11 text-[15px]" placeholder="03-1234-5679" {...register("fax")} />
            </div>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">メールアドレス</Label>
              <Input className="h-11 text-[15px]" type="email" placeholder="info@example.co.jp" {...register("email")} />
              {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">Webサイト</Label>
              <Input className="h-11 text-[15px]" placeholder="https://example.co.jp" {...register("website")} />
            </div>
          </div>

          <Separator />

          <div className="space-y-2">
            <Label className="text-[15px]">適格請求書発行事業者登録番号</Label>
            <Input className="h-11 text-[15px]" placeholder="T1234567890123" {...register("invoice_registration_number")} />
            <p className="text-sm text-muted-foreground">
              インボイス制度の登録番号（T + 13桁の数字）
            </p>
          </div>

          <div className="flex justify-end">
            <Button type="submit" disabled={isSubmitting} className="h-11 gap-2 text-[15px]">
              {isSubmitting ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
              保存する
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

/**
 * 振込先フォーム
 * @param data - テナントデータ
 * @param onSaved - 保存後のコールバック
 * @returns 振込先フォーム要素
 */
function BankInfoForm({
  data,
  onSaved,
}: {
  data: Record<string, unknown> | null;
  onSaved: () => void;
}) {
  const {
    register,
    handleSubmit,
    formState: { isSubmitting },
    setValue,
    watch,
  } = useForm<BankFormData>({
    resolver: zodResolver(bankSchema),
    defaultValues: {
      bank_name: (data?.bank_name as string) ?? "",
      bank_branch_name: (data?.bank_branch_name as string) ?? "",
      bank_account_type: (data?.bank_account_type as string) ?? "",
      bank_account_number: (data?.bank_account_number as string) ?? "",
      bank_account_holder: (data?.bank_account_holder as string) ?? "",
    },
  });

  const accountType = watch("bank_account_type");

  const onSubmit = async (formData: BankFormData) => {
    try {
      await api.patch("/api/v1/tenant", { tenant: formData });
      toast.success("振込先情報を保存しました");
      onSaved();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "保存に失敗しました");
      }
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">振込先情報</CardTitle>
        <CardDescription>請求書に記載される振込先口座情報を設定します</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">銀行名</Label>
              <Input className="h-11 text-[15px]" placeholder="三菱UFJ銀行" {...register("bank_name")} />
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">支店名</Label>
              <Input className="h-11 text-[15px]" placeholder="丸の内支店" {...register("bank_branch_name")} />
            </div>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">口座種別</Label>
              <Select
                value={accountType ?? ""}
                onValueChange={(v) => setValue("bank_account_type", v)}
              >
                <SelectTrigger className="h-11 text-[15px]">
                  <SelectValue placeholder="選択してください" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ordinary">普通</SelectItem>
                  <SelectItem value="checking">当座</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">口座番号</Label>
              <Input className="h-11 text-[15px]" placeholder="1234567" {...register("bank_account_number")} />
            </div>
          </div>
          <div className="space-y-2">
            <Label className="text-[15px]">口座名義</Label>
            <Input className="h-11 text-[15px]" placeholder="カ）サンプル" {...register("bank_account_holder")} />
            <p className="text-sm text-muted-foreground">
              カタカナで入力してください
            </p>
          </div>
          <div className="flex justify-end">
            <Button type="submit" disabled={isSubmitting} className="h-11 gap-2 text-[15px]">
              {isSubmitting ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
              保存する
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

/**
 * 帳票設定フォーム
 * @param data - テナントデータ
 * @param onSaved - 保存後のコールバック
 * @returns 帳票設定フォーム要素
 */
function DocumentSettingsForm({
  data,
  onSaved,
}: {
  data: Record<string, unknown> | null;
  onSaved: () => void;
}) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setValue,
    watch,
  } = useForm<DocumentFormData>({
    resolver: zodResolver(documentSchema),
    defaultValues: {
      document_sequence_format: (data?.document_sequence_format as string) || "{prefix}-{YYYY}{MM}-{SEQ}",
      default_tax_rate: Number(data?.default_tax_rate) || 10,
      default_payment_terms_days: (data?.default_payment_terms_days as number) ?? 30,
      fiscal_year_start_month: (data?.fiscal_year_start_month as number) ?? 4,
    },
  });

  const fiscalMonth = watch("fiscal_year_start_month");

  const onSubmit = async (formData: DocumentFormData) => {
    try {
      await api.patch("/api/v1/tenant", { tenant: formData });
      toast.success("帳票設定を保存しました");
      onSaved();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "保存に失敗しました");
      }
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">帳票設定</CardTitle>
        <CardDescription>帳票作成時のデフォルト値を設定します</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="space-y-2">
            <Label className="text-[15px]">帳票採番フォーマット</Label>
            <Input className="h-11 text-[15px]" {...register("document_sequence_format")} />
            {errors.document_sequence_format && (
              <p className="text-sm text-destructive">{errors.document_sequence_format.message}</p>
            )}
            <p className="text-xs text-muted-foreground">
              {"利用可能な変数: {prefix}=帳票種別, {YYYY}=西暦年, {MM}=月, {SEQ}=連番"}
            </p>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <div className="space-y-2">
              <Label className="text-[15px]">デフォルト消費税率 (%)</Label>
              <Input className="h-11 text-[15px]" type="number" step="0.1" {...register("default_tax_rate", { valueAsNumber: true })} />
              {errors.default_tax_rate && (
                <p className="text-sm text-destructive">{errors.default_tax_rate.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">デフォルト支払期限（日）</Label>
              <Input className="h-11 text-[15px]" type="number" {...register("default_payment_terms_days", { valueAsNumber: true })} />
              {errors.default_payment_terms_days && (
                <p className="text-sm text-destructive">{errors.default_payment_terms_days.message}</p>
              )}
            </div>
          </div>
          <div className="space-y-2">
            <Label className="text-[15px]">会計年度開始月</Label>
            <Select
              value={String(fiscalMonth)}
              onValueChange={(v) => setValue("fiscal_year_start_month", Number(v))}
            >
              <SelectTrigger className="h-11 text-[15px] w-full sm:w-48">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                  <SelectItem key={m} value={String(m)}>
                    {m}月
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex justify-end">
            <Button type="submit" disabled={isSubmitting} className="h-11 gap-2 text-[15px]">
              {isSubmitting ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
              保存する
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

