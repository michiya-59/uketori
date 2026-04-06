"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  BadgeJapaneseYen,
  Users,
  FolderKanban,
  FileText,
  CreditCard,
  Bell,
  Upload,
  BarChart3,
  Settings,
  LogOut,
  ShieldCheck,
  UserPlus,
  MessageSquarePlus,
  Sparkles,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarFooter,
  useSidebar,
} from "@/components/ui/sidebar";
import { Separator } from "@/components/ui/separator";
import { api } from "@/lib/api-client";
import { clearTokens } from "@/lib/auth";

/** サイドバーのナビゲーション項目の型定義 */
interface NavItem {
  /** 表示ラベル */
  label: string;
  /** 遷移先パス */
  href: string;
  /** lucide-react アイコンコンポーネント */
  icon: LucideIcon;
  /** 非活性フラグ（trueの場合クリック不可） */
  disabled?: boolean;
}

/** メインナビゲーション項目 */
const MAIN_NAV: NavItem[] = [
  { label: "ダッシュボード", href: "/dashboard", icon: LayoutDashboard },
  { label: "回収管理", href: "/collection", icon: BadgeJapaneseYen },
];

/** 業務ナビゲーション項目 */
const WORK_NAV: NavItem[] = [
  { label: "顧客", href: "/customers", icon: Users },
  { label: "案件", href: "/projects", icon: FolderKanban },
  { label: "帳票", href: "/documents", icon: FileText },
  { label: "入金", href: "/payments", icon: CreditCard },
  { label: "督促", href: "/dunning", icon: Bell },
];

/**
 * ツールナビゲーション項目を生成する
 * @param importEnabled - データ移行機能が有効か
 * @returns ツールナビゲーション項目の配列
 */
function getToolNav(importEnabled: boolean): NavItem[] {
  return [
    { label: "AI機能", href: "/ai", icon: Sparkles },
    { label: "データ移行", href: "/import", icon: Upload, disabled: !importEnabled },
    { label: "レポート", href: "/reports", icon: BarChart3 },
    { label: "設定", href: "/settings", icon: Settings },
  ];
}

/**
 * 指定されたパスが現在のパス名と一致するかを判定する
 * @param pathname - 現在のパス名
 * @param href - ナビゲーション項目のパス
 * @returns パスがアクティブであれば true
 */
function isActiveItem(pathname: string, href: string): boolean {
  if (href === "/dashboard") {
    return pathname === "/dashboard";
  }
  return pathname.startsWith(href);
}

/**
 * ナビゲーショングループをレンダリングするコンポーネント
 * @param items - ナビゲーション項目の配列
 * @param label - グループラベル
 * @param pathname - 現在のパス名
 * @returns ナビゲーショングループ要素
 */
function NavGroup({
  items,
  label,
  pathname,
}: {
  items: NavItem[];
  label: string;
  pathname: string;
}) {
  const { setOpenMobile } = useSidebar();

  return (
    <SidebarGroup>
      <SidebarGroupLabel className="text-xs font-semibold uppercase tracking-wider text-muted-foreground/70 px-3">
        {label}
      </SidebarGroupLabel>
      <SidebarGroupContent>
        <SidebarMenu>
          {items.map((item) => (
            <SidebarMenuItem key={item.href}>
              {item.disabled ? (
                <SidebarMenuButton
                  tooltip={`${item.label}（準備中）`}
                  className="h-10 text-[15px] opacity-40 pointer-events-none"
                >
                  <item.icon className="size-[18px]" />
                  <span>{item.label}</span>
                </SidebarMenuButton>
              ) : (
                <SidebarMenuButton
                  asChild
                  isActive={isActiveItem(pathname, item.href)}
                  tooltip={item.label}
                  className="h-10 text-[15px]"
                >
                  <Link href={item.href} onClick={() => setOpenMobile(false)}>
                    <item.icon className="size-[18px]" />
                    <span>{item.label}</span>
                  </Link>
                </SidebarMenuButton>
              )}
            </SidebarMenuItem>
          ))}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  );
}

/**
 * アプリケーションのサイドバーコンポーネント
 * ロゴとナビゲーションメニューを表示し、現在のページをハイライトする
 * @returns サイドバー要素
 */
export function AppSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [importEnabled, setImportEnabled] = useState(false);
  const [isSystemAdmin, setIsSystemAdmin] = useState(false);

  /**
   * テナント情報を取得し機能フラグを設定する
   */
  const fetchFeatureFlags = useCallback(async () => {
    try {
      const res = await api.get<{ tenant: { import_enabled: boolean } }>("/api/v1/tenant");
      setImportEnabled(res.tenant.import_enabled);
    } catch {
      // 取得失敗時はデフォルト（無効）のまま
    }
  }, []);

  /**
   * システム管理者かどうかを確認する
   */
  const checkAdmin = useCallback(async () => {
    try {
      await api.get<{ admin: boolean }>("/api/v1/admin/me");
      setIsSystemAdmin(true);
    } catch {
      // 管理者でない場合は403が返る
    }
  }, []);

  useEffect(() => {
    fetchFeatureFlags();
    checkAdmin();
  }, [fetchFeatureFlags, checkAdmin]);

  /**
   * ログアウト処理を実行しログインページへ遷移する
   */
  const handleSignOut = async () => {
    try {
      await api.delete("/api/v1/auth/sign_out");
    } catch {
      // サインアウトAPIが失敗してもトークンをクリアしてリダイレクト
    }
    clearTokens();
    router.push("/login");
  };

  const toolNav = getToolNav(importEnabled);

  return (
    <Sidebar>
      <SidebarHeader className="px-5 py-5">
        <Link href="/dashboard" className="flex items-center gap-3">
          <div className="flex size-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
            <BadgeJapaneseYen className="size-5" />
          </div>
          <span className="text-lg font-bold tracking-tight">ウケトリ</span>
        </Link>
      </SidebarHeader>
      <Separator />
      <SidebarContent className="pt-2">
        <NavGroup items={MAIN_NAV} label="概要" pathname={pathname} />
        <NavGroup items={WORK_NAV} label="業務" pathname={pathname} />
        <NavGroup items={toolNav} label="ツール" pathname={pathname} />
        {isSystemAdmin && (
          <NavGroup
            items={[
              { label: "アカウント発行", href: "/admin/accounts", icon: UserPlus },
              { label: "テナント管理", href: "/admin/tenants", icon: ShieldCheck },
            ]}
            label="管理者"
            pathname={pathname}
          />
        )}
      </SidebarContent>
      <SidebarFooter className="px-3 py-3">
        <Separator className="mb-3" />
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              asChild
              isActive={isActiveItem(pathname, "/contact")}
              tooltip="お問い合わせ"
              className="h-10 text-[15px]"
            >
              <Link href="/contact" onClick={() => { }}>
                <MessageSquarePlus className="size-[18px]" />
                <span>お問い合わせ</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
          <SidebarMenuItem>
            <SidebarMenuButton
              className="h-10 text-[15px] text-muted-foreground hover:text-destructive"
              onClick={handleSignOut}
            >
              <LogOut className="size-[18px]" />
              <span>ログアウト</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}
