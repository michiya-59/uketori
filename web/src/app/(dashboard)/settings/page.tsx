"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/**
 * 設定ページのルート
 * /settings/company にリダイレクトする
 */
export default function SettingsPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/settings/company");
  }, [router]);

  return null;
}
