"use client";

import { useEffect, useState, useCallback } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Plus,
  Pencil,
  Trash2,
  Loader2,
  Lock,
  Package,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Separator } from "@/components/ui/separator";
import { SettingsNav } from "@/components/settings/settings-nav";
import { api, ApiClientError } from "@/lib/api-client";

/** 品目の型定義 */
interface Product {
  id: number;
  code: string | null;
  name: string;
  description: string | null;
  unit: string | null;
  unit_price: number | null;
  tax_rate: number | null;
  tax_rate_type: string;
  category: string | null;
  sort_order: number;
  is_active: boolean;
  is_default: boolean;
}

/** 品目一覧APIレスポンス型 */
interface ProductsResponse {
  products: Product[];
  meta: { total_count: number };
}

/** 品目フォームのバリデーションスキーマ */
const productFormSchema = z.object({
  name: z.string().min(1, "品名を入力してください"),
  unit: z.string().optional(),
  unit_price: z.number().min(0, "0以上の値を入力してください"),
  tax_rate_type: z.enum(["standard", "reduced", "exempt"]),
  category: z.string().optional(),
  description: z.string().optional(),
});

type ProductFormData = z.infer<typeof productFormSchema>;

/** 税率オプション */
const TAX_RATE_OPTIONS = [
  { value: "standard", label: "10%（標準）" },
  { value: "reduced", label: "8%（軽減）" },
  { value: "exempt", label: "0%（非課税）" },
];

/**
 * 品目マスタ管理ページ
 * デフォルト品目の閲覧、カスタム品目の追加・編集・削除を提供する
 * @returns 品目管理ページ要素
 */
