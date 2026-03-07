"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/**
 * ルートページ
 * ダッシュボードへリダイレクトする
 */
export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/dashboard");
  }, [router]);

  return null;
}
