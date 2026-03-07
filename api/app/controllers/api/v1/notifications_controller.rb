# frozen_string_literal: true

module Api
  module V1
    # 通知コントローラー
    #
    # ユーザーへの通知一覧取得と既読更新を提供する。
    class NotificationsController < BaseController
      # 通知一覧を返す
      #
      # @return [void]
      def index
        notifications = policy_scope(Notification)
                        .recent
                        .page(page_param).per(per_page_param)

        render json: {
          notifications: notifications.map { |n| serialize_notification(n) },
          unread_count: policy_scope(Notification).unread.count,
          meta: pagination_meta(notifications)
        }
      end

      # 通知を既読にする
      #
      # @return [void]
      def update
        notification = policy_scope(Notification).find(params[:id])
        authorize notification

        notification.mark_as_read!

        render json: { notification: serialize_notification(notification) }
      end

      private

      # 通知をシリアライズする
      #
      # @param notification [Notification]
      # @return [Hash]
      def serialize_notification(notification)
        {
          id: notification.id,
          notification_type: notification.notification_type,
          title: notification.title,
          body: notification.body,
          data: notification.data,
          is_read: notification.is_read,
          read_at: notification.read_at,
          created_at: notification.created_at
        }
      end
    end
  end
end
