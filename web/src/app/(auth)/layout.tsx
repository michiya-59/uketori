import { BadgeJapaneseYen } from "lucide-react";

/**
 * 認証ページ用レイアウト
 * ログイン・新規登録などの認証関連ページで使用される中央寄せレイアウト
 * 左側にブランドビジュアル、右側にフォームを配置するスプリットレイアウト
 * @param children - 子コンポーネント
 * @returns 認証ページ用レイアウト要素
 */
export default function AuthLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <div className="flex min-h-svh">
      <div className="hidden lg:flex lg:w-1/2 flex-col justify-between bg-primary p-12 text-primary-foreground">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-xl bg-white/15 backdrop-blur-sm">
            <BadgeJapaneseYen className="size-6" />
          </div>
          <span className="text-xl font-bold tracking-tight">ウケトリ</span>
        </div>
        <div className="space-y-6">
          <h2 className="text-4xl font-bold leading-tight tracking-tight">
            見積から入金まで、
            <br />
            ぜんぶウケトリ。
          </h2>
          <p className="text-lg leading-relaxed text-white/75">
            AI搭載の請求・入金回収管理で、
            <br />
            経理業務をもっとスマートに。
          </p>
        </div>
        <p className="text-sm text-white/50">
          &copy; 2026 ウケトリ All rights reserved.
        </p>
      </div>
      <div className="flex w-full lg:w-1/2 items-center justify-center px-6 py-12">
        <div className="w-full max-w-[440px]">
          <div className="mb-10 lg:hidden text-center">
            <div className="mb-4 flex items-center justify-center gap-3">
              <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
                <BadgeJapaneseYen className="size-6" />
              </div>
              <span className="text-2xl font-bold tracking-tight">ウケトリ</span>
            </div>
            <p className="text-[15px] text-muted-foreground">
              見積から入金まで、ぜんぶウケトリ。
            </p>
          </div>
          {children}
        </div>
      </div>
    </div>
  );
}
