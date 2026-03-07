import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { Toaster } from "@/components/ui/sonner";
import { AuthGuard } from "@/components/auth/auth-guard";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

/**
 * アプリケーション全体のメタデータ定義
 */
export const metadata: Metadata = {
  title: "ウケトリ",
  description: "見積から入金まで、ぜんぶウケトリ。",
};

/**
 * アプリケーションのルートレイアウト
 * @param children - 子コンポーネント
 * @returns ルートレイアウト要素
 */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className={`${inter.variable} antialiased font-sans`}>
        <AuthGuard>{children}</AuthGuard>
        <Toaster />
      </body>
    </html>
  );
}
