"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { isAuthenticated } from "@/lib/auth";

/** 認証不要のパス */
const PUBLIC_PATHS = ["/login", "/signup", "/password/reset", "/invitation/accept"];

/**
 * 認証状態に応じてリダイレクトを行うガードコンポーネント
 *
 * - 未認証で保護ルートにアクセス → /login にリダイレクト
 * - 認証済みで認証ページにアクセス → /dashboard にリダイレクト
 *
 * @param children - 子コンポーネント
 * @returns 認証チェック済みの場合は子コンポーネント、チェック中はnull
 */
export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    const authenticated = isAuthenticated();
    const isPublicPath = PUBLIC_PATHS.some((p) => pathname.startsWith(p));

    if (!authenticated && !isPublicPath) {
      router.replace("/login");
      return;
    }

    if (authenticated && isPublicPath) {
      router.replace("/dashboard");
      return;
    }

    setChecked(true);
  }, [pathname, router]);

  if (!checked) {
    return null;
  }

  return <>{children}</>;
}
