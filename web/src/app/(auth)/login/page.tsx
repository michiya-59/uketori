"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { api, ApiClientError } from "@/lib/api-client";
import { setTokens } from "@/lib/auth";
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
      router.push("/dashboard");
    } catch (e) {
      if (e instanceof ApiClientError) {
        setError(e.body?.error?.message ?? "ログインに失敗しました");
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
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
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
        <p className="text-center text-[15px] text-muted-foreground">
          アカウントをお持ちでない方は{" "}
          <Link
            href="/signup"
            className="font-semibold text-primary hover:text-primary/80 transition-colors"
          >
            新規登録
          </Link>
        </p>
      </form>
    </div>
  );
}
