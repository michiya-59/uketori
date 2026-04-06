"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useForm, Controller } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  ShieldCheck,
  UserPlus,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Eye,
  EyeOff,
  Copy,
  Check,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
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
import { Separator } from "@/components/ui/separator";
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
import { api, ApiClientError } from "@/lib/api-client";

/** 業種の選択肢一覧 */
const INDUSTRY_TYPES = [
  { value: "it", label: "IT・通信" },
  { value: "consulting", label: "コンサルティング" },
  { value: "advertising", label: "広告・マーケティング" },
  { value: "design", label: "デザイン・クリエイティブ" },
  { value: "construction", label: "建設・不動産" },
  { value: "manufacturing", label: "製造" },
  { value: "retail", label: "小売・卸売" },
  { value: "finance", label: "金融・保険" },
  { value: "medical", label: "医療・福祉" },
  { value: "education", label: "教育" },
  { value: "other", label: "その他" },
] as const;

/** プランの選択肢一覧 */
const PLAN_OPTIONS = [
  { value: "free", label: "Free（3ユーザーまで）" },
  { value: "starter", label: "Starter（5ユーザーまで）" },
  { value: "standard", label: "Standard（10ユーザーまで）" },
  { value: "professional", label: "Professional（無制限）" },
] as const;

/** アカウント発行フォームのバリデーションスキーマ */
const accountSchema = z.object({
  tenantName: z.string().min(1, "会社名を入力してください").max(255),
  industryCode: z.string().min(1, "業種を選択してください"),
  plan: z.string().min(1, "プランを選択してください"),
  name: z.string().min(1, "氏名を入力してください").max(100),
  email: z
    .string()
    .min(1, "メールアドレスを入力してください")
    .email("有効なメールアドレスを入力してください"),
  password: z.string().min(8, "パスワードは8文字以上で入力してください"),
});

type AccountFormData = z.infer<typeof accountSchema>;

/** 発行済みアカウントの型 */
interface AccountSummary {
  id: string;
  tenant_name: string;
  industry_type: string;
  plan: string;
  owner_name: string | null;
  owner_email: string | null;
  users_count: number;
  has_system_admin: boolean;
  created_at: string;
}

/**
 * システム管理者用アカウント発行ページ
 * テナント＋オーナーユーザーの作成フォームと発行済みアカウント一覧を表示する
 * @returns アカウント発行ページ要素
 */
