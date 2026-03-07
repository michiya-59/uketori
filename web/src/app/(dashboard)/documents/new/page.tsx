"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useForm, useFieldArray } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  ArrowLeft,
  Loader2,
  Save,
  Plus,
  Trash2,
  GripVertical,
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { api, ApiClientError } from "@/lib/api-client";
import type { Customer } from "@/types/customer";
import type { DocumentType } from "@/types/document";

/** 明細行のバリデーションスキーマ */
const itemSchema = z.object({
  name: z.string().min(1, "品名を入力してください"),
  description: z.string().optional(),
  quantity: z.number().min(0.01, "数量を入力してください"),
  unit: z.string().optional(),
  unit_price: z.number().min(0, "単価を入力してください"),
  tax_rate: z.number().min(0).max(100),
  tax_rate_type: z.enum(["standard", "reduced", "exempt"]),
  item_type: z.string(),
  sort_order: z.number(),
});

/** 帳票フォームのバリデーションスキーマ */
const documentSchema = z.object({
  document_type: z.enum([
    "estimate",
    "purchase_order",
    "order_confirmation",
    "delivery_note",
    "invoice",
    "receipt",
  ]),
  customer_id: z.string().min(1, "顧客を選択してください"),
  title: z.string().optional(),
  issue_date: z.string().min(1, "発行日を入力してください"),
  due_date: z.string().optional(),
  valid_until: z.string().optional(),
  notes: z.string().optional(),
  internal_memo: z.string().optional(),
  document_items_attributes: z.array(itemSchema).min(1, "明細行を1つ以上追加してください"),
});

type DocumentFormData = z.infer<typeof documentSchema>;

/** 帳票種別ラベル */
const DOC_TYPE_OPTIONS: { value: DocumentType; label: string }[] = [
  { value: "estimate", label: "見積書" },
  { value: "invoice", label: "請求書" },
  { value: "purchase_order", label: "発注書" },
  { value: "order_confirmation", label: "注文請書" },
  { value: "delivery_note", label: "納品書" },
  { value: "receipt", label: "領収書" },
];

/** 税率オプション */
const TAX_RATE_OPTIONS = [
  { value: "standard", label: "10%（標準）", rate: 10 },
  { value: "reduced", label: "8%（軽減）", rate: 8 },
  { value: "exempt", label: "0%（非課税）", rate: 0 },
];

/** 顧客一覧レスポンス型 */
interface CustomersResponse {
  customers: Customer[];
  meta: { total_count: number };
}

/**
 * 帳票新規作成ページ
 * 帳票の種別選択、顧客選択、明細行入力を提供する
 * @returns 帳票新規作成ページ要素
 */
