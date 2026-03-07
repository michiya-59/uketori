"use client";

import { useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2, ArrowLeft, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { api, ApiClientError } from "@/lib/api-client";

/** メール入力フォームのバリデーションスキーマ */
const emailSchema = z.object({
  email: z
    .string()
    .min(1, "メールアドレスを入力してください")
    .email("有効なメールアドレスを入力してください"),
});

/** 新パスワードフォームのバリデーションスキーマ */
const passwordSchema = z
  .object({
    password: z.string().min(8, "パスワードは8文字以上で入力してください"),
    password_confirmation: z.string().min(1, "パスワード（確認）を入力してください"),
  })
  .refine((data) => data.password === data.password_confirmation, {
    message: "パスワードが一致しません",
    path: ["password_confirmation"],
  });

type EmailFormData = z.infer<typeof emailSchema>;
type PasswordFormData = z.infer<typeof passwordSchema>;

/**
 * パスワードリセットページ
 * token パラメータがない場合: メール入力フォーム表示
 * token パラメータがある場合: 新パスワード設定フォーム表示
 * @returns パスワードリセットページ要素
 */
export default function PasswordResetPage() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  if (token) {
    return <ResetPasswordForm token={token} />;
  }

  return <RequestResetForm />;
}

/**
 * パスワードリセットリクエストフォーム（メール入力）
 * @returns リセットリクエストフォーム要素
 */
function RequestResetForm() {
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<EmailFormData>({
    resolver: zodResolver(emailSchema),
  });

  /**
   * リセットメール送信リクエストのハンドラ
   * @param data - バリデーション済みフォームデータ
   */
  const onSubmit = async (data: EmailFormData) => {
    setError(null);
    try {
      await api.post("/api/v1/auth/password/reset", {
        auth: { email: data.email },
      });
      setSent(true);
    } catch (e) {
      if (e instanceof ApiClientError) {
        // セキュリティのため、メールが存在しなくても成功扱いにする
        setSent(true);
      } else {
        setError("通信エラーが発生しました");
      }
    }
  };

  if (sent) {
    return (
      <div>
        <div className="mb-8 text-center">
          <CheckCircle2 className="mx-auto mb-4 size-12 text-green-500" />
          <h1 className="text-2xl font-bold tracking-tight">メールを送信しました</h1>
          <p className="mt-2 text-muted-foreground">
            パスワードリセットのメールを送信しました。
            <br />
            メールに記載されたリンクから新しいパスワードを設定してください。
          </p>
        </div>
        <Link href="/login">
          <Button variant="outline" className="w-full h-11 gap-2 text-[15px]">
            <ArrowLeft className="size-4" />
            ログインに戻る
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">パスワードリセット</h1>
        <p className="mt-2 text-muted-foreground">
          登録済みのメールアドレスを入力してください。
          <br />
          パスワードリセットのリンクをお送りします。
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
        <Button
          type="submit"
          className="w-full h-11 text-[15px] font-semibold"
          disabled={isSubmitting}
        >
          {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
          {isSubmitting ? "送信中..." : "リセットメールを送信"}
        </Button>
        <p className="text-center text-[15px] text-muted-foreground">
          <Link
            href="/login"
            className="font-semibold text-primary hover:text-primary/80 transition-colors"
          >
            ログインに戻る
          </Link>
        </p>
      </form>
    </div>
  );
}

/**
 * パスワード再設定フォーム（新パスワード入力）
 * @param token - リセットトークン
 * @returns 新パスワード設定フォーム要素
 */
function ResetPasswordForm({ token }: { token: string }) {
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<PasswordFormData>({
    resolver: zodResolver(passwordSchema),
  });

  /**
   * パスワード更新のハンドラ
   * @param data - バリデーション済みフォームデータ
   */
  const onSubmit = async (data: PasswordFormData) => {
    setError(null);
    try {
      await api.patch("/api/v1/auth/password/update", {
        auth: {
          reset_token: token,
          password: data.password,
          password_confirmation: data.password_confirmation,
        },
      });
      setSuccess(true);
    } catch (e) {
      if (e instanceof ApiClientError) {
        setError(
          e.body?.error?.message ?? "パスワードの更新に失敗しました"
        );
      } else {
        setError("通信エラーが発生しました");
      }
    }
  };

  if (success) {
    return (
      <div>
        <div className="mb-8 text-center">
          <CheckCircle2 className="mx-auto mb-4 size-12 text-green-500" />
          <h1 className="text-2xl font-bold tracking-tight">
            パスワードを変更しました
          </h1>
          <p className="mt-2 text-muted-foreground">
            新しいパスワードでログインしてください。
          </p>
        </div>
        <Link href="/login">
          <Button className="w-full h-11 text-[15px] font-semibold">
            ログインへ
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">
          新しいパスワードを設定
        </h1>
        <p className="mt-2 text-muted-foreground">
          新しいパスワードを入力してください。
        </p>
      </div>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}
        <div className="space-y-2">
          <Label htmlFor="password" className="text-[15px] font-medium">
            新しいパスワード
          </Label>
          <Input
            id="password"
            type="password"
            placeholder="8文字以上"
            autoComplete="new-password"
            className="h-11 text-[15px]"
            {...register("password")}
          />
          {errors.password && (
            <p className="text-sm text-destructive">
              {errors.password.message}
            </p>
          )}
        </div>
        <div className="space-y-2">
          <Label
            htmlFor="password_confirmation"
            className="text-[15px] font-medium"
          >
            パスワード（確認）
          </Label>
          <Input
            id="password_confirmation"
            type="password"
            placeholder="もう一度入力してください"
            autoComplete="new-password"
            className="h-11 text-[15px]"
            {...register("password_confirmation")}
          />
          {errors.password_confirmation && (
            <p className="text-sm text-destructive">
              {errors.password_confirmation.message}
            </p>
          )}
        </div>
        <Button
          type="submit"
          className="w-full h-11 text-[15px] font-semibold"
          disabled={isSubmitting}
        >
          {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
          {isSubmitting ? "更新中..." : "パスワードを更新"}
        </Button>
      </form>
    </div>
  );
}
