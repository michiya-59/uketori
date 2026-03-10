"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Bug,
  Lightbulb,
  CreditCard,
  Receipt,
  UserCog,
  Database,
  ShieldAlert,
  HelpCircle,
  Loader2,
  Send,
  CheckCircle2,
  MessageSquarePlus,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { api, ApiClientError } from "@/lib/api-client";

/** お問い合わせカテゴリの定義 */
interface CategoryDef {
  value: string;
  label: string;
  description: string;
  icon: LucideIcon;
  placeholderSubject: string;
  placeholderBody: string;
}

/** お問い合わせカテゴリ一覧 */
const CATEGORIES: CategoryDef[] = [
  {
    value: "bug",
    label: "不具合報告",
    description: "システムのエラーや正しく動作しない機能について",
    icon: Bug,
    placeholderSubject: "例: 請求書PDFが生成されない",
    placeholderBody:
      "どの画面で、どのような操作を行った際に、どのような問題が発生したかを詳しくお書きください。\n\n【発生画面】\n\n【操作手順】\n1. \n2. \n3. \n\n【期待する動作】\n\n【実際の動作】\n",
  },
  {
    value: "feature_request",
    label: "機能要望",
    description: "新機能の提案や既存機能の改善要望",
    icon: Lightbulb,
    placeholderSubject: "例: CSVエクスポート機能が欲しい",
    placeholderBody:
      "どのような機能があると便利か、どのような場面で使いたいかをお書きください。\n\n【希望する機能】\n\n【利用シーン】\n\n【その他補足】\n",
  },
  {
    value: "plan_inquiry",
    label: "プラン変更",
    description: "プランのアップグレード・ダウングレードについて",
    icon: CreditCard,
    placeholderSubject: "例: Professionalプランへのアップグレード希望",
    placeholderBody:
      "現在のプランと希望するプラン、変更理由をお書きください。\n\n【希望プラン】\n\n【変更理由】\n",
  },
  {
    value: "billing",
    label: "請求・お支払い",
    description: "請求書、支払い方法、領収書などについて",
    icon: Receipt,
    placeholderSubject: "例: 領収書の再発行をお願いしたい",
    placeholderBody: "お支払いに関するご質問やご要望をお書きください。\n\n",
  },
  {
    value: "account",
    label: "アカウント",
    description: "ログイン、パスワード、ユーザー権限などについて",
    icon: UserCog,
    placeholderSubject: "例: パスワードリセットができない",
    placeholderBody:
      "アカウントに関する問題やご質問をお書きください。\n\n【対象アカウント（メールアドレス）】\n\n【詳細】\n",
  },
  {
    value: "data_issue",
    label: "データに関する問題",
    description: "データの不整合、誤削除、インポート/エクスポートの問題",
    icon: Database,
    placeholderSubject: "例: インポートしたデータが正しく反映されない",
    placeholderBody:
      "データに関する問題を詳しくお書きください。\n\n【対象データ】\n\n【問題の詳細】\n\n【発生日時（わかれば）】\n",
  },
  {
    value: "security",
    label: "セキュリティ",
    description: "セキュリティに関する懸念や報告",
    icon: ShieldAlert,
    placeholderSubject: "例: 不審なアクセスがあった",
    placeholderBody:
      "セキュリティに関する懸念を詳しくお書きください。\n※ 緊急の場合は優先度「緊急」を選択してください。\n\n【詳細】\n",
  },
  {
    value: "other",
    label: "その他",
    description: "上記に該当しないお問い合わせ",
    icon: HelpCircle,
    placeholderSubject: "お問い合わせの件名",
    placeholderBody: "お問い合わせ内容をお書きください。\n\n",
  },
];

/** お問い合わせフォームのバリデーションスキーマ */
const contactSchema = z.object({
  category: z.string().min(1, "カテゴリを選択してください"),
  subject: z.string().min(1, "件名を入力してください").max(200, "件名は200文字以内で入力してください"),
  body: z.string().min(10, "お問い合わせ内容は10文字以上で入力してください").max(5000, "お問い合わせ内容は5000文字以内で入力してください"),
  priority: z.string().min(1),
});

type ContactFormData = z.infer<typeof contactSchema>;

/**
 * お問い合わせページ
 * カテゴリ選択と詳細入力フォームを提供する
 * @returns お問い合わせページ要素
 */
