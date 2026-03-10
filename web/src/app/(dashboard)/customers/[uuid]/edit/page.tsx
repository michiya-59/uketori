"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { useRouter, useParams } from "next/navigation";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowLeft, Loader2, Save } from "lucide-react";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { api, ApiClientError } from "@/lib/api-client";
import { useKatakanaAutoFill } from "@/hooks/use-katakana";
import type { Customer } from "@/types/customer";

/** カタカナのみ（全角カタカナ・長音符・全角スペース・半角スペース） */
const katakanaRegex = /^[ァ-ヶー　\s]+$/;

/** 顧客フォームのバリデーションスキーマ */
const customerSchema = z.object({
  company_name: z.string().min(1, "会社名を入力してください"),
  company_name_kana: z
    .string()
    .min(1, "フリガナを入力してください")
    .regex(katakanaRegex, "カタカナで入力してください"),
  customer_type: z.enum(["client", "vendor", "both"]),
  department: z.string().optional(),
  title: z.string().optional(),
  contact_name: z.string().optional(),
  email: z
    .string()
    .email("有効なメールアドレスを入力してください")
    .optional()
    .or(z.literal("")),
  phone: z.string().optional(),
  fax: z.string().optional(),
  postal_code: z.string().optional(),
  prefecture: z.string().optional(),
  city: z.string().optional(),
  address_line1: z.string().optional(),
  address_line2: z.string().optional(),
  invoice_registration_number: z.string().optional(),
  payment_terms_days: z.number().min(0).optional(),
  memo: z.string().optional(),
});

type CustomerFormData = z.infer<typeof customerSchema>;

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

/** 顧客詳細APIレスポンス型 */
interface CustomerDetailResponse {
  customer: Customer;
}

/**
 * 顧客編集ページ
 * 既存の顧客情報を読み込み、編集・更新する
 * @returns 顧客編集ページ要素
 */
