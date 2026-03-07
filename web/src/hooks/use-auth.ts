"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { api, ApiClientError } from "@/lib/api-client";
import {
  getToken,
  setTokens,
  clearTokens,
  isAuthenticated,
  setStoredUser,
  getStoredUser,
} from "@/lib/auth";
import type {
  User,
  SignInResponse,
  SignUpResponse,
  SignUpRequest,
} from "@/types/user";

/** 認証状態 */
interface AuthState {
  user: User | null;
  loading: boolean;
  authenticated: boolean;
}

/**
 * 認証フック
 * ログイン/登録/ログアウト/状態管理を提供する
 * @returns 認証状態とアクションメソッド
 */
export function useAuth() {
  const router = useRouter();
  const [state, setState] = useState<AuthState>({
    user: null,
    loading: true,
    authenticated: false,
  });

  /**
   * 現在のユーザー情報をAPIから取得する
   */
  const fetchCurrentUser = useCallback(async () => {
    if (!isAuthenticated()) {
      setState({ user: null, loading: false, authenticated: false });
      return;
    }

    try {
      const result = await api.get<{ tenant: Record<string, unknown> }>(
        "/api/v1/tenant"
      );
      // テナントAPI経由でユーザーが認証済みであることを確認
      if (result.tenant) {
        const stored = getStoredUser();
        const user: User | null = stored
          ? { id: "", name: stored.name, email: stored.email, role: stored.role as User["role"] }
          : null;
        setState({ user, loading: false, authenticated: true });
      }
    } catch {
      clearTokens();
      setState({ user: null, loading: false, authenticated: false });
    }
  }, []);

  useEffect(() => {
    fetchCurrentUser();
  }, [fetchCurrentUser]);

  /**
   * メールアドレスとパスワードでログインする
   * @param email - メールアドレス
   * @param password - パスワード
   * @throws ApiClientError 認証失敗時
   */
  const login = useCallback(
    async (email: string, password: string) => {
      const result = await api.post<SignInResponse>("/api/v1/auth/sign_in", {
        auth: { email, password },
      });
      setTokens(result.tokens.access_token, result.tokens.refresh_token);
      setStoredUser({ name: result.user.name, email: result.user.email, role: result.user.role });
      setState({
        user: result.user,
        loading: false,
        authenticated: true,
      });
      router.push("/dashboard");
    },
    [router]
  );

  /**
   * 新規登録する
   * @param params - 登録情報
   * @throws ApiClientError バリデーションエラー時
   */
  const signUp = useCallback(
    async (params: SignUpRequest["auth"]) => {
      const result = await api.post<SignUpResponse>("/api/v1/auth/sign_up", {
        auth: params,
      });
      setTokens(result.tokens.access_token, result.tokens.refresh_token);
      setStoredUser({ name: result.user.name, email: result.user.email, role: result.user.role });
      setState({
        user: result.user,
        loading: false,
        authenticated: true,
      });
      router.push("/dashboard");
    },
    [router]
  );

  /**
   * ログアウトする
   */
  const logout = useCallback(async () => {
    try {
      await api.delete("/api/v1/auth/sign_out");
    } catch {
      // サインアウトAPIが失敗してもトークンはクリアする
    }
    clearTokens();
    setState({ user: null, loading: false, authenticated: false });
    router.push("/login");
  }, [router]);

  /**
   * パスワードリセットメールを送信する
   * @param email - メールアドレス
   */
  const requestPasswordReset = useCallback(async (email: string) => {
    await api.post("/api/v1/auth/password/reset", {
      auth: { email },
    });
  }, []);

  /**
   * パスワードをリセットする
   * @param token - リセットトークン
   * @param password - 新しいパスワード
   * @param passwordConfirmation - パスワード確認
   */
  const resetPassword = useCallback(
    async (
      token: string,
      password: string,
      passwordConfirmation: string
    ) => {
      await api.patch("/api/v1/auth/password/update", {
        auth: {
          reset_token: token,
          password,
          password_confirmation: passwordConfirmation,
        },
      });
    },
    []
  );

  return {
    ...state,
    login,
    signUp,
    logout,
    requestPasswordReset,
    resetPassword,
  };
}
