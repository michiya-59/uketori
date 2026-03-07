"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { ArrowLeft, Loader2, Save } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
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
import { api, ApiClientError } from "@/lib/api-client";
import type { Customer } from "@/types/customer";
import type { Project } from "@/types/project";
import type { User } from "@/types/user";

/** 案件フォームのバリデーションスキーマ */
const projectSchema = z.object({
  name: z.string().min(1, "案件名を入力してください"),
  customer_id: z.string().min(1, "顧客を選択してください"),
  assigned_user_id: z.string().optional(),
  probability: z.number().min(0).max(100).optional().nullable(),
  amount: z.number().min(0).optional().nullable(),
  cost: z.number().min(0).optional().nullable(),
  start_date: z.string().optional(),
  end_date: z.string().optional(),
  description: z.string().optional(),
});

type ProjectFormData = z.infer<typeof projectSchema>;

/** 顧客一覧レスポンス型 */
interface CustomersResponse {
  customers: Customer[];
  meta: { total_count: number };
}

/** ユーザー一覧レスポンス型 */
interface UsersResponse {
  users: User[];
  meta: { total_count: number };
}

/**
 * 案件新規登録ページ
 * 案件情報の入力フォームを提供する
 * @returns 案件新規登録ページ要素
 */
export default function NewProjectPage() {
  const router = useRouter();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [users, setUsers] = useState<User[]>([]);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<ProjectFormData>({
    resolver: zodResolver(projectSchema),
    defaultValues: {
      probability: 50,
    },
  });

  /** 顧客一覧を取得する */
  const loadCustomers = useCallback(async () => {
    try {
      const res = await api.get<CustomersResponse>("/api/v1/customers", {
        per_page: 100,
      });
      setCustomers(res.customers);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("顧客一覧の取得に失敗しました");
      }
    }
  }, []);

  /** ユーザー一覧を取得する */
  const loadUsers = useCallback(async () => {
    try {
      const res = await api.get<UsersResponse>("/api/v1/users", {
        per_page: 100,
      });
      setUsers(res.users);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error("ユーザー一覧の取得に失敗しました");
      }
    }
  }, []);

  useEffect(() => {
    loadCustomers();
    loadUsers();
  }, [loadCustomers, loadUsers]);

  /**
   * フォームの送信を処理する
   * @param data - フォームデータ
   */
  const onSubmit = async (data: ProjectFormData) => {
    try {
      const res = await api.post<{ project: Project }>("/api/v1/projects", {
        project: data,
      });
      toast.success("案件を登録しました");
      router.push(`/projects/${res.project.id}`);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "登録に失敗しました");
      }
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild className="size-10 sm:size-9">
          <Link href="/projects">
            <ArrowLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">案件の新規登録</h1>
          <p className="mt-1 text-muted-foreground">
            新しい案件を登録します
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">基本情報</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">
                  案件名 <span className="text-destructive">*</span>
                </Label>
                <Input
                  {...register("name")}
                  className="h-11 text-[15px]"
                  placeholder="Webサイト構築案件"
                />
                {errors.name && (
                  <p className="text-sm text-destructive">
                    {errors.name.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">
                  顧客 <span className="text-destructive">*</span>
                </Label>
                <Select
                  value={watch("customer_id") ?? ""}
                  onValueChange={(v) => setValue("customer_id", v)}
                >
                  <SelectTrigger className="h-11">
                    <SelectValue placeholder="顧客を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {customers.map((c) => (
                      <SelectItem key={c.id} value={c.id}>
                        {c.company_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {errors.customer_id && (
                  <p className="text-sm text-destructive">
                    {errors.customer_id.message}
                  </p>
                )}
              </div>
            </div>

            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">担当者</Label>
                <Select
                  value={watch("assigned_user_id") ?? ""}
                  onValueChange={(v) => setValue("assigned_user_id", v)}
                >
                  <SelectTrigger className="h-11">
                    <SelectValue placeholder="担当者を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {users.map((u) => (
                      <SelectItem key={u.id} value={u.id}>
                        {u.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">受注確度 (%)</Label>
                <Input
                  type="number"
                  {...register("probability", { valueAsNumber: true })}
                  className="h-11 text-[15px]"
                  placeholder="50"
                  min={0}
                  max={100}
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">詳細</CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">見込金額</Label>
                <Input
                  type="number"
                  {...register("amount", { valueAsNumber: true })}
                  className="h-11 text-[15px]"
                  placeholder="1000000"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">原価</Label>
                <Input
                  type="number"
                  {...register("cost", { valueAsNumber: true })}
                  className="h-11 text-[15px]"
                  placeholder="500000"
                />
              </div>
            </div>

            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">開始日</Label>
                <Input
                  type="date"
                  {...register("start_date")}
                  className="h-11 text-[15px]"
                />
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">終了日</Label>
                <Input
                  type="date"
                  {...register("end_date")}
                  className="h-11 text-[15px]"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-[15px]">説明</Label>
              <textarea
                {...register("description")}
                className="flex min-h-[100px] w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                placeholder="案件の詳細な説明"
              />
            </div>
          </CardContent>
        </Card>

        <div className="flex justify-end gap-3">
          <Button variant="outline" type="button" asChild>
            <Link href="/projects">キャンセル</Link>
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting && <Loader2 className="mr-2 size-4 animate-spin" />}
            <Save className="mr-2 size-4" />
            登録する
          </Button>
        </div>
      </form>
    </div>
  );
}
