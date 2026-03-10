"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Plus,
  Pencil,
  Trash2,
  ArrowLeft,
  Bell,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
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
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
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
import { api, ApiClientError } from "@/lib/api-client";
import { Tenant } from "@/types/tenant";
import type { DunningRule } from "@/types/dunning";

/** ルール一覧レスポンス */
interface RulesResponse {
  rules: DunningRule[];
}

/** テンプレート変数一覧 */
const TEMPLATE_VARS = [
  { key: "{{customer_name}}", label: "取引先名" },
  { key: "{{document_number}}", label: "帳票番号" },
  { key: "{{total_amount}}", label: "請求金額" },
  { key: "{{remaining_amount}}", label: "未回収金額" },
  { key: "{{due_date}}", label: "支払期限" },
  { key: "{{overdue_days}}", label: "遅延日数" },
  { key: "{{company_name}}", label: "自社名" },
  { key: "{{bank_info}}", label: "振込先情報" },
];

/** デフォルトのメール件名テンプレート */
const DEFAULT_SUBJECT = "【お支払いのお願い】{{document_number}} ({{overdue_days}}日超過)";

/** デフォルトのメール本文テンプレート */
const DEFAULT_BODY = `{{customer_name}} 御中

いつもお世話になっております。{{company_name}}です。

下記請求書のお支払期限が{{overdue_days}}日超過しております。
お忙しいところ恐れ入りますが、ご確認の上、お早めにお支払いいただけますようお願い申し上げます。

■ 請求書番号: {{document_number}}
■ 請求金額: {{total_amount}}円
■ 未回収金額: {{remaining_amount}}円
■ お支払期限: {{due_date}}

■ お振込先:
{{bank_info}}

何かご不明な点がございましたら、お気軽にお問い合わせください。

{{company_name}}`;

/**
 * 督促ルール設定ページ
 * 督促ルールの作成・編集・削除を行う
 */
