import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/** 認証不要のパス */
const PUBLIC_PATHS = ["/login", "/signup", "/password/reset", "/invitation/accept"];

/**
 * リクエストの認証チェックを行うミドルウェア
 *
 * クライアントサイドのlocalStorageトークンはサーバーサイドで確認できないため、
 * ここではcookieベースのチェックは行わず、レイアウト側でリダイレクトする。
 * ミドルウェアではパスベースの基本的なルーティング制御のみ行う。
 *
 * @param request - 受信リクエスト
 * @returns レスポンスまたはnext()
 */
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // APIや静的ファイルはスキップ
  if (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.includes(".")
  ) {
    return NextResponse.next();
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
