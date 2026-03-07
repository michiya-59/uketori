const TOKEN_KEY = 'uketori_token'
const REFRESH_TOKEN_KEY = 'uketori_refresh_token'
const USER_KEY = 'uketori_user'

/** localStorage保存用のユーザー情報 */
export interface StoredUser {
  name: string
  email: string
  role: string
}

/**
 * localStorageからJWTアクセストークンを取得する
 * @returns JWTトークン文字列、未認証の場合はnull
 */
export const getToken = (): string | null => {
  if (typeof window === 'undefined') return null
  return localStorage.getItem(TOKEN_KEY)
}

/**
 * localStorageからリフレッシュトークンを取得する
 * @returns リフレッシュトークン文字列、未認証の場合はnull
 */
export const getRefreshToken = (): string | null => {
  if (typeof window === 'undefined') return null
  return localStorage.getItem(REFRESH_TOKEN_KEY)
}

/**
 * JWTアクセストークンとリフレッシュトークンをlocalStorageに保存する
 * @param token - JWTアクセストークン
 * @param refreshToken - リフレッシュトークン
 */
export const setTokens = (token: string, refreshToken: string): void => {
  if (typeof window === 'undefined') return
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken)
}

/**
 * localStorageから全トークンとユーザー情報を削除する
 */
export const clearTokens = (): void => {
  if (typeof window === 'undefined') return
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(REFRESH_TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}

/**
 * ユーザー情報をlocalStorageに保存する
 * @param user - 保存するユーザー情報
 */
export const setStoredUser = (user: StoredUser): void => {
  if (typeof window === 'undefined') return
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

/**
 * localStorageからユーザー情報を取得する
 * @returns ユーザー情報、未保存の場合はnull
 */
export const getStoredUser = (): StoredUser | null => {
  if (typeof window === 'undefined') return null
  const raw = localStorage.getItem(USER_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as StoredUser
  } catch {
    return null
  }
}

/**
 * ユーザーが認証済みかどうかを判定する
 * @returns アクセストークンが存在する場合はtrue
 */
export const isAuthenticated = (): boolean => {
  return getToken() !== null
}
