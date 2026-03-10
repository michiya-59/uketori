"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/**
 * 管理者ページのリダイレクト
 * /admin にアクセスした場合、テナント一覧へリダイレクトする
 * @returns null
 */
export default function AdminPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/admin/tenants");
  }, [router]);

  return null;
}
