/** 通知 */
export interface Notification {
  id: number;
  notification_type: string;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

/** 通知一覧レスポンス */
export interface NotificationsResponse {
  notifications: Notification[];
  unread_count: number;
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

/** 通知更新レスポンス */
export interface NotificationUpdateResponse {
  notification: Notification;
}
