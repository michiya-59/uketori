class CreateCreditScoreHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_score_histories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :customers }
      t.integer :score, null: false
      t.jsonb :factors, null: false, default: "{}"
      t.datetime :calculated_at, null: false
    end
  end
end
