# frozen_string_literal: true

# すべてのモデルの基底クラス
#
# アプリケーション全体で共通の設定やメソッドを定義する。
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
