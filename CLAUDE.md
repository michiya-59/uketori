# 開発ルール

## バックエンド (Ruby on Rails)

### コメント規約
- すべてのメソッドに YARD コメントを記述すること
  ```ruby
  # @param name [String] ユーザー名
  # @return [User] 作成されたユーザーオブジェクト
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def create_user(name)
    ...
  end
  ```

### RSpec 規約
- `describe` はメソッド単位で記述する（クラスメソッドは `.method_name`、インスタンスメソッドは `#method_name`）
- `context` と `it` は日本語で記述する
- `let` は必ず `let!` を使用する
  ```ruby
  describe '#create_user' do
    let!(:user) { create(:user) }

    context 'ユーザー名が有効な場合' do
      it 'ユーザーが作成されること' do
        ...
      end
    end

    context 'ユーザー名が空の場合' do
      it 'バリデーションエラーになること' do
        ...
      end
    end
  end
  ```

## フロントエンド (Next.js)

### コメント規約
- すべての関数・コンポーネントに JSDoc コメントを記述すること
  ```typescript
  /**
   * ユーザー情報を取得する
   * @param userId - ユーザーID
   * @returns ユーザーオブジェクト
   * @throws ユーザーが見つからない場合
   */
  const fetchUser = async (userId: string): Promise<User> => {
    ...
  }
  ```
