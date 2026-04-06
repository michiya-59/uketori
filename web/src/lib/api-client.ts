import type { ApiError } from '@/types/api'
import { getToken, getRefreshToken, setTokens, clearTokens } from '@/lib/auth'

/** API通信時に発生するエラー */
export class ApiClientError extends Error {
  /** HTTPステータスコード */
  public readonly status: number
  /** APIエラーレスポンスのボディ */
  public readonly body: ApiError | null

  /**
   * ApiClientErrorを生成する
   * @param message - エラーメッセージ
   * @param status - HTTPステータスコード
   * @param body - APIエラーレスポンスのボディ（パース可能な場合）
   */
  constructor(message: string, status: number, body: ApiError | null) {
    super(message)
    this.name = 'ApiClientError'
    this.status = status
    this.body = body
  }
}

/**
 * バックエンドAPIと通信するHTTPクライアント
 *
 * JWTトークンを自動的にAuthorizationヘッダーに付与し、
 * 401レスポンス時にはリフレッシュトークンによる自動更新を試みる。
 * リフレッシュにも失敗した場合は /login にリダイレクトする。
 */
class ApiClient {
  private readonly baseUrl: string
  private isRefreshing: boolean = false
  private refreshPromise: Promise<boolean> | null = null

  /**
   * ApiClientを初期化する
   * @param baseUrl - APIのベースURL（デフォルト: NEXT_PUBLIC_API_URL環境変数）
   */
  constructor(baseUrl?: string) {
    this.baseUrl = baseUrl ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4100'
  }

  /**
   * リクエスト用の共通ヘッダーを生成する
   * @param contentType - Content-Typeヘッダーの値（nullの場合は設定しない）
   * @returns ヘッダーオブジェクト
   */
  private buildHeaders(contentType: string | null = 'application/json'): HeadersInit {
    const headers: Record<string, string> = {
      Accept: 'application/json',
    }

    if (contentType !== null) {
      headers['Content-Type'] = contentType
    }

    const token = getToken()
    if (token) {
      headers['Authorization'] = `Bearer ${token}`
    }

    return headers
  }

