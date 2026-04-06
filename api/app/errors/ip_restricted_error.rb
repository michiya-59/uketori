# frozen_string_literal: true

# IP制限エラー
#
# テナントのIP制限設定により、リクエスト元IPが許可リストに含まれない場合に発生する。
class IpRestrictedError < StandardError
end