export default function EditCustomerPage() {
  const router = useRouter();
  const params = useParams();
  const uuid = params.uuid as string;
  const [loading, setLoading] = useState(true);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<CustomerFormData>({
    resolver: zodResolver(customerSchema),
    defaultValues: {
      customer_type: "client",
      payment_terms_days: 30,
      company_name_kana: "",
    },
  });

  /** データ読み込み完了フラグ（初回ロード時にAPI呼び出しを防ぐ） */
  const initialLoaded = useRef(false);

  const companyName = watch("company_name");
  const kanaManuallyEdited = useKatakanaAutoFill(
    companyName,
    setValue,
    initialLoaded.current
  );

  /**
   * 既存の顧客データを読み込みフォームにセットする
   */
  const loadCustomer = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<CustomerDetailResponse>(
        `/api/v1/customers/${uuid}`
      );
      const c = res.customer;
      reset({
        company_name: c.company_name,
        company_name_kana: c.company_name_kana ?? "",
        customer_type: c.customer_type as "client" | "vendor" | "both",
        department: c.department ?? "",
        title: c.title ?? "",
        contact_name: c.contact_name ?? "",
        email: c.email ?? "",
        phone: c.phone ?? "",
        fax: c.fax ?? "",
        postal_code: c.postal_code ?? "",
        prefecture: c.prefecture ?? "",
        city: c.city ?? "",
        address_line1: c.address_line1 ?? "",
        address_line2: c.address_line2 ?? "",
        invoice_registration_number: c.invoice_registration_number ?? "",
        payment_terms_days: c.payment_terms_days ?? 30,
        memo: c.memo ?? "",
      });
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "顧客情報の取得に失敗しました");
      }
      router.push("/customers");
    } finally {
      setLoading(false);
      // 初回ロード完了後にフラグを立てる（ロード時のwatch変更でAPI呼び出しを防ぐ）
      setTimeout(() => {
        initialLoaded.current = true;
      }, 100);
    }
  }, [uuid, router, reset]);

  useEffect(() => {
    loadCustomer();
  }, [loadCustomer]);

  /**
   * フォームの送信を処理し顧客情報を更新する
   * @param data - フォームデータ
   */
  const onSubmit = async (data: CustomerFormData) => {
    try {
      await api.patch<{ customer: Customer }>(`/api/v1/customers/${uuid}`, {
        customer: data,
      });
      toast.success("顧客情報を更新しました");
      router.push(`/customers/${uuid}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "更新に失敗しました");
      }
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

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild className="size-10 sm:size-9">
          <Link href={`/customers/${uuid}`}>
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">顧客情報の編集</h1>
          <p className="mt-1 text-muted-foreground">
            顧客情報を変更します
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">基本情報</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">
                  会社名 <span className="text-destructive">*</span>
                </Label>
                <Input
                  {...register("company_name")}
                  className="h-11 text-[15px]"
                  placeholder="株式会社ウケトリ"
                />
                {errors.company_name && (
                  <p className="text-sm text-destructive">
                    {errors.company_name.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">
                  フリガナ <span className="text-destructive">*</span>
                </Label>
                <Input
                  {...register("company_name_kana", {
                    onChange: () => {
                      kanaManuallyEdited.current = true;
                    },
                  })}
                  className="h-11 text-[15px]"
                  placeholder="カブシキガイシャウケトリ"
                />
                {errors.company_name_kana && (
                  <p className="text-sm text-destructive">
                    {errors.company_name_kana.message}
                  </p>
                )}
              </div>
            </div>

            <div className="grid gap-5 sm:grid-cols-3">
              <div className="space-y-2">
                <Label className="text-[15px]">顧客区分</Label>
                <Select
                  value={watch("customer_type")}
                  onValueChange={(v) =>
                    setValue("customer_type", v as "client" | "vendor" | "both")
                  }
                >
                  <SelectTrigger className="h-11">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="client">得意先</SelectItem>
                    <SelectItem value="vendor">仕入先</SelectItem>
                    <SelectItem value="both">両方</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">部署</Label>
                <Input
                  {...register("department")}
                  className="h-11 text-[15px]"
                  placeholder="営業部"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">役職</Label>
                <Input
                  {...register("title")}
                  className="h-11 text-[15px]"
                  placeholder="部長"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">連絡先</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">担当者名</Label>
                <Input
                  {...register("contact_name")}
                  className="h-11 text-[15px]"
                  placeholder="山田 太郎"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">メールアドレス</Label>
                <Input
                  type="email"
                  {...register("email")}
                  className="h-11 text-[15px]"
                  placeholder="taro@example.com"
                />
                {errors.email && (
                  <p className="text-sm text-destructive">
                    {errors.email.message}
                  </p>
                )}
              </div>
            </div>
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">電話番号</Label>
                <Input
                  {...register("phone")}
                  className="h-11 text-[15px]"
                  placeholder="03-1234-5678"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">FAX</Label>
                <Input
                  {...register("fax")}
                  className="h-11 text-[15px]"
                  placeholder="03-1234-5679"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">住所</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-3">
              <div className="space-y-2">
                <Label className="text-[15px]">郵便番号</Label>
                <Input
                  {...register("postal_code")}
                  className="h-11 text-[15px]"
                  placeholder="100-0001"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">都道府県</Label>
                <Select
                  value={watch("prefecture") ?? ""}
                  onValueChange={(v) => setValue("prefecture", v)}
                >
                  <SelectTrigger className="h-11">
                    <SelectValue placeholder="選択してください" />
                  </SelectTrigger>
                  <SelectContent>
                    {PREFECTURES.map((pref) => (
                      <SelectItem key={pref} value={pref}>
                        {pref}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">市区町村</Label>
                <Input
                  {...register("city")}
                  className="h-11 text-[15px]"
                  placeholder="千代田区"
                />
              </div>
            </div>
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">番地</Label>
                <Input
                  {...register("address_line1")}
                  className="h-11 text-[15px]"
                  placeholder="丸の内1-1-1"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">建物名・部屋番号</Label>
                <Input
                  {...register("address_line2")}
                  className="h-11 text-[15px]"
                  placeholder="○○ビル 3F"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">取引情報</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">適格請求書番号</Label>
                <Input
                  {...register("invoice_registration_number")}
                  className="h-11 text-[15px]"
                  placeholder="T1234567890123"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">支払サイト（日数）</Label>
                <Input
                  type="number"
                  {...register("payment_terms_days", { valueAsNumber: true })}
                  className="h-11 text-[15px]"
                  placeholder="30"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">メモ</Label>
              <textarea
                {...register("memo")}
                className="flex min-h-[100px] w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                placeholder="取引に関するメモ"
              />
            </div>
          </CardContent>
        </Card>

        <div className="flex justify-end gap-3">
          <Button variant="outline" type="button" asChild>
            <Link href={`/customers/${uuid}`}>キャンセル</Link>
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
            <Save className="mr-2 size-4" />
            更新する
          </Button>
        </div>
      </form>
    </div>
  );
}