  /**
   * クエリパラメータオブジェクトをURLSearchParams文字列に変換する
   * @param params - クエリパラメータオブジェクト
   * @returns URLエンコードされたクエリ文字列（?を含む）、パラメータが無い場合は空文字列
   */
  private buildQuery(params?: Record<string, string | number | boolean | undefined>): string {
    if (!params) return ''

    const searchParams = new URLSearchParams()
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined) {
        searchParams.append(key, String(value))
      }
    }

    const queryString = searchParams.toString()
    return queryString ? `?${queryString}` : ''
  }

  /**
   * レスポンスのエラーハンドリングを行う
   * @param response - fetchのレスポンスオブジェクト
   * @throws ApiClientError レスポンスがOKでない場合
   */
  private async handleErrorResponse(response: Response): Promise<void> {
    let body: ApiError | null = null
    try {
      body = (await response.json()) as ApiError
    } catch {
      // JSONパースに失敗した場合はbodyをnullのまま返す
    }

    throw new ApiClientError(
      body?.error?.message ?? `API error: ${response.status} ${response.statusText}`,
      response.status,
      body
    )
  }

  /**
   * リフレッシュトークンを使用してアクセストークンを更新する
   * @returns トークンの更新に成功した場合はtrue、失敗した場合はfalse
   */
  private async refreshAccessToken(): Promise<boolean> {
    const refreshToken = getRefreshToken()
    if (!refreshToken) return false

    try {
      const response = await fetch(`${this.baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      })

      if (!response.ok) return false

      const data = (await response.json()) as { tokens: { access_token: string; refresh_token: string } }
      setTokens(data.tokens.access_token, data.tokens.refresh_token)
      return true
    } catch {
      return false
    }
  }

  /**
   * 401レスポンス時にトークンリフレッシュを試み、リクエストをリトライする
   *
   * 複数のリクエストが同時に401を受けた場合、リフレッシュは1回だけ実行し、
   * 他のリクエストはその結果を待つ。
   *
   * @param requestFn - リトライ対象のリクエストを実行する関数
   * @returns リトライしたレスポンス
   * @throws リフレッシュ失敗時は /login にリダイレクトする
   */
  private async handleUnauthorized<T>(requestFn: () => Promise<T>): Promise<T> {
    if (!this.isRefreshing) {
      this.isRefreshing = true
      this.refreshPromise = this.refreshAccessToken().finally(() => {
        this.isRefreshing = false
      })
    }

    const refreshed = await this.refreshPromise
    if (refreshed) {
      return requestFn()
    }

    clearTokens()
    if (typeof window !== 'undefined') {
      window.location.href = '/login'
    }
    throw new ApiClientError('Authentication failed. Redirecting to login.', 401, null)
  }

  /**
   * fetchリクエストを実行し、401時のリトライを含むレスポンス処理を行う
   * @param url - リクエスト先の完全なURL
   * @param options - fetchオプション
   * @returns パースされたレスポンスボディ
   * @throws ApiClientError リクエスト失敗時
   */
  private async request<T>(url: string, options: RequestInit): Promise<T> {
    const response = await fetch(url, options)

    if (response.status === 401) {
      return this.handleUnauthorized<T>(() => this.request<T>(url, {
        ...options,
        headers: this.buildHeaders(
          options.body instanceof FormData ? null : 'application/json'
        ),
      }))
    }

    // IP制限エラー: ログイン済みセッションの場合のみ強制ログアウト
    if (response.status === 403) {
      let body: ApiError | null = null
      try {
        body = (await response.json()) as ApiError
      } catch {
        // JSONパース失敗時はnull
      }

      if (body?.error?.code === 'ip_restricted') {
        // トークンがある = ログイン済みセッション中にIPが変わった場合のみ強制リダイレクト
        // トークンがない = ログイン試行時なので、呼び出し元（ログインページ）に処理を委譲する
        if (getToken()) {
          clearTokens()
          if (typeof window !== 'undefined') {
            sessionStorage.setItem('ip_restricted', '1')
            window.location.href = '/login'
          }
        }
        throw new ApiClientError(
          body.error.message ?? '許可されていないIPアドレスからのアクセスです',
          403,
          body
        )
      }
    }

    if (!response.ok) {
      await this.handleErrorResponse(response)
    }

    if (response.status === 204) {
      return undefined as T
    }

    return (await response.json()) as T
  }

  /**
   * GETリクエストを送信する
   * @param path - APIエンドポイントのパス（例: "/api/v1/customers"）
   * @param params - クエリパラメータ
   * @returns APIレスポンスのボディ
   * @throws ApiClientError リクエスト失敗時
   */
  async get<T>(path: string, params?: Record<string, string | number | boolean | undefined>): Promise<T> {
    const url = `${this.baseUrl}${path}${this.buildQuery(params)}`
    return this.request<T>(url, {
      method: 'GET',
      headers: this.buildHeaders(),
    })
  }

  /**
   * POSTリクエストを送信する
   * @param path - APIエンドポイントのパス
   * @param body - リクエストボディ
   * @returns APIレスポンスのボディ
   * @throws ApiClientError リクエスト失敗時
   */
  async post<T>(path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`
    return this.request<T>(url, {
      method: 'POST',
      headers: this.buildHeaders(),
      body: body !== undefined ? JSON.stringify(body) : undefined,
    })
  }

  /**
   * PATCHリクエストを送信する
   * @param path - APIエンドポイントのパス
   * @param body - リクエストボディ
   * @returns APIレスポンスのボディ
   * @throws ApiClientError リクエスト失敗時
   */
  async patch<T>(path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`
    return this.request<T>(url, {
      method: 'PATCH',
      headers: this.buildHeaders(),
      body: body !== undefined ? JSON.stringify(body) : undefined,
    })
  }

  /**
   * DELETEリクエストを送信する
   * @param path - APIエンドポイントのパス
   * @throws ApiClientError リクエスト失敗時
   */
  async delete(path: string): Promise<void> {
    const url = `${this.baseUrl}${path}`
    return this.request<void>(url, {
      method: 'DELETE',
      headers: this.buildHeaders(),
    })
  }

  /**
   * FormDataを使用したファイルアップロードリクエストを送信する
   *
   * Content-Typeヘッダーは自動設定（boundary付きmultipart/form-data）されるため、
   * 手動で設定しない。
   *
   * @param path - APIエンドポイントのパス
   * @param formData - アップロードするFormDataオブジェクト
   * @returns APIレスポンスのボディ
   * @throws ApiClientError リクエスト失敗時
   */
  async upload<T>(path: string, formData: FormData): Promise<T> {
    const url = `${this.baseUrl}${path}`
    return this.request<T>(url, {
      method: 'POST',
      headers: this.buildHeaders(null),
      body: formData,
    })
  }

  /**
   * FormDataを使用したPATCHリクエストを送信する
   *
   * 既存リソースの更新時にファイルアップロードが必要な場合に使用する。
   * Content-Typeヘッダーは自動設定（boundary付きmultipart/form-data）されるため、
   * 手動で設定しない。
   *
   * @param path - APIエンドポイントのパス
   * @param formData - アップロードするFormDataオブジェクト
   * @returns APIレスポンスのボディ
   * @throws ApiClientError リクエスト失敗時
   */
  async patchUpload<T>(path: string, formData: FormData): Promise<T> {
    const url = `${this.baseUrl}${path}`
    return this.request<T>(url, {
      method: 'PATCH',
      headers: this.buildHeaders(null),
      body: formData,
    })
  }
}

/** シングルトンのAPIクライアントインスタンス */
export const api = new ApiClient()
