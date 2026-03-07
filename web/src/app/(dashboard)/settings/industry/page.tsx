"use client";

import { useEffect, useState, useCallback } from "react";
import { Loader2, Factory, Check, Package, Tag } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { api, ApiClientError } from "@/lib/api-client";
import { SettingsNav } from "@/components/settings/settings-nav";

/** 業種テンプレートの一覧アイテム型 */
interface IndustryTemplate {
  code: string;
  name: string;
  sort_order: number;
}

/** 業種テンプレートの詳細型 */
interface IndustryTemplateDetail extends IndustryTemplate {
  labels: Record<string, string>;
  default_products: Array<{ name: string; unit: string; tax_rate_type: string }>;
  default_statuses: Array<{ key: string; label: string }> | null;
  tax_settings: Record<string, unknown> | null;
}

/** テナントAPIのレスポンス型 */
interface TenantData {
  tenant: {
    industry_type: string;
    [key: string]: unknown;
  };
}

/**
 * 業種テンプレート設定ページ
 * 業種を選択し、用語・デフォルト品目のプレビューを表示する
 * @returns 業種テンプレート設定ページ要素
 */
export default function IndustrySettingsPage() {
  const [loading, setLoading] = useState(true);
  const [templates, setTemplates] = useState<IndustryTemplate[]>([]);
  const [currentIndustry, setCurrentIndustry] = useState<string>("");
  const [selectedCode, setSelectedCode] = useState<string | null>(null);
  const [detail, setDetail] = useState<IndustryTemplateDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [saving, setSaving] = useState(false);

  /**
   * テンプレート一覧と現在のテナント業種を読み込む
   */
  const loadData = useCallback(async () => {
    try {
      const [templatesRes, tenantRes] = await Promise.all([
        api.get<{ industry_templates: IndustryTemplate[] }>("/api/v1/industry_templates"),
        api.get<TenantData>("/api/v1/tenant"),
      ]);
      setTemplates(templatesRes.industry_templates);
      setCurrentIndustry(tenantRes.tenant.industry_type);
    } catch {
      toast.error("データの読み込みに失敗しました");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  /**
   * テンプレートを選択し詳細を読み込む
   * @param code - テンプレートコード
   */
  const handleSelect = async (code: string) => {
    setSelectedCode(code);
    setDetailLoading(true);
    try {
      const res = await api.get<{ industry_template: IndustryTemplateDetail }>(
        `/api/v1/industry_templates/${code}`
      );
      setDetail(res.industry_template);
    } catch {
      toast.error("テンプレート詳細の取得に失敗しました");
    } finally {
      setDetailLoading(false);
    }
  };

  /**
   * 選択した業種をテナントに適用する
   */
  const handleApply = async () => {
    if (!selectedCode) return;
    setSaving(true);
    try {
      await api.patch("/api/v1/tenant", {
        tenant: { industry_type: selectedCode },
      });
      setCurrentIndustry(selectedCode);
      toast.success("業種設定を更新しました");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "更新に失敗しました");
      }
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-4 sm:space-y-6">
        <div>
          <Skeleton className="h-8 w-48" />
          <Skeleton className="mt-2 h-5 w-80" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      <SettingsNav />
      <div>
        <h1 className="text-xl sm:text-2xl font-bold tracking-tight">業種テンプレート</h1>
        <p className="text-sm text-muted-foreground">
          業種を選択すると、用語やデフォルト品目が自動設定されます
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {templates.map((t) => {
          const isActive = t.code === currentIndustry;
          const isSelected = t.code === selectedCode;

          return (
            <Card
              key={t.code}
              className={`cursor-pointer transition-all ${
                isSelected
                  ? "ring-2 ring-primary border-primary"
                  : isActive
                    ? "border-primary/50 bg-primary/5"
                    : "hover:border-muted-foreground/50"
              }`}
              onClick={() => handleSelect(t.code)}
            >
              <CardContent className="flex items-center gap-3 p-4">
                <Factory className={`size-5 shrink-0 ${isActive ? "text-primary" : "text-muted-foreground"}`} />
                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-medium truncate">{t.name}</p>
                  <p className="text-xs text-muted-foreground">{t.code}</p>
                </div>
                {isActive && (
                  <Badge variant="secondary" className="shrink-0 gap-1">
                    <Check className="size-3" />
                    現在
                  </Badge>
                )}
              </CardContent>
            </Card>
          );
        })}
      </div>

      {selectedCode && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">
              {detail?.name ?? selectedCode} のプレビュー
            </CardTitle>
            <CardDescription>
              この業種を選択した場合に適用される設定のプレビューです
            </CardDescription>
          </CardHeader>
          <CardContent>
            {detailLoading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="size-6 animate-spin text-muted-foreground" />
              </div>
            ) : detail ? (
              <div className="space-y-6">
                {detail.labels && Object.keys(detail.labels).length > 0 && (
                  <div>
                    <h3 className="flex items-center gap-2 text-[15px] font-medium mb-3">
                      <Tag className="size-4" />
                      用語設定
                    </h3>
                    <div className="grid gap-2 sm:grid-cols-2">
                      {Object.entries(detail.labels).map(([key, value]) => (
                        <div
                          key={key}
                          className="flex items-center justify-between rounded-md border px-4 py-2.5"
                        >
                          <span className="text-sm text-muted-foreground">{key}</span>
                          <span className="text-[15px] font-medium">{value}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <Separator />

                {detail.default_products && detail.default_products.length > 0 && (
                  <div>
                    <h3 className="flex items-center gap-2 text-[15px] font-medium mb-3">
                      <Package className="size-4" />
                      デフォルト品目
                    </h3>
                    <div className="space-y-2">
                      {detail.default_products.map((p, i) => (
                        <div
                          key={i}
                          className="flex items-center justify-between rounded-md border px-4 py-2.5"
                        >
                          <span className="text-[15px]">{p.name}</span>
                          <Badge variant="outline">{p.unit}</Badge>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <Separator />

                <div className="flex justify-end">
                  {selectedCode === currentIndustry ? (
                    <Button disabled className="h-11 gap-2 text-[15px]">
                      <Check className="size-4" />
                      現在の業種です
                    </Button>
                  ) : (
                    <Button
                      onClick={handleApply}
                      disabled={saving}
                      className="h-11 gap-2 text-[15px]"
                    >
                      {saving && <Loader2 className="size-4 animate-spin" />}
                      この業種に変更する
                    </Button>
                  )}
                </div>
              </div>
            ) : null}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
