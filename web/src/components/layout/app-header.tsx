"use client";

import { useEffect, useState, useCallback } from "react";
import { usePathname } from "next/navigation";
import { Bell, Check } from "lucide-react";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { api } from "@/lib/api-client";
import { Separator } from "@/components/ui/separator";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbList,
  BreadcrumbPage,
} from "@/components/ui/breadcrumb";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import type { Notification, NotificationsResponse, NotificationUpdateResponse } from "@/types";

/** パス名からパンくずラベルを返す */
const BREADCRUMB_MAP: Record<string, string> = {
  "/dashboard": "ダッシュボード",
  "/customers": "顧客",
  "/projects": "案件",
  "/documents": "帳票",
  "/payments": "入金",
  "/dunning": "督促",
  "/collection": "回収管理",
  "/import": "データ移行",
  "/reports": "レポート",
  "/settings": "設定",
};

/**
 * パスからパンくずラベルを取得する
 * @param pathname - 現在のパス
 * @returns ラベル文字列
 */
function getBreadcrumbLabel(pathname: string): string {
  for (const [path, label] of Object.entries(BREADCRUMB_MAP)) {
    if (pathname.startsWith(path)) return label;
  }
  return "ダッシュボード";
}

/**
 * アプリケーションのヘッダーコンポーネント
 * サイドバートグル、パンくずリスト、通知ベル、ユーザーアバタードロップダウンを表示する
 * @returns ヘッダー要素
 */
export function AppHeader() {
  const pathname = usePathname();

  return (
    <header className="flex h-16 shrink-0 items-center gap-3 border-b bg-card px-5">
      <SidebarTrigger className="-ml-1 size-10 [&>svg]:size-5" />
      <Separator orientation="vertical" className="mr-1 h-5" />
      <Breadcrumb className="flex-1">
        <BreadcrumbList>
          <BreadcrumbItem>
            <BreadcrumbPage className="text-[15px]">{getBreadcrumbLabel(pathname)}</BreadcrumbPage>
          </BreadcrumbItem>
        </BreadcrumbList>
      </Breadcrumb>
      <div className="flex items-center gap-1">
        <NotificationBell />
      </div>
    </header>
  );
}

/**
 * 通知ベルアイコンコンポーネント
 * APIから未読通知件数を取得し、クリックでドロップダウン一覧を表示する
 * @returns 通知ベルアイコン要素
 */
function NotificationBell() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [open, setOpen] = useState(false);

  const fetchNotifications = useCallback(async () => {
    try {
      const res = await api.get<NotificationsResponse>("/api/v1/notifications", { per_page: 10 });
      setNotifications(res.notifications);
      setUnreadCount(res.unread_count);
    } catch {
      // 通知取得失敗時は静かに無視
    }
  }, []);

  useEffect(() => {
    void fetchNotifications();
    const interval = setInterval(() => void fetchNotifications(), 60000);
    return () => clearInterval(interval);
  }, [fetchNotifications]);

  /**
   * 通知を既読にする
   * @param id - 通知ID
   */
  const markAsRead = async (id: number) => {
    try {
      const res = await api.patch<NotificationUpdateResponse>(`/api/v1/notifications/${id}`);
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? res.notification : n))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));
    } catch {
      // 静かに無視
    }
  };

  /**
   * 経過時間を日本語で返す
   * @param dateStr - ISO日時文字列
   * @returns 日本語の経過表記
   */
  const timeAgo = (dateStr: string): string => {
    const diff = Date.now() - new Date(dateStr).getTime();
    const minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "たった今";
    if (minutes < 60) return `${minutes}分前`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}時間前`;
    const days = Math.floor(hours / 24);
    return `${days}日前`;
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <PopoverTrigger asChild>
              <Button variant="ghost" size="icon" className="relative size-9">
                <Bell className="size-[18px]" />
                {unreadCount > 0 && (
                  <Badge
                    variant="destructive"
                    className="absolute -top-0.5 -right-0.5 flex size-[18px] items-center justify-center p-0 text-[10px] font-bold"
                  >
                    {unreadCount > 9 ? "9+" : unreadCount}
                  </Badge>
                )}
                <span className="sr-only">通知</span>
              </Button>
            </PopoverTrigger>
          </TooltipTrigger>
          <TooltipContent>通知</TooltipContent>
        </Tooltip>
      </TooltipProvider>
      <PopoverContent align="end" className="w-80 p-0">
        <div className="flex items-center justify-between border-b px-4 py-3">
          <p className="text-sm font-semibold">通知</p>
          {unreadCount > 0 && (
            <Badge variant="secondary" className="text-xs">{unreadCount}件未読</Badge>
          )}
        </div>
        <div className="max-h-80 overflow-y-auto">
          {notifications.length > 0 ? (
            notifications.map((n) => (
              <div
                key={n.id}
                className={`flex items-start gap-3 border-b px-4 py-3 last:border-0 ${
                  n.is_read ? "opacity-60" : "bg-accent/30"
                }`}
              >
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium leading-tight">{n.title}</p>
                  {n.body != null && (
                    <p className="mt-0.5 text-xs text-muted-foreground line-clamp-2">{n.body}</p>
                  )}
                  <p className="mt-1 text-xs text-muted-foreground">{timeAgo(n.created_at)}</p>
                </div>
                {!n.is_read && (
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-7 shrink-0"
                    onClick={() => void markAsRead(n.id)}
                  >
                    <Check className="size-3.5" />
                  </Button>
                )}
              </div>
            ))
          ) : (
            <div className="py-8 text-center text-sm text-muted-foreground">
              通知はありません
            </div>
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}

