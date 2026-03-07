# frozen_string_literal: true

# プラン制限超過エラー
#
# テナントのプランに設定されたリソース制限を超過した場合に発生する。
class PlanLimitExceededError < StandardError
end