export default function NewDocumentPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);

  const defaultType = (searchParams.get("type") ?? "estimate") as DocumentType;

  const {
    register,
    handleSubmit,
    control,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<DocumentFormData>({
    resolver: zodResolver(documentSchema),
    defaultValues: {
      document_type: defaultType,
      issue_date: new Date().toISOString().split("T")[0],
      document_items_attributes: [
        {
          name: "",
          quantity: 1,
          unit_price: 0,
          tax_rate: 10,
          tax_rate_type: "standard",
          item_type: "normal",
          sort_order: 0,
        },
      ],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "document_items_attributes",
  });

  const items = watch("document_items_attributes");

  /** 顧客一覧を取得する */
  const loadCustomers = useCallback(async () => {
    try {
      setLoadingCustomers(true);
      const res = await api.get<CustomersResponse>("/api/v1/customers", {
        per_page: 100,
      });
      setCustomers(res.customers);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("顧客一覧の取得に失敗しました");
      }
    } finally {
      setLoadingCustomers(false);
    }
  }, []);

  useEffect(() => {
    loadCustomers();
  }, [loadCustomers]);

  /**
   * 小計を計算する
   * @returns 小計金額
   */
  const calcSubtotal = (): number => {
    return (items ?? []).reduce((sum, item) => {
      if (item.item_type !== "normal") return sum;
      return sum + Math.floor((item.quantity ?? 0) * (item.unit_price ?? 0));
    }, 0);
  };

  /**
   * 税額を計算する
   * @returns 税額
   */
  const calcTax = (): number => {
    return (items ?? []).reduce((sum, item) => {
      if (item.item_type !== "normal") return sum;
      const amount = Math.floor((item.quantity ?? 0) * (item.unit_price ?? 0));
      return sum + Math.floor(amount * (item.tax_rate ?? 0) / 100);
    }, 0);
  };

  /**
   * フォームの送信を処理する
   * @param data - フォームデータ
   */
  const onSubmit = async (data: DocumentFormData) => {
    try {
      const payload = {
        document: {
          ...data,
          document_items_attributes: data.document_items_attributes.map(
            (item, idx) => ({
              ...item,
              sort_order: idx,
            })
          ),
        },
      };

      const res = await api.post<{ document: { id: string } }>(
        "/api/v1/documents",
        payload
      );
      toast.success("帳票を作成しました");
      router.push(`/documents/${res.document.id}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "帳票の作成に失敗しました");
      }
    }
  };

  /** 明細行を追加する */
  const addItem = () => {
    append({
      name: "",
      quantity: 1,
      unit_price: 0,
      tax_rate: 10,
      tax_rate_type: "standard",
      item_type: "normal",
      sort_order: fields.length,
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild className="size-10 sm:size-9">
          <Link href="/documents">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">帳票の新規作成</h1>
          <p className="mt-1 text-muted-foreground">
            新しい帳票を作成します
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">基本情報</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-3">
              <div className="space-y-2">
                <Label className="text-[15px]">
                  帳票種別 <span className="text-destructive">*</span>
                </Label>
                <Select
                  value={watch("document_type")}
                  onValueChange={(v) =>
                    setValue("document_type", v as DocumentType)
                  }
                >
                  <SelectTrigger className="h-11">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {DOC_TYPE_OPTIONS.map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">
                  顧客 <span className="text-destructive">*</span>
                </Label>
                <Select
                  value={watch("customer_id") ?? ""}
                  onValueChange={(v) => setValue("customer_id", v)}
                >
                  <SelectTrigger className="h-11">
                    <SelectValue placeholder="顧客を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {customers.map((c) => (
                      <SelectItem key={c.id} value={c.id}>
                        {c.company_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {errors.customer_id && (
                  <p className="text-sm text-destructive">
                    {errors.customer_id.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">タイトル</Label>
                <Input
                  {...register("title")}
                  className="h-11 text-[15px]"
                  placeholder="○○見積書"
                />
              </div>
            </div>

            <div className="grid gap-5 sm:grid-cols-3">
              <div className="space-y-2">
                <Label className="text-[15px]">
                  発行日 <span className="text-destructive">*</span>
                </Label>
                <Input
                  type="date"
                  {...register("issue_date")}
                  className="h-11 text-[15px]"
                />
                {errors.issue_date && (
                  <p className="text-sm text-destructive">
                    {errors.issue_date.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">支払期限</Label>
                <Input
                  type="date"
                  {...register("due_date")}
                  className="h-11 text-[15px]"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">有効期限</Label>
                <Input
                  type="date"
                  {...register("valid_until")}
                  className="h-11 text-[15px]"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">明細行</CardTitle>
            <Button type="button" variant="outline" size="sm" onClick={addItem}>
              <Plus className="mr-1.5 size-4" />
              行を追加
            </Button>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {/* PC用ヘッダー */}
              <div className="hidden sm:grid grid-cols-[1fr_80px_120px_120px_120px_40px] gap-2 text-xs font-medium text-muted-foreground px-1">
                <span>品名</span>
                <span className="text-right">数量</span>
                <span className="text-right">単価</span>
                <span>税率</span>
                <span className="text-right">金額</span>
                <span />
              </div>
              {fields.map((field, index) => {
                const qty = items?.[index]?.quantity ?? 0;
                const price = items?.[index]?.unit_price ?? 0;
                const amount = Math.floor(qty * price);

                return (
                  <div key={field.id}>
                    {/* PC用: 横一列グリッド */}
                    <div className="hidden sm:grid grid-cols-[1fr_80px_120px_120px_120px_40px] gap-2 items-center">
                      <Input
                        {...register(`document_items_attributes.${index}.name`)}
                        placeholder="品名"
                        className="h-10 text-[15px]"
                      />
                      <Input
                        type="number"
                        step="0.01"
                        {...register(
                          `document_items_attributes.${index}.quantity`,
                          { valueAsNumber: true }
                        )}
                        className="h-10 text-[15px] text-right"
                      />
                      <Input
                        type="number"
                        {...register(
                          `document_items_attributes.${index}.unit_price`,
                          { valueAsNumber: true }
                        )}
                        className="h-10 text-[15px] text-right"
                      />
                      <Select
                        value={items?.[index]?.tax_rate_type ?? "standard"}
                        onValueChange={(v) => {
                          setValue(
                            `document_items_attributes.${index}.tax_rate_type`,
                            v as "standard" | "reduced" | "exempt"
                          );
                          const opt = TAX_RATE_OPTIONS.find(
                            (o) => o.value === v
                          );
                          if (opt) {
                            setValue(
                              `document_items_attributes.${index}.tax_rate`,
                              opt.rate
                            );
                          }
                        }}
                      >
                        <SelectTrigger className="h-10">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {TAX_RATE_OPTIONS.map((opt) => (
                            <SelectItem key={opt.value} value={opt.value}>
                              {opt.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <p className="text-right tabular-nums text-[15px] font-medium">
                        ¥{amount.toLocaleString()}
                      </p>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8"
                        onClick={() => remove(index)}
                        disabled={fields.length <= 1}
                      >
                        <Trash2 className="size-4 text-muted-foreground" />
                      </Button>
                    </div>

                    {/* SP用: カード型スタックレイアウト */}
                    <div className="sm:hidden rounded-md border p-3 space-y-3">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-medium text-muted-foreground">明細 {index + 1}</span>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="size-7"
                          onClick={() => remove(index)}
                          disabled={fields.length <= 1}
                        >
                          <Trash2 className="size-3.5 text-muted-foreground" />
                        </Button>
                      </div>
                      <div className="space-y-1.5">
                        <Label className="text-xs text-muted-foreground">品名</Label>
                        <Input
                          {...register(`document_items_attributes.${index}.name`)}
                          placeholder="品名"
                          className="h-10 text-[15px]"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-3">
                        <div className="space-y-1.5">
                          <Label className="text-xs text-muted-foreground">数量</Label>
                          <Input
                            type="number"
                            step="0.01"
                            {...register(
                              `document_items_attributes.${index}.quantity`,
                              { valueAsNumber: true }
                            )}
                            className="h-10 text-[15px] text-right"
                          />
                        </div>
                        <div className="space-y-1.5">
                          <Label className="text-xs text-muted-foreground">単価</Label>
                          <Input
                            type="number"
                            {...register(
                              `document_items_attributes.${index}.unit_price`,
                              { valueAsNumber: true }
                            )}
                            className="h-10 text-[15px] text-right"
                          />
                        </div>
                      </div>
                      <div className="grid grid-cols-2 gap-3 items-end">
                        <div className="space-y-1.5">
                          <Label className="text-xs text-muted-foreground">税率</Label>
                          <Select
                            value={items?.[index]?.tax_rate_type ?? "standard"}
                            onValueChange={(v) => {
                              setValue(
                                `document_items_attributes.${index}.tax_rate_type`,
                                v as "standard" | "reduced" | "exempt"
                              );
                              const opt = TAX_RATE_OPTIONS.find(
                                (o) => o.value === v
                              );
                              if (opt) {
                                setValue(
                                  `document_items_attributes.${index}.tax_rate`,
                                  opt.rate
                                );
                              }
                            }}
                          >
                            <SelectTrigger className="h-10">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {TAX_RATE_OPTIONS.map((opt) => (
                                <SelectItem key={opt.value} value={opt.value}>
                                  {opt.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="text-right">
                          <Label className="text-xs text-muted-foreground">金額</Label>
                          <p className="tabular-nums text-[15px] font-medium mt-1.5">
                            ¥{amount.toLocaleString()}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
              {errors.document_items_attributes?.message && (
                <p className="text-sm text-destructive">
                  {errors.document_items_attributes.message}
                </p>
              )}
            </div>

            <Separator className="my-4" />

            <div className="flex sm:justify-end">
              <div className="w-full sm:w-[280px] space-y-2">
                <div className="flex justify-between text-[15px]">
                  <span className="text-muted-foreground">小計</span>
                  <span className="tabular-nums">
                    ¥{calcSubtotal().toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between text-[15px]">
                  <span className="text-muted-foreground">消費税</span>
                  <span className="tabular-nums">
                    ¥{calcTax().toLocaleString()}
                  </span>
                </div>
                <Separator />
                <div className="flex justify-between text-lg font-bold">
                  <span>合計</span>
                  <span className="tabular-nums">
                    ¥{(calcSubtotal() + calcTax()).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">備考</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="space-y-2">
              <Label className="text-[15px]">備考（顧客に表示されます）</Label>
              <textarea
                {...register("notes")}
                className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                placeholder="支払条件、納品条件など"
              />
            </div>
            <div className="space-y-2">
              <Label className="text-[15px]">社内メモ（非公開）</Label>
              <textarea
                {...register("internal_memo")}
                className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                placeholder="社内共有メモ"
              />
            </div>
          </CardContent>
        </Card>

        <div className="flex justify-end gap-3">
          <Button variant="outline" type="button" asChild>
            <Link href="/documents">キャンセル</Link>
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
            <Save className="mr-2 size-4" />
            作成する
          </Button>
        </div>
      </form>
    </div>
  );
}
