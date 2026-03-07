# ユーザーテーブルを作成するマイグレーション
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.column :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.references :tenant, null: false, foreign_key: true
      t.column :email, :string, limit: 255, null: false
      t.column :password_digest, :string, limit: 255, null: false
      t.column :name, :string, limit: 100, null: false
      t.column :role, :string, limit: 20, null: false, default: "member"
      t.column :avatar_url, :string, limit: 500
      t.column :last_sign_in_at, :datetime
      t.column :sign_in_count, :integer, null: false, default: 0
      t.column :invitation_token, :string, limit: 100
      t.column :invitation_sent_at, :datetime
      t.column :invitation_accepted_at, :datetime
      t.column :password_reset_token, :string, limit: 100
      t.column :password_reset_sent_at, :datetime
      t.column :two_factor_enabled, :boolean, null: false, default: false
      t.column :otp_secret, :string, limit: 100
      t.column :jti, :string, null: false

      t.timestamps
      t.column :deleted_at, :datetime

      t.index :uuid, unique: true
      t.index [:tenant_id, :email], unique: true, where: "deleted_at IS NULL"
      t.index :invitation_token, unique: true
      t.index :jti, unique: true
    end
  end
end
