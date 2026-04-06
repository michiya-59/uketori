"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2, ShieldAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiClientError } from "@/lib/api-client";
import { setStoredUser, setTokens } from "@/lib/auth";
import type { SignInResponse } from "@/types/user";

/** ログインフォームのバリデーションスキーマ */
const loginSchema = z.object({
  email: z.string().min(1, "メールアドレスを入力してください").email("有効なメールアドレスを入力してください"),
  password: z.string().min(1, "パスワードを入力してください"),
});

type LoginFormData = z.infer<typeof loginSchema>;

/**
 * ログインページ
 * メールアドレスとパスワードによるログインフォームを表示する
 * @returns ログインページ要素
 */
export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [ipRestricted] = useState(() => {
    if (typeof window === "undefined") return false;

    const restricted = sessionStorage.getItem("ip_restricted") === "1";
    if (restricted) {
      sessionStorage.removeItem("ip_restricted");
    }

    return restricted;
  });

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  /**
   * ログインフォームの送信ハンドラ
   * @param data - バリデーション済みフォームデータ
   */
  const onSubmit = async (data: LoginFormData) => {
    setError(null);
    try {
      const result = await api.post<SignInResponse>("/api/v1/auth/sign_in", {
        auth: { email: data.email, password: data.password },
      });
      setTokens(result.tokens.access_token, result.tokens.refresh_token);
      setStoredUser({ name: result.user.name, email: result.user.email, role: result.user.role });
      router.push("/dashboard");
    } catch (e) {
      if (e instanceof ApiClientError) {
        if (e.status === 403 && e.body?.error?.code === "ip_restricted") {
          const yourIp = (e.body?.error as Record<string, unknown>)?.your_ip;
          setError(
            `許可されていないIPアドレスからのアクセスです。${yourIp ? `（あなたのIP: ${yourIp}）` : ""}管理者にお問い合わせください。`
          );
        } else {
          setError(e.body?.error?.message ?? "ログインに失敗しました");
        }
      } else {
        setError("通信エラーが発生しました");
      }
    }
  };

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">ログイン</h1>
        <p className="mt-2 text-muted-foreground">
          メールアドレスとパスワードを入力してください
        </p>
      </div>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        {ipRestricted && (
          <div className="rounded-lg border border-destructive/30 bg-destructive/5 px-4 py-3">
            <div className="flex gap-2">
              <ShieldAlert className="size-4 mt-0.5 shrink-0 text-destructive" />
              <div>
                <p className="text-sm font-medium text-destructive">
                  許可されていないIPアドレスからのアクセスです
                </p>
                <p className="mt-1 text-xs text-destructive/80">
                  お使いのネットワークからのアクセスが制限されています。管理者にお問い合わせください。
                </p>
              </div>
            </div>
          </div>
        )}
        {error && (
          <p className="text-sm text-destructive">{error}</p>
        )}
        <div className="space-y-2">
          <Label htmlFor="email" className="text-[15px] font-medium">
            メールアドレス
          </Label>
          <Input
            id="email"
            type="email"
            placeholder="example@company.co.jp"
            autoComplete="email"
            className="h-11 text-[15px]"
            {...register("email")}
          />
          {errors.email && (
            <p className="text-sm text-destructive">{errors.email.message}</p>
          )}
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password" className="text-[15px] font-medium">
              パスワード
            </Label>
            <Link
              href="/password/reset"
              className="text-sm text-primary hover:text-primary/80 transition-colors"
            >
              パスワードをお忘れですか？
            </Link>
          </div>
          <Input
            id="password"
            type="password"
            placeholder="パスワードを入力"
            autoComplete="current-password"
            className="h-11 text-[15px]"
            {...register("password")}
          />
          {errors.password && (
            <p className="text-sm text-destructive">{errors.password.message}</p>
          )}
        </div>
        <Button
          type="submit"
          className="w-full h-11 text-[15px] font-semibold"
          disabled={isSubmitting}
        >
          {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
          {isSubmitting ? "ログイン中..." : "ログイン"}
        </Button>
      </form>
      <p className="mt-6 text-center text-sm text-muted-foreground">
        アカウントをお持ちでない場合は{" "}
        <Link href="/signup" className="font-medium text-primary hover:text-primary/80 transition-colors">
          新規登録
        </Link>
      </p>
    </div>
  );
}
