"use client";

import { useEffect, useState, useCallback } from "react";
import {
  Loader2,
  Plus,
  MoreHorizontal,
  Shield,
  Mail,
  Trash2,
  UserPlus,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import { api, ApiClientError } from "@/lib/api-client";
import { SettingsNav } from "@/components/settings/settings-nav";
import type { User, UserRole } from "@/types";

/** ロールの日本語ラベル */
const ROLE_LABELS: Record<UserRole, string> = {
  owner: "オーナー",
  admin: "管理者",
  accountant: "経理",
  sales: "営業",
  member: "メンバー",
};

/** ロールのバッジカラー */
const ROLE_VARIANTS: Record<UserRole, "default" | "secondary" | "outline"> = {
  owner: "default",
  admin: "default",
  accountant: "secondary",
  sales: "secondary",
  member: "outline",
};

/** ユーザー一覧レスポンス */
interface UsersResponse {
  users: User[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/**
 * ユーザー管理ページ
 * テナント内のユーザー一覧表示、招待、ロール変更、削除を提供する
 * @returns ユーザー管理ページ要素
 */
export default function UsersSettingsPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [inviteName, setInviteName] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState<UserRole>("member");
  const [inviting, setInviting] = useState(false);
  const [roleEditUser, setRoleEditUser] = useState<User | null>(null);
  const [newRole, setNewRole] = useState<UserRole>("member");
  const [deleteUser, setDeleteUser] = useState<User | null>(null);

  const fetchUsers = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get<UsersResponse>("/api/v1/users", { per_page: 100 });
      setUsers(res.users);
    } catch {
      toast.error("ユーザー一覧の取得に失敗しました");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchUsers();
  }, [fetchUsers]);

  /**
   * ユーザーを招待する
   */
  const handleInvite = async () => {
    if (!inviteEmail.trim()) return;
    setInviting(true);
    try {
      await api.post("/api/v1/users/invite", {
        user: { name: inviteName.trim(), email: inviteEmail.trim(), role: inviteRole },
      });
      toast.success("招待メールを送信しました");
      setInviteOpen(false);
      setInviteName("");
      setInviteEmail("");
      setInviteRole("member");
      void fetchUsers();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "招待に失敗しました");
      }
    } finally {
      setInviting(false);
    }
  };

  /**
   * ユーザーのロールを更新する
   */
  const handleRoleUpdate = async () => {
    if (roleEditUser == null) return;
    try {
      await api.patch(`/api/v1/users/${roleEditUser.id}`, { user: { role: newRole } });
      toast.success("ロールを更新しました");
      setRoleEditUser(null);
      void fetchUsers();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "ロール更新に失敗しました");
      }
    }
  };

  /**
   * ユーザーを削除する
   */
  const handleDelete = async () => {
    if (deleteUser == null) return;
    try {
      await api.delete(`/api/v1/users/${deleteUser.id}`);
      toast.success("ユーザーを削除しました");
      setDeleteUser(null);
      void fetchUsers();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "削除に失敗しました");
      }
    }
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      <SettingsNav />
      <div className="space-y-4 sm:space-y-6">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight">ユーザー管理</h1>
            <p className="text-sm text-muted-foreground">チームメンバーの管理と招待</p>
          </div>
          <Button size="sm" className="self-start sm:self-auto" onClick={() => setInviteOpen(true)}>
            <Plus className="size-4" />
            ユーザーを招待
          </Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>メンバー一覧</CardTitle>
            <CardDescription>{users.length}人のメンバー</CardDescription>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="size-6 animate-spin text-muted-foreground" />
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>名前</TableHead>
                    <TableHead>メールアドレス</TableHead>
                    <TableHead>ロール</TableHead>
                    <TableHead>最終ログイン</TableHead>
                    <TableHead className="w-12" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {users.map((user) => (
                    <TableRow key={user.id}>
                      <TableCell className="font-medium">{user.name}</TableCell>
                      <TableCell className="text-muted-foreground">{user.email}</TableCell>
                      <TableCell>
                        <Badge variant={ROLE_VARIANTS[user.role]}>
                          {ROLE_LABELS[user.role]}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {user.last_sign_in_at
                          ? new Date(user.last_sign_in_at).toLocaleDateString("ja-JP")
                          : "未ログイン"}
                      </TableCell>
                      <TableCell>
                        {user.role !== "owner" && (
                          <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                              <Button variant="ghost" size="icon" className="size-8">
                                <MoreHorizontal className="size-4" />
                              </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem
                                onClick={() => {
                                  setRoleEditUser(user);
                                  setNewRole(user.role);
                                }}
                              >
                                <Shield className="size-4" />
                                ロール変更
                              </DropdownMenuItem>
                              <DropdownMenuSeparator />
                              <DropdownMenuItem
                                variant="destructive"
                                onClick={() => setDeleteUser(user)}
                              >
                                <Trash2 className="size-4" />
                                削除
                              </DropdownMenuItem>
                            </DropdownMenuContent>
                          </DropdownMenu>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>

      {/* 招待ダイアログ */}
      <Dialog open={inviteOpen} onOpenChange={setInviteOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <UserPlus className="size-5" />
              ユーザーを招待
            </DialogTitle>
            <DialogDescription>
              メールアドレスを入力して招待メールを送信します
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div>
              <Label htmlFor="invite-name">氏名</Label>
              <Input
                id="invite-name"
                type="text"
                placeholder="山田 太郎"
                value={inviteName}
                onChange={(e) => setInviteName(e.target.value)}
                className="mt-1.5"
              />
            </div>
            <div>
              <Label htmlFor="invite-email">メールアドレス</Label>
              <Input
                id="invite-email"
                type="email"
                placeholder="user@example.com"
                value={inviteEmail}
                onChange={(e) => setInviteEmail(e.target.value)}
                className="mt-1.5"
              />
            </div>
            <div>
              <Label htmlFor="invite-role">ロール</Label>
              <Select value={inviteRole} onValueChange={(v) => setInviteRole(v as UserRole)}>
                <SelectTrigger className="mt-1.5">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="admin">管理者</SelectItem>
                  <SelectItem value="accountant">経理</SelectItem>
                  <SelectItem value="sales">営業</SelectItem>
                  <SelectItem value="member">メンバー</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setInviteOpen(false)}>
              キャンセル
            </Button>
            <Button onClick={handleInvite} disabled={inviting || !inviteName.trim() || !inviteEmail.trim()}>
              {inviting && <Loader2 className="size-4 animate-spin" />}
              <Mail className="size-4" />
              招待を送信
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ロール変更ダイアログ */}
      <Dialog open={roleEditUser != null} onOpenChange={() => setRoleEditUser(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ロールを変更</DialogTitle>
            <DialogDescription>
              {roleEditUser?.name} のロールを変更します
            </DialogDescription>
          </DialogHeader>
          <div className="py-2">
            <Label>新しいロール</Label>
            <Select value={newRole} onValueChange={(v) => setNewRole(v as UserRole)}>
              <SelectTrigger className="mt-1.5">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="admin">管理者</SelectItem>
                <SelectItem value="accountant">経理</SelectItem>
                <SelectItem value="sales">営業</SelectItem>
                <SelectItem value="member">メンバー</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRoleEditUser(null)}>
              キャンセル
            </Button>
            <Button onClick={handleRoleUpdate}>変更を保存</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 削除確認ダイアログ */}
      <Dialog open={deleteUser != null} onOpenChange={() => setDeleteUser(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ユーザーを削除</DialogTitle>
            <DialogDescription>
              {deleteUser?.name}（{deleteUser?.email}）を削除してもよろしいですか？この操作は取り消せません。
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteUser(null)}>
              キャンセル
            </Button>
            <Button variant="destructive" onClick={handleDelete}>
              削除する
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
