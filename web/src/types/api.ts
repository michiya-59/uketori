/** ページネーションメタ情報 */
export interface PaginationMeta {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

/** ページネーション付きレスポンス */
export interface PaginatedResponse<T> {
  data: T[]
  meta: PaginationMeta
}

/** APIエラー詳細 */
export interface ApiErrorDetail {
  field: string
  message: string
}

/** APIエラーレスポンス */
export interface ApiError {
  error: {
    code: string
    message: string
    details?: ApiErrorDetail[]
  }
}

/** フィルタパラメータ */
export type FilterParams = Record<string, string | number | boolean | undefined>

/** ソート順序 */
export type SortOrder = 'asc' | 'desc'

/** リストクエリパラメータ */
export interface ListParams {
  page?: number
  per_page?: number
  sort?: string
  order?: SortOrder
  filter?: FilterParams
}
