"use client";

import { useEffect, useState, useCallback } from "react";
import { CreditCard, Check, X } from "lucide-react";
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
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { api, ApiClientError } from "@/lib/api-client";
import type { Tenant, TenantPlan } from "@/types/tenant";

/** プラン情報の定義 */
interface PlanInfo {
  name: string;
  price: string;
  users: string;
  documents: string;
  customers: string;
  aiMatching: boolean;
  autoDunning: boolean;
}

/** プラン別機能一覧 */
const PLANS: Record<TenantPlan, PlanInfo> = {
  free: {
    name: "Free",
    price: "¥0",
    users: "1名",
    documents: "月5件",
    customers: "10社",
    aiMatching: false,
    autoDunning: false,
  },
  starter: {
    name: "Starter",
    price: "¥2,980/月",
    users: "3名",
    documents: "月50件",
    customers: "100社",
    aiMatching: true,
    autoDunning: true,
  },
  standard: {
    name: "Standard",
    price: "¥9,800/月",
    users: "10名",
    documents: "無制限",
    customers: "500社",
    aiMatching: true,
    autoDunning: true,
  },
  professional: {
    name: "Professional",
    price: "¥29,800/月",
    users: "30名",
    documents: "無制限",
    customers: "無制限",
    aiMatching: true,
    autoDunning: true,
  },
};

/** プランの順序 */
const PLAN_ORDER: TenantPlan[] = ["free", "starter", "standard", "professional"];

/**
 * プラン設定ページ
 * 現在のプラン表示とプラン比較テーブルを提供する
 * @returns プラン設定ページ要素
 */
export default function BillingPage() {
  const [tenant, setTenant] = useState<Tenant | null>(null);
  const [loading, setLoading] = useState(true);

  /** テナント情報を取得する */
  const loadTenant = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ tenant: Tenant }>("/api/v1/tenant");
      setTenant(res.tenant);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "プラン情報の取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTenant();
  }, [loadTenant]);

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-32 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  const currentPlan = tenant?.plan ?? "free";
  const planInfo = PLANS[currentPlan];

  return (
    <div className="space-y-4 sm:space-y-6">
      <div>
        <h1 className="text-xl sm:text-2xl font-bold tracking-tight">プラン設定</h1>
        <p className="text-sm text-muted-foreground">
          ご利用プランの確認と変更を行います
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-lg">
            <CreditCard className="size-5" />
            現在のプラン
          </CardTitle>
          <CardDescription>
            現在ご利用中のプラン情報です
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-2xl font-bold">{planInfo.name}</span>
                <Badge variant="default">利用中</Badge>
              </div>
              <p className="text-lg text-muted-foreground mt-1">
                {planInfo.price}
              </p>
            </div>
          </div>
          <div className="mt-4 grid gap-3 sm:grid-cols-3 text-sm">
            <div>
              <span className="text-muted-foreground">ユーザー数:</span>{" "}
              <span className="font-medium">{planInfo.users}</span>
            </div>
            <div>
              <span className="text-muted-foreground">帳票数:</span>{" "}
              <span className="font-medium">{planInfo.documents}</span>
            </div>
            <div>
              <span className="text-muted-foreground">顧客数:</span>{" "}
              <span className="font-medium">{planInfo.customers}</span>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">プラン比較</CardTitle>
          <CardDescription>
            各プランの機能を比較できます
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[180px]">機能</TableHead>
                {PLAN_ORDER.map((plan) => (
                  <TableHead key={plan} className="text-center">
                    <div className="flex flex-col items-center gap-1">
                      <span className="font-medium">{PLANS[plan].name}</span>
                      {plan === currentPlan && (
                        <Badge variant="outline" className="text-xs">
                          現在
                        </Badge>
                      )}
                    </div>
                  </TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow>
                <TableCell className="font-medium">月額料金</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    {PLANS[plan].price}
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                <TableCell className="font-medium">ユーザー数</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    {PLANS[plan].users}
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                <TableCell className="font-medium">月間帳票数</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    {PLANS[plan].documents}
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                <TableCell className="font-medium">顧客数</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    {PLANS[plan].customers}
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                <TableCell className="font-medium">AI消込</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    <FeatureIcon enabled={PLANS[plan].aiMatching} />
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                <TableCell className="font-medium">自動督促</TableCell>
                {PLAN_ORDER.map((plan) => (
                  <TableCell key={plan} className="text-center">
                    <FeatureIcon enabled={PLANS[plan].autoDunning} />
                  </TableCell>
                ))}
              </TableRow>
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="font-medium">プランのアップグレード</p>
              <p className="text-sm text-muted-foreground">
                より多くの機能をご利用いただけます
              </p>
            </div>
            <Button
              size="sm"
              className="self-start sm:self-auto"
              onClick={() =>
                toast.info("プランの変更については、お問い合わせください。")
              }
            >
              アップグレードのお問い合わせ
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

/**
 * 機能の有効/無効を示すアイコン
 * @param enabled - 有効かどうか
 * @returns アイコン要素
 */
function FeatureIcon({ enabled }: { enabled: boolean }) {
  return enabled ? (
    <Check className="size-4 text-green-600 mx-auto" />
  ) : (
    <X className="size-4 text-muted-foreground mx-auto" />
  );
}
