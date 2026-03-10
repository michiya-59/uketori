"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
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
  Package,
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
import { Skeleton } from "@/components/ui/skeleton";
import { api, ApiClientError } from "@/lib/api-client";
import {
  ProductPickerDialog,
  type ProductSelection,
} from "@/components/documents/product-picker-dialog";
import type { Customer } from "@/types/customer";
import type { DocumentType } from "@/types/document";

/** 明細行のバリデーションスキーマ */
const itemSchema = z.object({
  id: z.number().optional(),
  name: z.string().min(1, "品名を入力してください"),
  description: z.string().optional(),
  quantity: z.number().min(0.01, "数量を入力してください"),
  unit: z.string().optional(),
  unit_price: z.number().min(0, "単価を入力してください"),
  tax_rate: z.number().min(0).max(100),
  tax_rate_type: z.enum(["standard", "reduced", "exempt"]),
  item_type: z.string(),
  sort_order: z.number(),
  _destroy: z.boolean().optional(),
});

/** 帳票編集フォームのバリデーションスキーマ */
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

/** 帳票詳細レスポンス内の帳票型 */
interface DocumentDetail {
  id: string;
  document_type: DocumentType;
  customer_id: string | null;
  title: string | null;
  issue_date: string | null;
  due_date: string | null;
  valid_until: string | null;
  notes: string | null;
  internal_memo: string | null;
  locked_at: string | null;
  items: {
    id: number;
    name: string;
    description: string | null;
    quantity: number;
    unit: string | null;
    unit_price: number;
    tax_rate: number;
    tax_rate_type: string;
    item_type: string;
    sort_order: number;
  }[];
}

/**
 * 帳票編集ページ
 * 既存の帳票を編集するフォームを提供する
 * @returns 帳票編集ページ要素
 */
