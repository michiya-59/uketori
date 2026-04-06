"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api, ApiClientError } from "@/lib/api-client";
import { useAuth } from "@/hooks/use-auth";

interface IndustryTemplate {
  code: string;
  name: string;
}

const signUpSchema = z.object({
  tenant_name: z.string().min(1, "会社名を入力してください").max(255, "会社名は255文字以内で入力してください"),
  industry_code: z.string().min(1, "業種を選択してください"),
  name: z.string().min(1, "お名前を入力してください"),
  email: z.string().min(1, "メールアドレスを入力してください").email("有効なメールアドレスを入力してください"),
  password: z.string()
    .min(8, "パスワードは8文字以上で入力してください")
    .regex(/[a-z]/, "英小文字を1文字以上含めてください")
    .regex(/[A-Z]/, "英大文字を1文字以上含めてください")
    .regex(/\d/, "数字を1文字以上含めてください")
    .regex(/[^A-Za-z0-9]/, "記号を1文字以上含めてください"),
  password_confirmation: z.string().min(1, "確認用パスワードを入力してください"),
}).refine((data) => data.password === data.password_confirmation, {
  message: "パスワード確認が一致しません",
  path: ["password_confirmation"],
});

type SignUpFormData = z.infer<typeof signUpSchema>;

export default function SignUpPage() {
  const { signUp } = useAuth();
  const [industries, setIndustries] = useState<IndustryTemplate[]>([]);
  const [loadingIndustries, setLoadingIndustries] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<SignUpFormData>({
    resolver: zodResolver(signUpSchema),
    defaultValues: {
      tenant_name: "",
      industry_code: "",
      name: "",
      email: "",
      password: "",
      password_confirmation: "",
    },
  });

  useEffect(() => {
    const loadIndustries = async () => {
      try {
        const result = await api.get<{ industry_templates: IndustryTemplate[] }>("/api/v1/industry_templates");
        setIndustries(result.industry_templates);
      } catch {
        setError("業種一覧の取得に失敗しました");
      } finally {
        setLoadingIndustries(false);
      }
    };

    loadIndustries();
  }, []);

  const onSubmit = async (data: SignUpFormData) => {
    setError(null);
    try {
      await signUp(data);
    } catch (e) {
      if (e instanceof ApiClientError) {
        setError(e.body?.error?.message ?? "新規登録に失敗しました");
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
          会社情報とオーナー情報を入力して利用を開始します
        </p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        {error && <p className="text-sm text-destructive">{error}</p>}

        <div className="space-y-2">
          <Label htmlFor="tenant_name" className="text-[15px] font-medium">
            会社名
          </Label>
          <Input
            id="tenant_name"
            placeholder="株式会社サンプル"
            className="h-11 text-[15px]"
            {...register("tenant_name")}
          />
          {errors.tenant_name && (
            <p className="text-sm text-destructive">{errors.tenant_name.message}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="industry_code" className="text-[15px] font-medium">
            業種
          </Label>
          <Select
            value={watch("industry_code")}
            onValueChange={(value) => setValue("industry_code", value, { shouldValidate: true })}
            disabled={loadingIndustries}
          >
            <SelectTrigger id="industry_code" className="h-11 text-[15px]">
              <SelectValue placeholder={loadingIndustries ? "読み込み中..." : "業種を選択してください"} />
            </SelectTrigger>
            <SelectContent>
              {industries.map((industry) => (
                <SelectItem key={industry.code} value={industry.code}>
                  {industry.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {errors.industry_code && (
            <p className="text-sm text-destructive">{errors.industry_code.message}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="name" className="text-[15px] font-medium">
            お名前
          </Label>
          <Input
            id="name"
            placeholder="鈴木 太郎"
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
            placeholder="owner@example.co.jp"
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
            autoComplete="new-password"
            placeholder="SecureP@ss123"
            className="h-11 text-[15px]"
            {...register("password")}
          />
          {errors.password && (
            <p className="text-sm text-destructive">{errors.password.message}</p>
          )}
          <p className="text-xs text-muted-foreground">
            8文字以上で、英大文字・英小文字・数字・記号を各1文字以上含めてください。
          </p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="password_confirmation" className="text-[15px] font-medium">
            パスワード確認
          </Label>
          <Input
            id="password_confirmation"
            type="password"
            autoComplete="new-password"
            placeholder="パスワードを再入力"
            className="h-11 text-[15px]"
            {...register("password_confirmation")}
          />
          {errors.password_confirmation && (
            <p className="text-sm text-destructive">{errors.password_confirmation.message}</p>
          )}
        </div>

        <Button
          type="submit"
          className="h-11 w-full text-[15px] font-semibold"
          disabled={isSubmitting || loadingIndustries}
        >
          {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
          {isSubmitting ? "登録中..." : "無料ではじめる"}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-muted-foreground">
        すでにアカウントをお持ちの場合は{" "}
        <Link href="/login" className="font-medium text-primary hover:text-primary/80">
          ログイン
        </Link>
      </p>
    </div>
  );
}
