"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Building2, Factory, Package, Users, Bell, CreditCard, AlertTriangle } from "lucide-react";

/** 設定ページのサブナビゲーション項目 */
const SETTINGS_ITEMS = [
  { label: "会社設定", href: "/settings/company", icon: Building2 },
  { label: "業種テンプレート", href: "/settings/industry", icon: Factory },
  { label: "品目マスタ", href: "/settings/products", icon: Package },
  { label: "ユーザー管理", href: "/settings/users", icon: Users },
  { label: "通知設定", href: "/settings/notifications", icon: Bell },
  { label: "督促設定", href: "/settings/dunning", icon: AlertTriangle },
  { label: "プラン・請求", href: "/settings/billing", icon: CreditCard },
];

/**
 * 設定ページ間のサブナビゲーション
 * @returns サブナビゲーション要素
 */
export function SettingsNav() {
  const pathname = usePathname();

  return (
    <nav className="flex gap-1 border-b pb-3 mb-4 sm:mb-8 overflow-x-auto -mx-1 px-1">
      {SETTINGS_ITEMS.map((item) => {
        const isActive = pathname.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center gap-1.5 sm:gap-2 rounded-md px-3 sm:px-4 py-2 text-[13px] sm:text-[14px] font-medium whitespace-nowrap transition-colors ${
              isActive
                ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:bg-muted hover:text-foreground"
            }`}
          >
            <item.icon className="size-3.5 sm:size-4 shrink-0" />
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