export default function EditDocumentPage() {
  const params = useParams();
  const router = useRouter();
  const uuid = params.uuid as string;
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [productPickerOpen, setProductPickerOpen] = useState(false);

  const {
    register,
    handleSubmit,
    control,
    setValue,
    watch,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<DocumentFormData>({
    resolver: zodResolver(documentSchema),
    defaultValues: {
      document_items_attributes: [],
    },
  });

  // バリデーションエラーをコンソールに出力（デバッグ用）
  useEffect(() => {
    if (Object.keys(errors).length > 0) {
      console.log("Form validation errors:", errors);
    }
  }, [errors]);

  const { fields, append, remove } = useFieldArray({
    control,
    name: "document_items_attributes",
  });

  const items = watch("document_items_attributes");

  /** 顧客一覧を取得する */
  const loadCustomers = useCallback(async () => {
    try {
      const res = await api.get<CustomersResponse>("/api/v1/customers", {
        per_page: 100,
      });
      setCustomers(res.customers);
    } catch {
      // silently fail
    }
  }, []);

  /** 帳票データを取得してフォームにセットする */
  const loadDocument = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ document: DocumentDetail }>(
        `/api/v1/documents/${uuid}`
      );
      const doc = res.document;

      if (doc.locked_at) {
        toast.error("ロック済みの帳票は編集できません");
        router.push(`/documents/${uuid}`);
        return;
      }

      reset({
        document_type: doc.document_type,
        customer_id: doc.customer_id ?? "",
        title: doc.title ?? "",
        issue_date: doc.issue_date ?? "",
        due_date: doc.due_date ?? "",
        valid_until: doc.valid_until ?? "",
        notes: doc.notes ?? "",
        internal_memo: doc.internal_memo ?? "",
        document_items_attributes: doc.items.map((item) => ({
          id: item.id,
          name: item.name,
          description: item.description ?? "",
          quantity: item.quantity,
          unit: item.unit ?? "",
          unit_price: item.unit_price,
          tax_rate: Number(item.tax_rate),
          tax_rate_type: item.tax_rate_type as "standard" | "reduced" | "exempt",
          item_type: item.item_type,
          sort_order: item.sort_order,
        })),
      });
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "帳票情報の取得に失敗しました");
      }
      router.push("/documents");
    } finally {
      setLoading(false);
    }
  }, [uuid, reset, router]);

  useEffect(() => {
    loadCustomers();
    loadDocument();
  }, [loadCustomers, loadDocument]);

  /**
   * 小計を計算する
   * @returns 小計金額
   */
  const calcSubtotal = (): number => {
    return (items ?? []).reduce((sum, item) => {
      if (item._destroy || item.item_type !== "normal") return sum;
      return sum + Math.floor((item.quantity ?? 0) * (item.unit_price ?? 0));
    }, 0);
  };

  /**
   * 税額を計算する
   * @returns 税額
   */
  const calcTax = (): number => {
    return (items ?? []).reduce((sum, item) => {
      if (item._destroy || item.item_type !== "normal") return sum;
      const amount = Math.floor((item.quantity ?? 0) * (item.unit_price ?? 0));
      return sum + Math.floor((amount * (item.tax_rate ?? 0)) / 100);
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

      await api.patch(`/api/v1/documents/${uuid}`, payload);
      toast.success("帳票を更新しました");
      router.push(`/documents/${uuid}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "帳票の更新に失敗しました");
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

  /**
   * 品目マスタから選択して明細行を追加する
   * @param product - 選択された品目データ
   */
  const addFromProduct = (product: ProductSelection) => {
    append({
      name: product.name,
      quantity: 1,
      unit_price: product.unit_price,
      tax_rate: product.tax_rate,
      tax_rate_type: product.tax_rate_type,
      item_type: "normal",
      sort_order: fields.length,
    });
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
          <Link href={`/documents/${uuid}`}>
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">帳票の編集</h1>
          <p className="mt-1 text-muted-foreground">
            帳票の内容を更新します
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
              {["invoice", "purchase_order"].includes(watch("document_type")) && (
                <div className="space-y-2">
                  <Label className="text-[15px]">支払期限</Label>
                  <Input
                    type="date"
                    {...register("due_date")}
                    className="h-11 text-[15px]"
                  />
                </div>
              )}
              {watch("document_type") === "estimate" && (
                <div className="space-y-2">
                  <Label className="text-[15px]">有効期限</Label>
                  <Input
                    type="date"
                    {...register("valid_until")}
                    className="h-11 text-[15px]"
                  />
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">明細行</CardTitle>
            <div className="flex gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setProductPickerOpen(true)}
              >
                <Package className="mr-1.5 size-4" />
                品目から追加
              </Button>
              <Button type="button" variant="outline" size="sm" onClick={addItem}>
                <Plus className="mr-1.5 size-4" />
                手入力で追加
              </Button>
            </div>
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
                const item = items?.[index];
                if (item?._destroy) return null;
                const qty = item?.quantity ?? 0;
                const price = item?.unit_price ?? 0;
                const amount = Math.floor(qty * price);
                const activeCount = fields.filter((_, i) => !items?.[i]?._destroy).length;

                /** 明細行を削除（既存行は_destroy、新規行はremove） */
                const handleRemove = () => {
                  if (item?.id) {
                    setValue(`document_items_attributes.${index}._destroy`, true);
                  } else {
                    remove(index);
                  }
                };

                return (
                  <div key={field.id} className="rounded-md border p-3 sm:border-0 sm:p-0">
                    {/* SP用: 明細番号ヘッダー */}
                    <div className="flex items-center justify-between sm:hidden mb-3">
                      <span className="text-xs font-medium text-muted-foreground">明細 {index + 1}</span>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-7"
                        onClick={handleRemove}
                        disabled={activeCount <= 1}
                      >
                        <Trash2 className="size-3.5 text-muted-foreground" />
                      </Button>
                    </div>

                    {/* レスポンシブグリッド: SP=2列, PC=6列 */}
                    <div className="grid grid-cols-2 sm:grid-cols-[1fr_80px_120px_120px_120px_40px] gap-3 sm:gap-2 items-end sm:items-center">
                      {/* 品名 (SP: 2列幅, PC: 1列) */}
                      <div className="col-span-2 sm:col-span-1 space-y-1.5">
                        <Label className="text-xs text-muted-foreground sm:hidden">品名</Label>
                        <Input
                          {...register(`document_items_attributes.${index}.name`)}
                          placeholder="品名"
                          className="h-10 text-[15px]"
                        />
                      </div>

                      {/* 数量 */}
                      <div className="space-y-1.5">
                        <Label className="text-xs text-muted-foreground sm:hidden">数量</Label>
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

                      {/* 単価 */}
                      <div className="space-y-1.5">
                        <Label className="text-xs text-muted-foreground sm:hidden">単価</Label>
                        <Input
                          type="number"
                          {...register(
                            `document_items_attributes.${index}.unit_price`,
                            { valueAsNumber: true }
                          )}
                          className="h-10 text-[15px] text-right"
                        />
                      </div>

                      {/* 税率 */}
                      <div className="space-y-1.5">
                        <Label className="text-xs text-muted-foreground sm:hidden">税率</Label>
                        <Select
                          value={item?.tax_rate_type ?? "standard"}
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

                      {/* 金額 */}
                      <div className="space-y-1.5">
                        <Label className="text-xs text-muted-foreground sm:hidden">金額</Label>
                        <p className="text-right tabular-nums text-[15px] font-medium h-10 flex items-center justify-end">
                          ¥{amount.toLocaleString()}
                        </p>
                      </div>

                      {/* PC用: 削除ボタン */}
                      <div className="hidden sm:flex justify-center">
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="size-8"
                          onClick={handleRemove}
                          disabled={activeCount <= 1}
                        >
                          <Trash2 className="size-4 text-muted-foreground" />
                        </Button>
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
            <Link href={`/documents/${uuid}`}>キャンセル</Link>
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
            <Save className="mr-2 size-4" />
            更新する
          </Button>
        </div>
      </form>

      <ProductPickerDialog
        open={productPickerOpen}
        onOpenChange={setProductPickerOpen}
        onSelect={addFromProduct}
      />
    </div>
  );
}
