"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, Loader2, RotateCcw, Save } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
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
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { SettingsNav } from "@/components/settings/settings-nav";
import { api, ApiClientError } from "@/lib/api-client";

/** 権限の状態 */
interface PermissionState {
  allowed: boolean;
  default: boolean;
  customized: boolean;
}

/** ロールの権限データ */
interface RoleData {
  role: string;
  role_label: string;
  permissions: Record<string, PermissionState>;
}

/** アクションのメタデータ */
interface ActionMeta {
  action: string;
  action_label: string;
  key: string;
  default_min_role: string;
  default_min_role_label: string;
}

/** リソースのメタデータ */
interface ResourceMeta {
  resource: string;
  resource_label: string;
  actions: ActionMeta[];
}

/** APIレスポンス */
interface RolePermissionsResponse {
  roles: RoleData[];
  resources: ResourceMeta[];
}

/** ロールの表示色 */
const ROLE_COLORS: Record<string, string> = {
  admin: "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200",
  accountant: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200",
  sales: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200",
  member: "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200",
};

/**
 * ロール権限設定ページ
 * テナント内のロールごとにカスタム権限を設定する
 * @returns ロール権限設定ページ要素
 */
export default function RolePermissionsPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [roles, setRoles] = useState<RoleData[]>([]);
  const [resources, setResources] = useState<ResourceMeta[]>([]);
  const [selectedRole, setSelectedRole] = useState<string>("admin");
  const [editedPermissions, setEditedPermissions] = useState<Record<string, boolean>>({});
  const [hasChanges, setHasChanges] = useState(false);

  /**
   * 権限データを取得する
   */
  const loadPermissions = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<RolePermissionsResponse>("/api/v1/role_permissions");
      setRoles(res.roles);
      setResources(res.resources);
      initEditState(res.roles, selectedRole);
    } catch (e) {
      if (e instanceof ApiClientError) {
        if (e.status === 403) {
          toast.error("管理者権限が必要です");
          router.push("/settings/company");
          return;
        }
        toast.error(e.body?.error?.message ?? "権限設定の取得に失敗しました");
      }
    } finally {
      setLoading(false);
    }
  }, [router, selectedRole]);

  useEffect(() => {
    loadPermissions();
  }, [loadPermissions]);

  /**
   * 編集状態を初期化する
   * @param rolesData - ロールデータ配列
   * @param role - 選択中のロール
   */
  const initEditState = (rolesData: RoleData[], role: string) => {
    const roleData = rolesData.find((r) => r.role === role);
    if (!roleData) return;

    const perms: Record<string, boolean> = {};
    Object.entries(roleData.permissions).forEach(([key, state]) => {
      perms[key] = state.allowed;
    });
    setEditedPermissions(perms);
    setHasChanges(false);
  };

  /**
   * ロール切替時のハンドラ
   * @param role - 選択されたロール
   */
  const handleRoleChange = (role: string) => {
    if (hasChanges) {
      if (!window.confirm("未保存の変更があります。破棄しますか？")) return;
    }
    setSelectedRole(role);
    initEditState(roles, role);
  };

  /**
   * 権限トグルのハンドラ
   * @param key - 権限キー
   * @param value - 新しい値
   */
  const handleToggle = (key: string, value: boolean) => {
    setEditedPermissions((prev) => ({ ...prev, [key]: value }));
    setHasChanges(true);
  };

  /**
   * 権限を保存する
   */
  const handleSave = async () => {
    try {
      setSaving(true);
      const roleData = roles.find((r) => r.role === selectedRole);
      if (!roleData) return;

      const customized: Record<string, boolean> = {};
      Object.entries(editedPermissions).forEach(([key, value]) => {
        const defaultValue = roleData.permissions[key]?.default;
        if (value !== defaultValue) {
          customized[key] = value;
        }
      });

      await api.put(`/api/v1/role_permissions/${selectedRole}`, {
        permissions: customized,
      });
      toast.success("権限を保存しました");
      await loadPermissions();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "権限の保存に失敗しました");
      }
    } finally {
      setSaving(false);
    }
  };

  /**
   * 権限をデフォルトにリセットする
   */
  const handleReset = async () => {
    try {
      setResetting(true);
      await api.post(`/api/v1/role_permissions/${selectedRole}/reset`, {});
      toast.success("権限をデフォルトにリセットしました");
      await loadPermissions();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "リセットに失敗しました");
      }
    } finally {
      setResetting(false);
    }
  };

  const currentRole = roles.find((r) => r.role === selectedRole);
  const hasCustomizations = currentRole
    ? Object.values(currentRole.permissions).some((p) => p.customized)
    : false;

  return (
    <div className="space-y-6">
      <SettingsNav />

      {/* ヘッダー */}
      <div>
        <div className="flex items-center gap-2">
          <KeyRound className="size-6 text-primary" />
          <h1 className="text-2xl font-bold tracking-tight">ロール権限設定</h1>
        </div>
        <p className="mt-1 text-muted-foreground">
          各ロールの操作権限をカスタマイズできます。オーナーは常にすべての権限を持ちます。
        </p>
      </div>

      {loading ? (
        <div className="space-y-4">
          <Skeleton className="h-10 w-48" />
          <Skeleton className="h-96 w-full" />
        </div>
      ) : (
        <>
          {/* ロール選択 + アクション */}
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3">
            <Select value={selectedRole} onValueChange={handleRoleChange}>
              <SelectTrigger className="w-48 h-10">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {roles.map((r) => (
                  <SelectItem key={r.role} value={r.role}>
                    {r.role_label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Badge variant="outline" className={ROLE_COLORS[selectedRole]}>
              {currentRole?.role_label}
            </Badge>

            <div className="flex gap-2 sm:ml-auto">
              {hasCustomizations && (
                <AlertDialog>
                  <AlertDialogTrigger asChild>
                    <Button variant="outline" size="sm" disabled={resetting}>
                      {resetting ? (
                        <Loader2 className="mr-1.5 size-3.5 animate-spin" />
                      ) : (
                        <RotateCcw className="mr-1.5 size-3.5" />
                      )}
                      デフォルトに戻す
                    </Button>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>権限をリセットしますか？</AlertDialogTitle>
                      <AlertDialogDescription>
                        {currentRole?.role_label}ロールのカスタム設定をすべて削除し、デフォルトの権限に戻します。
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel>キャンセル</AlertDialogCancel>
                      <AlertDialogAction onClick={handleReset}>
                        リセットする
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              )}

              <Button size="sm" disabled={!hasChanges || saving} onClick={handleSave}>
                {saving ? (
                  <Loader2 className="mr-1.5 size-3.5 animate-spin" />
                ) : (
                  <Save className="mr-1.5 size-3.5" />
                )}
                保存
              </Button>
            </div>
          </div>

          {/* 権限テーブル */}
          {resources.map((resource) => (
            <Card key={resource.resource}>
              <CardHeader className="py-4">
                <CardTitle className="text-base">{resource.resource_label}</CardTitle>
                <CardDescription className="text-xs">
                  この機能に関する操作権限
                </CardDescription>
              </CardHeader>
              <CardContent className="p-0">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-1/3">操作</TableHead>
                      <TableHead className="w-1/4">デフォルト最低ロール</TableHead>
                      <TableHead className="w-1/6 text-center">デフォルト</TableHead>
                      <TableHead className="w-1/6 text-center">許可</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {resource.actions.map((action) => {
                      const permState = currentRole?.permissions[action.key];
                      const isAllowed = editedPermissions[action.key] ?? false;
                      const isDefault = permState?.default ?? false;
                      const isCustomized = isAllowed !== isDefault;

                      return (
                        <TableRow key={action.key}>
                          <TableCell className="font-medium">
                            {action.action_label}
                            {isCustomized && (
                              <Badge variant="secondary" className="ml-2 text-[10px] px-1.5 py-0">
                                変更あり
                              </Badge>
                            )}
                          </TableCell>
                          <TableCell>
                            <Badge variant="outline" className="text-xs">
                              {action.default_min_role_label}以上
                            </Badge>
                          </TableCell>
                          <TableCell className="text-center">
                            <span className={isDefault ? "text-green-600" : "text-muted-foreground"}>
                              {isDefault ? "許可" : "拒否"}
                            </span>
                          </TableCell>
                          <TableCell className="text-center">
                            <Switch
                              checked={isAllowed}
                              onCheckedChange={(v) => handleToggle(action.key, v)}
                            />
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          ))}
        </>
      )}
    </div>
  );
}
