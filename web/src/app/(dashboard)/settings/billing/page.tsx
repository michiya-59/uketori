"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, CreditCard, Check, X, Send } from "lucide-react";
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
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
/** 現在の使用数 */
interface UsageCounts {
  users: number;
  documentsMonthly: number;
  customers: number;
}

export default function BillingPage() {
  const [tenant, setTenant] = useState<Tenant | null>(null);
  const [loading, setLoading] = useState(true);
  const [usage, setUsage] = useState<UsageCounts>({ users: 0, documentsMonthly: 0, customers: 0 });

  // お問い合わせダイアログ
  const [inquiryOpen, setInquiryOpen] = useState(false);
  const [desiredPlan, setDesiredPlan] = useState<string>("");
  const [inquiryMessage, setInquiryMessage] = useState("");
  const [sending, setSending] = useState(false);

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

  /** 現在の使用数を取得する */
  useEffect(() => {
    const loadUsage = async () => {
      try {
        const [usersRes, docsRes, customersRes] = await Promise.all([
          api.get<{ users: unknown[]; meta: { total_count: number } }>("/api/v1/users", { per_page: 1 }),
          (() => {
            const now = new Date();
            const from = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
            const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
            const to = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
            return api.get<{ meta: { total_count: number } }>("/api/v1/documents", {
              "filter[issue_date_from]": from,
              "filter[issue_date_to]": to,
              per_page: 1,
            });
          })(),
          api.get<{ customers: unknown[]; meta: { total_count: number } }>("/api/v1/customers", { per_page: 1 }),
        ]);
        setUsage({
          users: usersRes.meta.total_count,
          documentsMonthly: docsRes.meta.total_count,
          customers: customersRes.meta.total_count,
        });
      } catch {
        // ignore
      }
    };
    loadUsage();
  }, []);

  /**
   * お問い合わせダイアログを開く
   */
  const openInquiry = () => {
    const currentPlan = tenant?.plan ?? "free";
    const currentIndex = PLAN_ORDER.indexOf(currentPlan);
    const nextPlan = PLAN_ORDER[currentIndex + 1] ?? "professional";
    setDesiredPlan(nextPlan);
    setInquiryMessage("");
    setInquiryOpen(true);
  };

  /**
   * お問い合わせを送信する
   */
  const handleSendInquiry = async () => {
    if (!desiredPlan || !inquiryMessage.trim()) {
      toast.error("希望プランとお問い合わせ内容を入力してください");
      return;
    }

    setSending(true);
    try {
      await api.post("/api/v1/contact/plan_inquiry", {
        desired_plan: PLANS[desiredPlan as TenantPlan]?.name ?? desiredPlan,
        message: inquiryMessage,
      });
      toast.success("お問い合わせを送信しました。担当者より折り返しご連絡いたします。");
      setInquiryOpen(false);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "送信に失敗しました");
      }
    } finally {
      setSending(false);
    }
  };

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
  const upgradePlans = PLAN_ORDER.filter((p) => PLAN_ORDER.indexOf(p) > PLAN_ORDER.indexOf(currentPlan));

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" asChild className="mt-1 shrink-0 size-10 sm:size-9">
          <Link href="/settings/company">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight">プラン設定</h1>
          <p className="text-sm text-muted-foreground">
            ご利用プランの確認と変更を行います
          </p>
        </div>
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
            <UsageItem
              label="ユーザー数"
              current={usage.users}
              limit={planInfo.users}
            />
            <UsageItem
              label="今月の帳票数"
              current={usage.documentsMonthly}
              limit={planInfo.documents}
            />
            <UsageItem
              label="顧客数"
              current={usage.customers}
              limit={planInfo.customers}
            />
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

      {upgradePlans.length > 0 && (
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
                onClick={openInquiry}
              >
                <Send className="mr-1.5 size-3.5" />
                アップグレードのお問い合わせ
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* お問い合わせダイアログ */}
      <Dialog open={inquiryOpen} onOpenChange={setInquiryOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>プランアップグレードのお問い合わせ</DialogTitle>
            <DialogDescription>
              ご希望のプランとお問い合わせ内容をご記入ください。担当者より折り返しご連絡いたします。
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>希望プラン</Label>
              <Select value={desiredPlan} onValueChange={setDesiredPlan}>
                <SelectTrigger>
                  <SelectValue placeholder="プランを選択" />
                </SelectTrigger>
                <SelectContent>
                  {upgradePlans.map((plan) => (
                    <SelectItem key={plan} value={plan}>
                      {PLANS[plan].name}（{PLANS[plan].price}）
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>お問い合わせ内容</Label>
              <Textarea
                value={inquiryMessage}
                onChange={(e) => setInquiryMessage(e.target.value)}
                placeholder="ご利用予定の人数やご質問など、ご自由にご記入ください"
                rows={4}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setInquiryOpen(false)}>
              キャンセル
            </Button>
            <Button onClick={handleSendInquiry} disabled={sending || !inquiryMessage.trim()}>
              {sending ? "送信中..." : "送信する"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
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

/**
 * 使用量表示コンポーネント
 * @param label - ラベル
 * @param current - 現在の使用数
 * @param limit - 上限表示文字列
 * @returns 使用量要素
 */
function UsageItem({ label, current, limit }: { label: string; current: number; limit: string }) {
  const isUnlimited = limit === "無制限";
  const limitNum = isUnlimited ? Infinity : parseInt(limit.replace(/[^0-9]/g, ""), 10);
  const isNearLimit = !isUnlimited && !isNaN(limitNum) && current >= limitNum;
  const isWarning = !isUnlimited && !isNaN(limitNum) && current >= limitNum * 0.8 && !isNearLimit;

  return (
    <div>
      <span className="text-muted-foreground">{label}:</span>{" "}
      <span className={`font-medium ${isNearLimit ? "text-red-600" : isWarning ? "text-amber-600" : ""}`}>
        {current}
      </span>
      <span className="text-muted-foreground"> / {limit}</span>
    </div>
  );
}
