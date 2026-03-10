"use client";

import { useCallback, useEffect, useState } from "react";
import { Search, Package, Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { api, ApiClientError } from "@/lib/api-client";

/** 品目マスタの型 */
export interface Product {
  id: number;
  code: string | null;
  name: string;
  description: string | null;
  unit: string | null;
  unit_price: number | null;
  tax_rate: number | null;
  tax_rate_type: string;
  category: string | null;
  is_active: boolean;
  is_default: boolean;
}

/** 品目一覧APIレスポンス型 */
interface ProductsResponse {
  products: Product[];
  meta: { total_count: number };
}

/** 品目選択時に渡されるデータ */
export interface ProductSelection {
  name: string;
  unit: string;
  unit_price: number;
  tax_rate: number;
  tax_rate_type: "standard" | "reduced" | "exempt";
}

interface ProductPickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelect: (product: ProductSelection) => void;
}

/** 税率種別のラベルマッピング */
const TAX_RATE_TYPE_LABELS: Record<string, string> = {
  standard: "10%",
  reduced: "8%",
  exempt: "非課税",
};

/** 税率種別に対応する税率値 */
const TAX_RATE_VALUES: Record<string, number> = {
  standard: 10,
  reduced: 8,
  exempt: 0,
};

/**
 * 品目マスタから明細行に追加するための選択ダイアログ
 * @param open - ダイアログの開閉状態
 * @param onOpenChange - 開閉状態変更ハンドラ
 * @param onSelect - 品目選択ハンドラ
 */
export function ProductPickerDialog({
  open,
  onOpenChange,
  onSelect,
}: ProductPickerDialogProps) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  /** 品目一覧を取得する */
  const loadProducts = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<ProductsResponse>("/api/v1/products", {
        per_page: 100,
        "filter[active]": "true",
      });
      setProducts(res.products);
    } catch (e) {
      if (e instanceof ApiClientError) {
        console.error("品目一覧の取得に失敗しました", e);
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (open) {
      loadProducts();
      setSearchQuery("");
    }
  }, [open, loadProducts]);

  /** 検索クエリでフィルタした品目一覧 */
  const filteredProducts = products.filter(
    (p) =>
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.code && p.code.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.category && p.category.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  /**
   * 品目を選択して親コンポーネントに通知する
   * @param product - 選択された品目
   */
  const handleSelect = (product: Product) => {
    const taxRateType = (["standard", "reduced", "exempt"].includes(product.tax_rate_type)
      ? product.tax_rate_type
      : "standard") as "standard" | "reduced" | "exempt";

    onSelect({
      name: product.name,
      unit: product.unit ?? "",
      unit_price: product.unit_price ?? 0,
      tax_rate: product.tax_rate ?? TAX_RATE_VALUES[taxRateType] ?? 10,
      tax_rate_type: taxRateType,
    });
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>品目マスタから追加</DialogTitle>
          <DialogDescription>
            品目を選択すると明細行に追加されます
          </DialogDescription>
        </DialogHeader>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
          <Input
            placeholder="品名・コード・カテゴリで検索"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 h-10"
          />
        </div>
        <ScrollArea className="max-h-[360px]">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="size-5 animate-spin text-muted-foreground" />
            </div>
          ) : filteredProducts.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-8 text-muted-foreground">
              <Package className="size-8 mb-2" />
              <p className="text-sm">
                {products.length === 0
                  ? "品目が登録されていません"
                  : "該当する品目がありません"}
              </p>
            </div>
          ) : (
            <div className="space-y-1">
              {filteredProducts.map((product) => (
                <button
                  key={product.id}
                  type="button"
                  onClick={() => handleSelect(product)}
                  className="w-full text-left rounded-md px-3 py-2.5 hover:bg-accent transition-colors"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-[15px] font-medium">{product.name}</span>
                    <div className="flex items-center gap-2">
                      {product.unit && (
                        <Badge variant="secondary" className="text-xs">
                          {product.unit}
                        </Badge>
                      )}
                      <Badge variant="outline" className="text-xs">
                        {TAX_RATE_TYPE_LABELS[product.tax_rate_type] ?? "10%"}
                      </Badge>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 mt-0.5">
                    {product.unit_price != null && product.unit_price > 0 && (
                      <span className="text-sm text-muted-foreground tabular-nums">
                        ¥{product.unit_price.toLocaleString()}
                      </span>
                    )}
                    {product.category && (
                      <span className="text-xs text-muted-foreground">
                        {product.category}
                      </span>
                    )}
                  </div>
                </button>
              ))}
            </div>
          )}
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
}