export default function ContactPage() {
  const router = useRouter();
  const [selectedCategory, setSelectedCategory] = useState<CategoryDef | null>(null);
  const [submitted, setSubmitted] = useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<ContactFormData>({
    resolver: zodResolver(contactSchema),
    defaultValues: {
      category: "",
      subject: "",
      body: "",
      priority: "normal",
    },
  });

  /**
   * カテゴリを選択してフォーム表示に切り替える
   * @param cat - 選択されたカテゴリ
   */
  const handleSelectCategory = (cat: CategoryDef) => {
    setSelectedCategory(cat);
    setValue("category", cat.value);
    setValue("body", cat.placeholderBody);
  };

  /**
   * フォームを送信する
   * @param data - フォームデータ
   */
  const onSubmit = async (data: ContactFormData) => {
    try {
      await api.post("/api/v1/contact", {
        ...data,
        page_url: window.location.href,
      });
      setSubmitted(true);
      toast.success("お問い合わせを送信しました");
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message ?? "送信に失敗しました");
      }
    }
  };

  /**
   * フォームをリセットしてカテゴリ選択に戻る
   */
  const handleReset = () => {
    setSelectedCategory(null);
    setSubmitted(false);
    reset();
  };

  // 送信完了画面
  if (submitted) {
    return (
      <div className="mx-auto max-w-2xl space-y-6">
        <div className="text-center space-y-4 py-12">
          <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30">
            <CheckCircle2 className="size-8 text-green-600 dark:text-green-400" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">
            お問い合わせを受け付けました
          </h1>
          <p className="text-muted-foreground max-w-md mx-auto">
            サポートチームより折り返しご連絡いたします。
            通常1〜2営業日以内にご返信いたします。
          </p>
          <div className="flex justify-center gap-3 pt-4">
            <Button variant="outline" onClick={handleReset}>
              新しいお問い合わせ
            </Button>
            <Button onClick={() => router.push("/dashboard")}>
              ダッシュボードへ
            </Button>
          </div>
        </div>
      </div>
    );
  }

  // カテゴリ未選択: カテゴリ選択画面
  if (!selectedCategory) {
    return (
      <div className="mx-auto max-w-3xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">お問い合わせ</h1>
          <p className="mt-1 text-muted-foreground">
            お問い合わせの種類を選択してください
          </p>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {CATEGORIES.map((cat) => (
            <Card
              key={cat.value}
              className="cursor-pointer transition-all hover:border-primary hover:shadow-md"
              onClick={() => handleSelectCategory(cat)}
            >
              <CardContent className="flex items-start gap-4 p-5">
                <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted">
                  <cat.icon className="size-5 text-muted-foreground" />
                </div>
                <div className="space-y-1">
                  <p className="text-[15px] font-medium leading-tight">{cat.label}</p>
                  <p className="text-[13px] text-muted-foreground leading-snug">
                    {cat.description}
                  </p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  // カテゴリ選択済み: フォーム入力画面
  const Icon = selectedCategory.icon;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div>
        <button
          onClick={handleReset}
          className="mb-3 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          &larr; カテゴリ選択に戻る
        </button>
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-lg bg-muted">
            <Icon className="size-5 text-muted-foreground" />
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">
              {selectedCategory.label}
            </h1>
            <p className="text-sm text-muted-foreground">
              {selectedCategory.description}
            </p>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">お問い合わせ内容</CardTitle>
            <CardDescription>
              できるだけ詳しくお書きいただくことで、より迅速に対応できます
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-[15px]">
                  件名 <span className="text-destructive">*</span>
                </Label>
                <Input
                  {...register("subject")}
                  className="h-11 text-[15px]"
                  placeholder={selectedCategory.placeholderSubject}
                />
                {errors.subject && (
                  <p className="text-sm text-destructive">
                    {errors.subject.message}
                  </p>
                )}
              </div>
              <div className="space-y-2">
                <Label className="text-[15px]">優先度</Label>
                <Select
                  value={watch("priority")}
                  onValueChange={(v) => setValue("priority", v)}
                >
                  <SelectTrigger className="h-11">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="low">低 - 急ぎではない</SelectItem>
                    <SelectItem value="normal">通常</SelectItem>
                    <SelectItem value="high">高 - 業務に支障がある</SelectItem>
                    <SelectItem value="urgent">緊急 - 業務が停止している</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-[15px]">
                お問い合わせ内容 <span className="text-destructive">*</span>
              </Label>
              <textarea
                {...register("body")}
                rows={12}
                className="flex w-full rounded-md border border-input bg-background px-3 py-2 text-[15px] ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                placeholder={selectedCategory.placeholderBody}
              />
              <div className="flex items-center justify-between">
                {errors.body ? (
                  <p className="text-sm text-destructive">
                    {errors.body.message}
                  </p>
                ) : (
                  <span />
                )}
                <p className="text-xs text-muted-foreground">
                  {(watch("body") || "").length} / 5000
                </p>
              </div>
            </div>

            {selectedCategory.value === "bug" && (
              <div className="rounded-lg border border-amber-200 bg-amber-50 p-4 dark:border-amber-800 dark:bg-amber-950/30">
                <p className="text-sm text-amber-800 dark:text-amber-200">
                  不具合を報告される際は、以下の情報をできるだけ含めてください：
                </p>
                <ul className="mt-2 space-y-1 text-sm text-amber-700 dark:text-amber-300">
                  <li>- 発生した画面のURL</li>
                  <li>- 操作の手順（再現手順）</li>
                  <li>- 期待する動作と実際の動作</li>
                </ul>
              </div>
            )}

            {selectedCategory.value === "security" && (
              <div className="rounded-lg border border-red-200 bg-red-50 p-4 dark:border-red-800 dark:bg-red-950/30">
                <p className="text-sm text-red-800 dark:text-red-200">
                  セキュリティに関するお問い合わせは最優先で対応いたします。
                  不正アクセスの疑いがある場合は、優先度「緊急」を選択してください。
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="flex justify-end gap-3">
          <Button variant="outline" type="button" onClick={handleReset}>
            キャンセル
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            {isSubmitting ? (
              <Loader2 className="mr-2 size-4 animate-spin" />
            ) : (
              <Send className="mr-2 size-4" />
            )}
            送信する
          </Button>
        </div>
      </form>
    </div>
  );
}
