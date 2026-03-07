"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useForm, Controller } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api, ApiClientError } from "@/lib/api-client";
import { setTokens } from "@/lib/auth";
import type { SignUpResponse } from "@/types/user";

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

/** サインアップフォームのバリデーションスキーマ */
const signupSchema = z.object({
  tenantName: z.string().min(1, "会社名を入力してください").max(255),
  industryCode: z.string().min(1, "業種を選択してください"),
  name: z.string().min(1, "氏名を入力してください").max(100),
  email: z.string().min(1, "メールアドレスを入力してください").email("有効なメールアドレスを入力してください"),
  password: z.string().min(8, "パスワードは8文字以上で入力してください"),
});

type SignupFormData = z.infer<typeof signupSchema>;

/**
 * 新規登録ページ
 * テナント名・業種・ユーザー名・メールアドレス・パスワードの入力フォームを表示する
 * @returns 新規登録ページ要素
 */
export default function SignupPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting },
  } = useForm<SignupFormData>({
    resolver: zodResolver(signupSchema),
  });

  /**
   * 新規登録フォームの送信ハンドラ
   * @param data - バリデーション済みフォームデータ
   */
  const onSubmit = async (data: SignupFormData) => {
    setError(null);
    try {
      const result = await api.post<SignUpResponse>("/api/v1/auth/sign_up", {
        auth: {
          tenant_name: data.tenantName,
          industry_code: data.industryCode,
          name: data.name,
          email: data.email,
          password: data.password,
          password_confirmation: data.password,
        },
      });
      setTokens(result.tokens.access_token, result.tokens.refresh_token);
      router.push("/dashboard");
    } catch (e) {
      if (e instanceof ApiClientError) {
        setError(e.body?.error?.message ?? "登録に失敗しました");
      } else {
        setError("通信エラーが発生しました");
      }
    }
  };

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">新規登録</h1>
        <p className="mt-2 text-muted-foreground">
          会社情報とアカウント情報を入力してください
        </p>
      </div>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}
        <div className="space-y-4 rounded-xl border bg-card p-5">
          <p className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">
            会社情報
          </p>
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
              <p className="text-sm text-destructive">{errors.tenantName.message}</p>
            )}
          </div>
          <div className="space-y-2">
            <Label htmlFor="industry-type" className="text-[15px] font-medium">
              業種
            </Label>
            <Controller
              name="industryCode"
              control={control}
              render={({ field }) => (
                <Select onValueChange={field.onChange} value={field.value}>
                  <SelectTrigger id="industry-type" className="w-full h-11 text-[15px]">
                    <SelectValue placeholder="業種を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {INDUSTRY_TYPES.map((industry) => (
                      <SelectItem key={industry.value} value={industry.value}>
                        {industry.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
            {errors.industryCode && (
              <p className="text-sm text-destructive">{errors.industryCode.message}</p>
            )}
          </div>
        </div>
        <div className="space-y-4 rounded-xl border bg-card p-5">
          <p className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">
            アカウント情報
          </p>
          <div className="space-y-2">
            <Label htmlFor="user-name" className="text-[15px] font-medium">
              氏名
            </Label>
            <Input
              id="user-name"
              type="text"
              placeholder="山田 太郎"
              autoComplete="name"
              className="h-11 text-[15px]"
              {...register("name")}
            />
            {errors.name && (
              <p className="text-sm text-destructive">{errors.name.message}</p>
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
              autoComplete="email"
              className="h-11 text-[15px]"
              {...register("email")}
            />
            {errors.email && (
              <p className="text-sm text-destructive">{errors.email.message}</p>
            )}
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-[15px] font-medium">
              パスワード
            </Label>
            <Input
              id="password"
              type="password"
              placeholder="8文字以上で入力"
              autoComplete="new-password"
              className="h-11 text-[15px]"
              {...register("password")}
            />
            {errors.password && (
              <p className="text-sm text-destructive">{errors.password.message}</p>
            )}
          </div>
        </div>
        <Button
          type="submit"
          className="w-full h-11 text-[15px] font-semibold"
          disabled={isSubmitting}
        >
          {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
          {isSubmitting ? "登録中..." : "無料で始める"}
        </Button>
        <p className="text-center text-[15px] text-muted-foreground">
          すでにアカウントをお持ちの方は{" "}
          <Link
            href="/login"
            className="font-semibold text-primary hover:text-primary/80 transition-colors"
          >
            ログイン
          </Link>
        </p>
      </form>
    </div>
  );
}