export default function ProductsSettingsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [formOpen, setFormOpen] = useState(false);
  const [editingProduct, setEditingProduct] = useState<Product | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Product | null>(null);
  const [deleting, setDeleting] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<ProductFormData>({
    resolver: zodResolver(productFormSchema),
    defaultValues: {
      name: "",
      unit: "",
      unit_price: 0,
      tax_rate_type: "standard",
      category: "",
      description: "",
    },
  });

  /** 品目一覧を取得する */
  const loadProducts = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<ProductsResponse>("/api/v1/products", {
        per_page: 100,
        "filter[active]": "false",
      });
      setProducts(res.products);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("品目一覧の取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadProducts();
  }, [loadProducts]);

  /** 新規追加ダイアログを開く */
  const openCreateDialog = () => {
    setEditingProduct(null);
    reset({
      name: "",
      unit: "",
      unit_price: 0,
      tax_rate_type: "standard",
      category: "",
      description: "",
    });
    setFormOpen(true);
  };

  /**
   * 編集ダイアログを開く
   * @param product - 編集対象の品目
   */
  const openEditDialog = (product: Product) => {
    setEditingProduct(product);
    reset({
      name: product.name,
      unit: product.unit ?? "",
      unit_price: product.unit_price ?? 0,
      tax_rate_type: product.tax_rate_type as "standard" | "reduced" | "exempt",
      category: product.category ?? "",
      description: product.description ?? "",
    });
    setFormOpen(true);
  };

  /**
   * 品目を保存する（新規作成または更新）
   * @param data - フォームデータ
   */
  const onSubmit = async (data: ProductFormData) => {
    try {
      const payload = { product: data };
      if (editingProduct) {
        await api.patch(`/api/v1/products/${editingProduct.id}`, payload);
        toast.success("品目を更新しました");
      } else {
        await api.post("/api/v1/products", payload);
        toast.success("品目を追加しました");
      }
      setFormOpen(false);
      loadProducts();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "品目の保存に失敗しました");
      }
    }
  };

  /**
   * 品目を削除する
   */
  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      setDeleting(true);
      await api.delete(`/api/v1/products/${deleteTarget.id}`);
      toast.success("品目を削除しました");
      setDeleteTarget(null);
      loadProducts();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "品目の削除に失敗しました");
      }
    } finally {
      setDeleting(false);
    }
  };

  const defaultProducts = products.filter((p) => p.is_default);
  const customProducts = products.filter((p) => !p.is_default);

  return (
    <div className="space-y-6">
      <SettingsNav />

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">品目マスタ</h1>
          <p className="mt-1 text-muted-foreground">
            帳票作成時に使用する品目を管理します
          </p>
        </div>
        <Button onClick={openCreateDialog}>
          <Plus className="mr-1.5 size-4" />
          品目を追加
        </Button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="size-6 animate-spin text-muted-foreground" />
        </div>
      ) : (
        <div className="space-y-6">
          {/* デフォルト品目 */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Lock className="size-4 text-muted-foreground" />
                デフォルト品目
              </CardTitle>
              <p className="text-sm text-muted-foreground">
                業種テンプレートから自動登録された品目です。編集・削除はできません。
              </p>
            </CardHeader>
            <CardContent>
              {defaultProducts.length === 0 ? (
                <p className="text-sm text-muted-foreground py-4 text-center">
                  デフォルト品目はありません
                </p>
              ) : (
                <div className="space-y-2">
                  {defaultProducts.map((product) => (
                    <div
                      key={product.id}
                      className="flex items-center justify-between rounded-md border px-4 py-3 bg-muted/30"
                    >
                      <div className="flex items-center gap-3">
                        <Package className="size-4 text-muted-foreground shrink-0" />
                        <div>
                          <span className="text-[15px] font-medium">{product.name}</span>
                          <div className="flex items-center gap-2 mt-0.5">
                            {product.unit && (
                              <span className="text-xs text-muted-foreground">単位: {product.unit}</span>
                            )}
                            {product.unit_price != null && product.unit_price > 0 && (
                              <span className="text-xs text-muted-foreground">
                                ¥{product.unit_price.toLocaleString()}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge variant="secondary" className="text-xs">
                          {TAX_RATE_OPTIONS.find((o) => o.value === product.tax_rate_type)?.label ?? "10%"}
                        </Badge>
                        <Badge variant="outline" className="text-xs">
                          デフォルト
                        </Badge>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* カスタム品目 */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">カスタム品目</CardTitle>
              <p className="text-sm text-muted-foreground">
                独自に追加した品目です。自由に編集・削除できます。
              </p>
            </CardHeader>
            <CardContent>
              {customProducts.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-8 text-muted-foreground">
                  <Package className="size-8 mb-2" />
                  <p className="text-sm">カスタム品目はまだありません</p>
                  <Button
                    variant="outline"
                    size="sm"
                    className="mt-3"
                    onClick={openCreateDialog}
                  >
                    <Plus className="mr-1.5 size-4" />
                    品目を追加
                  </Button>
                </div>
              ) : (
                <div className="space-y-2">
                  {customProducts.map((product) => (
                    <div
                      key={product.id}
                      className="flex items-center justify-between rounded-md border px-4 py-3"
                    >
                      <div className="flex items-center gap-3">
                        <Package className="size-4 text-muted-foreground shrink-0" />
                        <div>
                          <span className="text-[15px] font-medium">{product.name}</span>
                          <div className="flex items-center gap-2 mt-0.5">
                            {product.unit && (
                              <span className="text-xs text-muted-foreground">単位: {product.unit}</span>
                            )}
                            {product.unit_price != null && product.unit_price > 0 && (
                              <span className="text-xs text-muted-foreground">
                                ¥{product.unit_price.toLocaleString()}
                              </span>
                            )}
                            {product.category && (
                              <span className="text-xs text-muted-foreground">{product.category}</span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge variant="secondary" className="text-xs">
                          {TAX_RATE_OPTIONS.find((o) => o.value === product.tax_rate_type)?.label ?? "10%"}
                        </Badge>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8"
                          onClick={() => openEditDialog(product)}
                        >
                          <Pencil className="size-3.5" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-8 text-destructive hover:text-destructive"
                          onClick={() => setDeleteTarget(product)}
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* 品目追加・編集ダイアログ */}
      <Dialog open={formOpen} onOpenChange={setFormOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{editingProduct ? "品目を編集" : "品目を追加"}</DialogTitle>
            <DialogDescription>
              {editingProduct
                ? "品目の情報を編集します"
                : "新しい品目を追加します。帳票作成時に選択できるようになります。"}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label>
                品名 <span className="text-destructive">*</span>
              </Label>
              <Input
                {...register("name")}
                placeholder="例: Webサイト構築"
                className="h-10"
              />
              {errors.name && (
                <p className="text-sm text-destructive">{errors.name.message}</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>単位</Label>
                <Input
                  {...register("unit")}
                  placeholder="例: 式, 時間, 個"
                  className="h-10"
                />
              </div>
              <div className="space-y-2">
                <Label>単価</Label>
                <Input
                  type="number"
                  {...register("unit_price", { valueAsNumber: true })}
                  placeholder="0"
                  className="h-10 text-right"
                />
                {errors.unit_price && (
                  <p className="text-sm text-destructive">{errors.unit_price.message}</p>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>税率</Label>
                <Select
                  value={watch("tax_rate_type")}
                  onValueChange={(v) =>
                    setValue("tax_rate_type", v as "standard" | "reduced" | "exempt")
                  }
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
              <div className="space-y-2">
                <Label>カテゴリ</Label>
                <Input
                  {...register("category")}
                  placeholder="例: 開発, デザイン"
                  className="h-10"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label>説明</Label>
              <Input
                {...register("description")}
                placeholder="品目の補足説明"
                className="h-10"
              />
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setFormOpen(false)}
              >
                キャンセル
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
                {editingProduct ? "更新する" : "追加する"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* 削除確認ダイアログ */}
      <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>品目を削除しますか？</AlertDialogTitle>
            <AlertDialogDescription>
              「{deleteTarget?.name}」を削除します。この操作は取り消せません。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {deleting && <Loader2 className="mr-2 size-4 animate-spin" />}
              削除する
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