export default function AdminAccountsPage() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<AccountSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [formError, setFormError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [createdAccount, setCreatedAccount] = useState<{
    email: string;
    password: string;
  } | null>(null);
  const [copiedField, setCopiedField] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    control,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<AccountFormData>({
    resolver: zodResolver(accountSchema),
  });

  /**
   * アカウント一覧を取得する
   * @param page - ページ番号
   */
  const loadAccounts = useCallback(
    async (page: number = 1) => {
      try {
        setLoading(true);
        const res = await api.get<{
          accounts: AccountSummary[];
          meta: {
            current_page: number;
            total_pages: number;
            total_count: number;
          };
        }>("/api/v1/admin/accounts", { page });

        setAccounts(res.accounts);
        setCurrentPage(res.meta.current_page);
        setTotalPages(res.meta.total_pages);
        setTotalCount(res.meta.total_count);
      } catch (e) {
        if (e instanceof ApiClientError) {
          if (e.status === 403) {
            toast.error("システム管理者権限が必要です");
            router.push("/dashboard");
            return;
          }
          toast.error(
            e.body?.error?.message ?? "アカウント一覧の取得に失敗しました"
          );
        }
      } finally {
        setLoading(false);
      }
    },
    [router]
  );

  useEffect(() => {
    loadAccounts(1);
  }, [loadAccounts]);

  /**
   * アカウント発行フォームの送信ハンドラ
   * @param data - バリデーション済みフォームデータ
   */
  const onSubmit = async (data: AccountFormData) => {
    setFormError(null);
    setCreatedAccount(null);
    try {
      await api.post("/api/v1/admin/accounts", {
        account: {
          tenant_name: data.tenantName,
          industry_code: data.industryCode,
          plan: data.plan,
          name: data.name,
          email: data.email,
          password: data.password,
          password_confirmation: data.password,
        },
      });
      toast.success("アカウントを発行しました");
      setCreatedAccount({ email: data.email, password: data.password });
      reset();
      loadAccounts(1);
    } catch (e) {
      if (e instanceof ApiClientError) {
        setFormError(e.body?.error?.message ?? "アカウント発行に失敗しました");
      } else {
        setFormError("通信エラーが発生しました");
      }
    }
  };

  /**
   * テキストをクリップボードにコピーする
   * @param text - コピーするテキスト
   * @param field - コピー元フィールド名
   */
  const handleCopy = async (text: string, field: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedField(field);
    setTimeout(() => setCopiedField(null), 2000);
  };

  /**
   * アカウントを削除する
   * @param accountId - テナントUUID
   */
  const handleDelete = async (accountId: string) => {
    try {
      setDeletingId(accountId);
      await api.delete(`/api/v1/admin/accounts/${accountId}`);
      toast.success("アカウントを削除しました");
      loadAccounts(currentPage);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "アカウントの削除に失敗しました");
      }
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="space-y-8">
      {/* ヘッダー */}
      <div>
        <div className="flex items-center gap-2">
          <ShieldCheck className="size-6 text-primary" />
          <h1 className="text-2xl font-bold tracking-tight">アカウント発行</h1>
        </div>
        <p className="mt-1 text-muted-foreground">
          新規テナントとオーナーアカウントを作成します
        </p>
      </div>

      {/* アカウント発行フォーム */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-lg">
            <UserPlus className="size-5" />
            新規アカウント発行
          </CardTitle>
          <CardDescription>
            会社情報とオーナーアカウント情報を入力してください
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {formError && (
              <Alert variant="destructive">
                <AlertDescription>{formError}</AlertDescription>
              </Alert>
            )}

            {/* 発行完了メッセージ */}
            {createdAccount && (
              <Alert className="border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950">
                <AlertDescription className="space-y-3">
                  <p className="font-semibold text-green-800 dark:text-green-200">
                    アカウントを発行しました。以下の情報をユーザーに伝えてください。
                  </p>
                  <div className="space-y-2 text-sm">
                    <div className="flex items-center gap-2">
                      <span className="text-muted-foreground w-32">
                        メールアドレス:
                      </span>
                      <code className="rounded bg-muted px-2 py-0.5">
                        {createdAccount.email}
                      </code>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-7"
                        onClick={() =>
                          handleCopy(createdAccount.email, "email")
                        }
                      >
                        {copiedField === "email" ? (
                          <Check className="size-3.5 text-green-600" />
                        ) : (
                          <Copy className="size-3.5" />
                        )}
                      </Button>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-muted-foreground w-32">
                        パスワード:
                      </span>
                      <code className="rounded bg-muted px-2 py-0.5">
                        {createdAccount.password}
                      </code>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-7"
                        onClick={() =>
                          handleCopy(createdAccount.password, "password")
                        }
                      >
                        {copiedField === "password" ? (
                          <Check className="size-3.5 text-green-600" />
                        ) : (
                          <Copy className="size-3.5" />
                        )}
                      </Button>
                    </div>
                  </div>
                </AlertDescription>
              </Alert>
            )}

            {/* 会社情報 */}
            <div className="space-y-4 rounded-xl border bg-card p-5">
              <p className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">
                会社情報
              </p>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="tenant-name" className="text-[15px] font-medium">
                    会社名
                  </Label>
                  <Input
                    id="tenant-name"
                    type="text"
                    placeholder="株式会社サンプル"
                    className="h-11 text-[15px]"
                    {...register("tenantName")}
                  />
                  {errors.tenantName && (
                    <p className="text-sm text-destructive">
                      {errors.tenantName.message}
                    </p>
                  )}
                </div>
                <div className="space-y-2">
                  <Label
                    htmlFor="industry-type"
                    className="text-[15px] font-medium"
                  >
                    業種
                  </Label>
                  <Controller
                    name="industryCode"
                    control={control}
                    render={({ field }) => (
                      <Select
                        onValueChange={field.onChange}
                        value={field.value}
                      >
                        <SelectTrigger
                          id="industry-type"
                          className="w-full h-11 text-[15px]"
                        >
                          <SelectValue placeholder="業種を選択" />
                        </SelectTrigger>
                        <SelectContent>
                          {INDUSTRY_TYPES.map((industry) => (
                            <SelectItem
                              key={industry.value}
                              value={industry.value}
                            >
                              {industry.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                  {errors.industryCode && (
                    <p className="text-sm text-destructive">
                      {errors.industryCode.message}
                    </p>
                  )}
                </div>
                <div className="space-y-2 sm:col-span-2">
                  <Label
                    htmlFor="plan"
                    className="text-[15px] font-medium"
                  >
                    プラン
                  </Label>
                  <Controller
                    name="plan"
                    control={control}
                    render={({ field }) => (
                      <Select
                        onValueChange={field.onChange}
                        value={field.value}
                      >
                        <SelectTrigger
                          id="plan"
                          className="w-full h-11 text-[15px]"
                        >
                          <SelectValue placeholder="プランを選択" />
                        </SelectTrigger>
                        <SelectContent>
                          {PLAN_OPTIONS.map((plan) => (
                            <SelectItem
                              key={plan.value}
                              value={plan.value}
                            >
                              {plan.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                  {errors.plan && (
                    <p className="text-sm text-destructive">
                      {errors.plan.message}
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* アカウント情報 */}
            <div className="space-y-4 rounded-xl border bg-card p-5">
              <p className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">
                オーナーアカウント情報
              </p>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="user-name" className="text-[15px] font-medium">
                    氏名
                  </Label>
                  <Input
                    id="user-name"
                    type="text"
                    placeholder="山田 太郎"
                    className="h-11 text-[15px]"
                    {...register("name")}
                  />
                  {errors.name && (
                    <p className="text-sm text-destructive">
                      {errors.name.message}
                    </p>
                  )}
                </div>
                <div className="space-y-2">
                  <Label htmlFor="email" className="text-[15px] font-medium">
                    メールアドレス
                  </Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="example@company.co.jp"
                    className="h-11 text-[15px]"
                    {...register("email")}
                  />
                  {errors.email && (
                    <p className="text-sm text-destructive">
                      {errors.email.message}
                    </p>
                  )}
                </div>
                <div className="space-y-2 sm:col-span-2">
                  <Label htmlFor="password" className="text-[15px] font-medium">
                    初期パスワード
                  </Label>
                  <div className="relative">
                    <Input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      placeholder="8文字以上で入力"
                      className="h-11 text-[15px] pr-10"
                      {...register("password")}
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="absolute right-1 top-1/2 -translate-y-1/2 size-8"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? (
                        <EyeOff className="size-4" />
                      ) : (
                        <Eye className="size-4" />
                      )}
                    </Button>
                  </div>
                  {errors.password && (
                    <p className="text-sm text-destructive">
                      {errors.password.message}
                    </p>
                  )}
                </div>
              </div>
            </div>

            <div className="flex justify-end">
              <Button
                type="submit"
                className="h-11 px-8 text-[15px] font-semibold"
                disabled={isSubmitting}
              >
                {isSubmitting && (
                  <Loader2 className="mr-2 size-4 animate-spin" />
                )}
                <UserPlus className="mr-2 size-4" />
                {isSubmitting ? "発行中..." : "アカウントを発行"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      <Separator />

      {/* 発行済みアカウント一覧 */}
      <div className="space-y-4">
        <h2 className="text-lg font-semibold">発行済みアカウント一覧</h2>

        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-16 w-full" />
            ))}
          </div>
        ) : accounts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <p className="text-lg font-medium text-muted-foreground">
              発行済みアカウントはありません
            </p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>会社名</TableHead>
                    <TableHead>業種</TableHead>
                    <TableHead>オーナー</TableHead>
                    <TableHead>メールアドレス</TableHead>
                    <TableHead>プラン</TableHead>
                    <TableHead className="text-center">ユーザー数</TableHead>
                    <TableHead>発行日</TableHead>
                    <TableHead className="w-16" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {accounts.map((account) => (
                    <TableRow key={account.id}>
                      <TableCell className="font-medium">
                        {account.tenant_name}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {account.industry_type}
                      </TableCell>
                      <TableCell>{account.owner_name ?? "-"}</TableCell>
                      <TableCell className="text-sm">
                        {account.owner_email ?? "-"}
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline" className="capitalize">{account.plan}</Badge>
                      </TableCell>
                      <TableCell className="text-center tabular-nums">
                        {account.users_count}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {new Date(account.created_at).toLocaleDateString(
                          "ja-JP"
                        )}
                      </TableCell>
                      <TableCell>
                        {!account.has_system_admin && (
                          <AlertDialog>
                            <AlertDialogTrigger asChild>
                              <Button
                                variant="ghost"
                                size="icon"
                                className="size-8 text-muted-foreground hover:text-destructive"
                                disabled={deletingId === account.id}
                              >
                                {deletingId === account.id ? (
                                  <Loader2 className="size-4 animate-spin" />
                                ) : (
                                  <Trash2 className="size-4" />
                                )}
                              </Button>
                            </AlertDialogTrigger>
                            <AlertDialogContent>
                              <AlertDialogHeader>
                                <AlertDialogTitle>
                                  アカウントを削除しますか？
                                </AlertDialogTitle>
                                <AlertDialogDescription>
                                  「{account.tenant_name}」のアカウントと所属するすべてのユーザーが削除されます。この操作は取り消せません。
                                </AlertDialogDescription>
                              </AlertDialogHeader>
                              <AlertDialogFooter>
                                <AlertDialogCancel>キャンセル</AlertDialogCancel>
                                <AlertDialogAction
                                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                                  onClick={() => handleDelete(account.id)}
                                >
                                  削除する
                                </AlertDialogAction>
                              </AlertDialogFooter>
                            </AlertDialogContent>
                          </AlertDialog>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* ページネーション */}
            <div className="flex items-center justify-between pt-2">
              <p className="text-sm text-muted-foreground">
                全{totalCount}件
              </p>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => loadAccounts(currentPage - 1)}
                  disabled={currentPage <= 1}
                >
                  <ChevronLeft className="size-4" />
                </Button>
                <span className="text-sm">
                  {currentPage} / {totalPages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => loadAccounts(currentPage + 1)}
                  disabled={currentPage >= totalPages}
                >
                  <ChevronRight className="size-4" />
                </Button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
