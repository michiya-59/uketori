"use client";

import { useState } from "react";
import { Bell, Mail, MessageSquare } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { SettingsNav } from "@/components/settings/settings-nav";

/** 通知設定項目 */
interface NotificationSetting {
  key: string;
  label: string;
  description: string;
  enabled: boolean;
}

/** 通知カテゴリ */
interface NotificationCategory {
  title: string;
  description: string;
  icon: React.ElementType;
  settings: NotificationSetting[];
}

/**
 * 通知設定ページ
 * 通知チャネルごとのオン/オフ設定を提供する
 * @returns 通知設定ページ要素
 */
export default function NotificationSettingsPage() {
  const [categories, setCategories] = useState<NotificationCategory[]>([
    {
      title: "支払い・入金",
      description: "請求書の支払いに関する通知",
      icon: Bell,
      settings: [
        { key: "payment_received", label: "入金通知", description: "入金が確認された時に通知", enabled: true },
        { key: "payment_overdue", label: "支払い遅延", description: "支払い期限を超過した時に通知", enabled: true },
        { key: "payment_reminder", label: "入金予定リマインダー", description: "入金予定日の前日に通知", enabled: true },
      ],
    },
    {
      title: "帳票",
      description: "見積書・請求書の操作に関する通知",
      icon: Mail,
      settings: [
        { key: "document_approved", label: "承認通知", description: "帳票が承認された時に通知", enabled: true },
        { key: "document_rejected", label: "却下通知", description: "帳票が却下された時に通知", enabled: true },
        { key: "document_sent", label: "送信完了", description: "帳票がメール送信された時に通知", enabled: false },
      ],
    },
    {
      title: "システム",
      description: "インポートやシステム関連の通知",
      icon: MessageSquare,
      settings: [
        { key: "import_completed", label: "インポート完了", description: "データ移行が完了した時に通知", enabled: true },
        { key: "dunning_sent", label: "督促送信", description: "督促メールが送信された時に通知", enabled: true },
        { key: "credit_alert", label: "与信アラート", description: "与信スコアが低下した時に通知", enabled: false },
      ],
    },
  ]);

  /**
   * 通知設定を切り替える
   * @param categoryIndex - カテゴリインデックス
   * @param settingIndex - 設定項目インデックス
   */
  const toggleSetting = (categoryIndex: number, settingIndex: number) => {
    setCategories((prev) =>
      prev.map((cat, ci) =>
        ci === categoryIndex
          ? {
              ...cat,
              settings: cat.settings.map((s, si) =>
                si === settingIndex ? { ...s, enabled: !s.enabled } : s
              ),
            }
          : cat
      )
    );
  };

  /**
   * 設定を保存する
   */
  const handleSave = () => {
    toast.success("通知設定を保存しました");
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      <SettingsNav />
      <div className="space-y-4 sm:space-y-6">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight">通知設定</h1>
            <p className="text-sm text-muted-foreground">受け取る通知の種類を管理します</p>
          </div>
          <Button size="sm" className="self-start sm:self-auto" onClick={handleSave}>設定を保存</Button>
        </div>

        {categories.map((category, ci) => (
          <Card key={category.title}>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <category.icon className="size-5 text-primary" />
                {category.title}
              </CardTitle>
              <CardDescription>{category.description}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-1">
              {category.settings.map((setting, si) => (
                <div key={setting.key}>
                  {si > 0 && <Separator className="my-3" />}
                  <div className="flex items-center justify-between py-1">
                    <div>
                      <Label className="text-[15px] font-medium">{setting.label}</Label>
                      <p className="text-sm text-muted-foreground">{setting.description}</p>
                    </div>
                    <Switch
                      checked={setting.enabled}
                      onCheckedChange={() => toggleSetting(ci, si)}
                    />
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