export default function DunningSettingsPage() {
  const router = useRouter();
  const [rules, setRules] = useState<DunningRule[]>([]);
  const [loading, setLoading] = useState(true);

  // プラン制限
  const [tenantPlan, setTenantPlan] = useState<string | null>(null);
  const isFreePlan = tenantPlan === "free";

  useEffect(() => {
    api.get<{ tenant: Tenant }>("/api/v1/tenant")
      .then((data) => setTenantPlan(data.tenant.plan))
      .catch(() => {});
  }, []);

  // フォームダイアログ
  const [formOpen, setFormOpen] = useState(false);
  const [editingRule, setEditingRule] = useState<DunningRule | null>(null);
  const [saving, setSaving] = useState(false);

  // フォームフィールド
  const [name, setName] = useState("");
  const [triggerDays, setTriggerDays] = useState("7");
  const [actionType, setActionType] = useState("email");
  const [sendTo, setSendTo] = useState("billing_contact");
  const [customEmail, setCustomEmail] = useState("");
  const [maxCount, setMaxCount] = useState("3");
  const [intervalDays, setIntervalDays] = useState("7");
  const [emailSubject, setEmailSubject] = useState(DEFAULT_SUBJECT);
  const [emailBody, setEmailBody] = useState(DEFAULT_BODY);

  // 削除ダイアログ
  const [deleteTarget, setDeleteTarget] = useState<DunningRule | null>(null);
  const [deleting, setDeleting] = useState(false);

  /**
   * 督促ルール一覧を取得する
   */
  const fetchRules = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get<RulesResponse>("/api/v1/dunning/rules");
      setRules(data.rules);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("督促ルールの取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRules();
  }, [fetchRules]);

  /**
   * フォームをリセットする
   */
  const resetForm = () => {
    setName("");
    setTriggerDays("7");
    setActionType("email");
    setSendTo("billing_contact");
    setCustomEmail("");
    setMaxCount("3");
    setIntervalDays("7");
    setEmailSubject(DEFAULT_SUBJECT);
    setEmailBody(DEFAULT_BODY);
    setEditingRule(null);
  };

  /**
   * 編集モードでフォームを開く
   * @param rule - 編集対象のルール
   */
  const openEdit = (rule: DunningRule) => {
    setEditingRule(rule);
    setName(rule.name);
    setTriggerDays(String(rule.trigger_days_after_due));
    setActionType(rule.action_type);
    setSendTo(rule.send_to);
    setCustomEmail(rule.custom_email || "");
    setMaxCount(String(rule.max_dunning_count));
    setIntervalDays(String(rule.interval_days));
    setEmailSubject(rule.email_template_subject || DEFAULT_SUBJECT);
    setEmailBody(rule.email_template_body || DEFAULT_BODY);
    setFormOpen(true);
  };

  /**
   * 新規作成モードでフォームを開く
   */
  const openCreate = () => {
    resetForm();
    setFormOpen(true);
  };

  /**
   * ルールを保存する（作成または更新）
   */
  const handleSave = async () => {
    if (!name.trim()) {
      toast.error("ルール名を入力してください");
      return;
    }
    setSaving(true);
    const payload = {
      rule: {
        name: name.trim(),
        trigger_days_after_due: Number(triggerDays),
        action_type: actionType,
        send_to: sendTo,
        custom_email: sendTo === "custom_email" ? customEmail : null,
        max_dunning_count: Number(maxCount),
        interval_days: Number(intervalDays),
        email_template_subject: emailSubject,
        email_template_body: emailBody,
      },
    };

    try {
      if (editingRule) {
        await api.patch(`/api/v1/dunning/rules/${editingRule.id}`, payload);
        toast.success("ルールを更新しました");
      } else {
        await api.post("/api/v1/dunning/rules", payload);
        toast.success("ルールを作成しました");
      }
      setFormOpen(false);
      resetForm();
      fetchRules();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "保存に失敗しました");
      }
    } finally {
      setSaving(false);
    }
  };

  /**
   * ルールを削除する
   */
  const handleDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await api.delete(`/api/v1/dunning/rules/${deleteTarget.id}`);
      toast.success("ルールを削除しました");
      setDeleteTarget(null);
      fetchRules();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "削除に失敗しました");
      }
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      {/* ヘッダー */}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" className="mt-1 shrink-0 size-10 sm:size-9" onClick={() => router.back()}>
          <ArrowLeft className="size-5 sm:size-4" />
        </Button>
        <div className="min-w-0 flex-1">
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight">督促ルール設定</h1>
          <p className="text-sm text-muted-foreground">
            督促の条件、テンプレート、送信先を設定します
          </p>
          {isFreePlan ? (
            <div className="mt-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 dark:border-red-900 dark:bg-red-950/30">
              <p className="text-sm font-medium text-red-700 dark:text-red-400">
                Freeプランでは自動督促機能をご利用いただけません
              </p>
              <p className="mt-1 text-xs text-red-600 dark:text-red-500">
                Starter プラン以上にアップグレードすると、督促ルールの作成・自動実行が利用できます。
              </p>
              <Button
                variant="outline"
                size="sm"
                className="mt-2 border-red-300 text-red-700 hover:bg-red-100 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
                asChild
              >
                <Link href="/settings/billing">プランを確認する</Link>
              </Button>
            </div>
          ) : (
            <Button size="sm" className="mt-2" onClick={openCreate}>
              <Plus className="mr-1.5 size-3.5" />
              ルール追加
            </Button>
          )}
        </div>
      </div>

      {/* ルール一覧 */}
      {loading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <Card key={i}>
              <CardContent className="pt-6">
                <Skeleton className="h-6 w-48 mb-4" />
                <Skeleton className="h-4 w-full" />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : rules.length === 0 ? (
        <Card>
          <CardContent className="py-8 text-center text-muted-foreground">
            <Bell className="mx-auto mb-2 size-8 opacity-50" />
            <p>督促ルールが設定されていません</p>
            <p className="text-sm mt-1">「ルール追加」ボタンから最初のルールを作成しましょう</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2 sm:space-y-3">
          {rules.map((rule) => (
            <Card key={rule.id} className={`py-0 gap-0 ${!rule.is_active ? "opacity-60" : ""}`}>
              <CardContent className="py-2.5 sm:py-3 px-3 sm:px-4">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-semibold text-sm">{rule.name}</h3>
                      <Badge variant={rule.is_active ? "default" : "secondary"} className="text-xs">
                        {rule.is_active ? "有効" : "無効"}
                      </Badge>
                    </div>
                    <div className="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 text-xs sm:text-sm text-muted-foreground">
                      <span>期限超過 {rule.trigger_days_after_due}日後</span>
                      <span>最大 {rule.max_dunning_count}回</span>
                      <span>{rule.interval_days}日間隔</span>
                      <span>
                        {rule.action_type === "email" ? "メール送信" :
                         rule.action_type === "internal_alert" ? "社内通知" : "メール＋通知"}
                      </span>
                    </div>
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <Button variant="ghost" size="icon" className="size-9 sm:size-8" onClick={() => openEdit(rule)}>
                      <Pencil className="size-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-9 sm:size-8 text-destructive"
                      onClick={() => setDeleteTarget(rule)}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* 作成/編集ダイアログ */}
      <Dialog open={formOpen} onOpenChange={(open) => { setFormOpen(open); if (!open) resetForm(); }}>
        <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto overflow-x-hidden">
          <DialogHeader>
            <DialogTitle>{editingRule ? "ルール編集" : "ルール追加"}</DialogTitle>
            <DialogDescription>
              督促の条件とメールテンプレートを設定します
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 sm:space-y-6 py-2 sm:py-4">
            {/* 基本設定 */}
            <div className="space-y-3 sm:space-y-4">
              <h4 className="text-sm font-semibold">基本設定</h4>
              <div className="space-y-2">
                <Label>ルール名 *</Label>
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="例: 初回督促メール"
                />
              </div>
              <div className="grid grid-cols-3 gap-2 sm:gap-4">
                <div className="space-y-1.5">
                  <Label className="text-xs sm:text-sm">超過日数 *</Label>
                  <Input
                    type="number"
                    value={triggerDays}
                    onChange={(e) => setTriggerDays(e.target.value)}
                    min="1"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-xs sm:text-sm">最大回数 *</Label>
                  <Input
                    type="number"
                    value={maxCount}
                    onChange={(e) => setMaxCount(e.target.value)}
                    min="1"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-xs sm:text-sm">間隔（日） *</Label>
                  <Input
                    type="number"
                    value={intervalDays}
                    onChange={(e) => setIntervalDays(e.target.value)}
                    min="1"
                  />
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label>アクション種別</Label>
                  <Select value={actionType} onValueChange={setActionType}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="email">メール送信</SelectItem>
                      <SelectItem value="internal_alert">社内通知</SelectItem>
                      <SelectItem value="both">メール＋社内通知</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label>送信先</Label>
                  <Select value={sendTo} onValueChange={setSendTo}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="billing_contact">経理担当者</SelectItem>
                      <SelectItem value="primary_contact">主要連絡先</SelectItem>
                      <SelectItem value="custom_email">カスタムメール</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              {sendTo === "custom_email" && (
                <div className="space-y-2">
                  <Label>カスタムメールアドレス</Label>
                  <Input
                    type="email"
                    value={customEmail}
                    onChange={(e) => setCustomEmail(e.target.value)}
                    placeholder="billing@example.com"
                  />
                </div>
              )}
            </div>

            {/* メールテンプレート */}
            {(actionType === "email" || actionType === "both") && (
              <div className="space-y-3 sm:space-y-4">
                <h4 className="text-sm font-semibold">メールテンプレート</h4>
                <div className="rounded-md border p-2 sm:p-3 bg-muted/50">
                  <p className="text-xs font-medium mb-1.5 text-muted-foreground">利用可能な変数:</p>
                  <div className="flex flex-wrap gap-1.5">
                    {TEMPLATE_VARS.map((v) => (
                      <Badge key={v.key} variant="outline" className="text-[10px] sm:text-xs cursor-default">
                        <code>{v.key}</code>
                        <span className="ml-1 text-muted-foreground hidden sm:inline">({v.label})</span>
                      </Badge>
                    ))}
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>件名</Label>
                  <Input
                    value={emailSubject}
                    onChange={(e) => setEmailSubject(e.target.value)}
                  />
                </div>
                <div className="space-y-2">
                  <Label>本文</Label>
                  <Textarea
                    value={emailBody}
                    onChange={(e) => setEmailBody(e.target.value)}
                    rows={14}
                    className="font-mono text-sm"
                  />
                </div>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setFormOpen(false)}>
              キャンセル
            </Button>
            <Button onClick={handleSave} disabled={saving}>
              {saving ? "保存中..." : editingRule ? "更新" : "作成"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 削除確認ダイアログ */}
      <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>ルールを削除</AlertDialogTitle>
            <AlertDialogDescription>
              {deleteTarget && (
                <>
                  督促ルール「{deleteTarget.name}」を削除しますか？
                  この操作は取り消せません。
                </>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {deleting ? "削除中..." : "削除する"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
