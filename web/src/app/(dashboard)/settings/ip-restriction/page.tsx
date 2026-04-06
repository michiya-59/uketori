"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Shield, Plus, Trash2, AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
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
import type { Tenant } from "@/types/tenant";

/** IPv4/IPv6アドレスまたはCIDR表記の簡易バリデーション */
const IP_PATTERN = /^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$|^([0-9a-fA-F:]+)(\/\d{1,3})?$/;

/**
 * IP制限設定ページ
 * テナントのIPホワイトリストを管理する
 * @returns IP制限設定ページ要素
 */
export default function IpRestrictionPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [enabled, setEnabled] = useState(false);
  const [ipList, setIpList] = useState<string[]>([]);
  const [newIp, setNewIp] = useState("");
  const [currentIp, setCurrentIp] = useState<string | null>(null);
  const [confirmDisableOpen, setConfirmDisableOpen] = useState(false);
  const [confirmEnableOpen, setConfirmEnableOpen] = useState(false);

  /** テナント情報を取得する */
  const loadTenant = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<{ tenant: Tenant; meta?: { your_ip?: string } }>("/api/v1/tenant");
      setEnabled(res.tenant.ip_restriction_enabled);
      setIpList(res.tenant.allowed_ip_addresses);
      if (res.meta?.your_ip) {
        setCurrentIp(res.meta.your_ip);
      }
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("設定の取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTenant();
  }, [loadTenant]);

  /**
   * IP制限設定を保存する
   * @param newEnabled - IP制限の有効/無効
   * @param newIpList - 許可IPアドレスリスト
   */
  const saveSetting = async (newEnabled: boolean, newIpList: string[]) => {
    setSaving(true);
    try {
      await api.patch("/api/v1/tenant", {
        tenant: {
          ip_restriction_enabled: newEnabled,
          allowed_ip_addresses: newIpList,
        },
      });
      setEnabled(newEnabled);
      setIpList(newIpList);
      toast.success("IP制限設定を保存しました");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "保存に失敗しました");
      }
    } finally {
      setSaving(false);
    }
  };

  /** IP制限の有効/無効を切り替える */
  const handleToggle = (checked: boolean) => {
    if (checked) {
      if (ipList.length === 0) {
        toast.error("IPアドレスを1つ以上追加してから有効化してください");
        return;
      }
      setConfirmEnableOpen(true);
    } else {
      setConfirmDisableOpen(true);
    }
  };

  /** 有効化を確定する */
  const confirmEnable = () => {
    setConfirmEnableOpen(false);
    saveSetting(true, ipList);
  };

  /** 無効化を確定する */
  const confirmDisable = () => {
    setConfirmDisableOpen(false);
    saveSetting(false, ipList);
  };

  /** IPアドレスを追加する */
  const handleAddIp = () => {
    const trimmed = newIp.trim();
    if (!trimmed) return;

    if (!IP_PATTERN.test(trimmed)) {
      toast.error("有効なIPアドレスまたはCIDR表記を入力してください（例: 203.0.113.1, 192.168.1.0/24）");
      return;
    }

    if (ipList.includes(trimmed)) {
      toast.error("このIPアドレスは既に追加されています");
      return;
    }

    const updated = [...ipList, trimmed];
    setIpList(updated);
    setNewIp("");

    if (enabled) {
      saveSetting(true, updated);
    }
  };

  /** IPアドレスを削除する */
  const handleRemoveIp = (ip: string) => {
    const updated = ipList.filter((item) => item !== ip);

    if (enabled && updated.length === 0) {
      toast.error("IP制限が有効な間は、すべてのIPアドレスを削除できません。先にIP制限を無効化してください。");
      return;
    }

    setIpList(updated);

    if (enabled) {
      saveSetting(true, updated);
    }
  };

  /** 未保存のIPリストを保存する（IP制限無効時の一括保存） */
  const handleSaveList = () => {
    saveSetting(enabled, ipList);
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

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="icon" className="mt-1 shrink-0 size-10 sm:size-9" onClick={() => router.back()}>
          <ArrowLeft className="size-5 sm:size-4" />
        </Button>
        <div>
          <h1 className="text-xl sm:text-2xl font-bold tracking-tight">IP制限設定</h1>
          <p className="text-sm text-muted-foreground">
            許可するIPアドレスを設定し、不正なアクセスを防止します
          </p>
        </div>
      </div>

      {/* 有効/無効切り替え */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Shield className="size-5" />
            IP制限
          </CardTitle>
          <CardDescription>
            有効にすると、許可リストに含まれるIPアドレスからのみアクセスが可能になります
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">
                {enabled ? "有効" : "無効"}
              </p>
              <p className="text-sm text-muted-foreground">
                {enabled
                  ? "許可リストのIPアドレスからのみアクセス可能です"
                  : "すべてのIPアドレスからアクセス可能です"}
              </p>
            </div>
            <Switch
              checked={enabled}
              onCheckedChange={handleToggle}
              disabled={saving}
            />
          </div>
          {enabled && (
            <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 dark:border-amber-900 dark:bg-amber-950/30">
              <div className="flex gap-2">
                <AlertTriangle className="size-4 mt-0.5 shrink-0 text-amber-600 dark:text-amber-400" />
                <div>
                  <p className="text-sm font-medium text-amber-700 dark:text-amber-400">
                    IP制限が有効です
                  </p>
                  <p className="mt-1 text-xs text-amber-600 dark:text-amber-500">
                    現在のIPアドレスが許可リストに含まれていない場合、設定保存後にアクセスできなくなります。ご注意ください。
                  </p>
                </div>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* 現在のIPアドレス表示 */}
      {currentIp && (
        <Card>
          <CardContent className="pt-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p className="text-sm text-muted-foreground">サーバーが認識しているあなたの現在のIPアドレス</p>
                <code className="text-lg font-mono font-bold">{currentIp}</code>
              </div>
              {!ipList.includes(currentIp) && (
                <Button
                  size="sm"
                  variant="outline"
                  className="self-start sm:self-auto"
                  onClick={() => {
                    const updated = [...ipList, currentIp];
                    setIpList(updated);
                    if (enabled) {
                      saveSetting(true, updated);
                    }
                    toast.success(`${currentIp} を許可リストに追加しました`);
                  }}
                  disabled={saving}
                >
                  <Plus className="mr-1.5 size-3.5" />
                  このIPを許可リストに追加
                </Button>
              )}
              {ipList.includes(currentIp) && (
                <p className="text-sm text-green-600 font-medium">許可リストに含まれています</p>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* IPアドレスリスト */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">許可IPアドレス一覧</CardTitle>
          <CardDescription>
            CIDR表記にも対応しています（例: 192.168.1.0/24）
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* 追加フォーム */}
          <div className="flex gap-2">
            <div className="flex-1">
              <Label className="sr-only">IPアドレス</Label>
              <Input
                value={newIp}
                onChange={(e) => setNewIp(e.target.value)}
                placeholder="例: 203.0.113.1 または 192.168.1.0/24"
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    handleAddIp();
                  }
                }}
              />
            </div>
            <Button onClick={handleAddIp} disabled={saving || !newIp.trim()}>
              <Plus className="mr-1.5 size-3.5" />
              追加
            </Button>
          </div>

          {/* IPリスト */}
          {ipList.length === 0 ? (
            <div className="py-6 text-center text-muted-foreground">
              <Shield className="mx-auto mb-2 size-8 opacity-50" />
              <p>許可IPアドレスが設定されていません</p>
              <p className="text-sm mt-1">上のフォームからIPアドレスを追加してください</p>
            </div>
          ) : (
            <div className="space-y-1.5">
              {ipList.map((ip) => (
                <div
                  key={ip}
                  className="flex items-center justify-between rounded-md border px-3 py-2"
                >
                  <code className="text-sm font-mono">{ip}</code>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-8 text-destructive"
                    onClick={() => handleRemoveIp(ip)}
                    disabled={saving}
                  >
                    <Trash2 className="size-3.5" />
                  </Button>
                </div>
              ))}
            </div>
          )}

          {/* IP制限無効時は一括保存ボタンを表示 */}
          {!enabled && ipList.length > 0 && (
            <Button onClick={handleSaveList} disabled={saving} className="w-full sm:w-auto">
              {saving ? "保存中..." : "リストを保存"}
            </Button>
          )}
        </CardContent>
      </Card>

      {/* 有効化確認ダイアログ */}
      <AlertDialog open={confirmEnableOpen} onOpenChange={setConfirmEnableOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>IP制限を有効にしますか？</AlertDialogTitle>
            <AlertDialogDescription>
              有効にすると、許可リストに含まれるIPアドレスからのみアクセスが可能になります。
              現在のIPアドレスが許可リストに含まれていることを確認してください。
              {ipList.length > 0 && (
                <>
                  <br /><br />
                  許可済みIP: {ipList.join(", ")}
                </>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction onClick={confirmEnable}>
              有効にする
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* 無効化確認ダイアログ */}
      <AlertDialog open={confirmDisableOpen} onOpenChange={setConfirmDisableOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>IP制限を無効にしますか？</AlertDialogTitle>
            <AlertDialogDescription>
              無効にすると、すべてのIPアドレスからアクセスが可能になります。
              許可IPアドレスの設定は保持されます。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>キャンセル</AlertDialogCancel>
            <AlertDialogAction onClick={confirmDisable}>
              無効にする
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
