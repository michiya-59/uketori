"use client";

import { useEffect, useRef } from "react";
import type { UseFormSetValue } from "react-hook-form";
import { api } from "@/lib/api-client";

/**
 * ひらがなを全角カタカナに変換する
 * @param str - 入力文字列
 * @returns カタカナに変換された文字列
 */
const hiraganaToKatakana = (str: string): string =>
  str.replace(/[\u3041-\u3096]/g, (ch) =>
    String.fromCharCode(ch.charCodeAt(0) + 0x60)
  );

/**
 * 半角カタカナを全角カタカナに変換する
 * @param str - 入力文字列
 * @returns 全角カタカナに変換された文字列
 */
const halfToFullKatakana = (str: string): string => {
  const map: Record<string, string> = {
    "ｶﾞ": "ガ", "ｷﾞ": "ギ", "ｸﾞ": "グ", "ｹﾞ": "ゲ", "ｺﾞ": "ゴ",
    "ｻﾞ": "ザ", "ｼﾞ": "ジ", "ｽﾞ": "ズ", "ｾﾞ": "ゼ", "ｿﾞ": "ゾ",
    "ﾀﾞ": "ダ", "ﾁﾞ": "ヂ", "ﾂﾞ": "ヅ", "ﾃﾞ": "デ", "ﾄﾞ": "ド",
    "ﾊﾞ": "バ", "ﾋﾞ": "ビ", "ﾌﾞ": "ブ", "ﾍﾞ": "ベ", "ﾎﾞ": "ボ",
    "ﾊﾟ": "パ", "ﾋﾟ": "ピ", "ﾌﾟ": "プ", "ﾍﾟ": "ペ", "ﾎﾟ": "ポ",
    "ｱ": "ア", "ｲ": "イ", "ｳ": "ウ", "ｴ": "エ", "ｵ": "オ",
    "ｶ": "カ", "ｷ": "キ", "ｸ": "ク", "ｹ": "ケ", "ｺ": "コ",
    "ｻ": "サ", "ｼ": "シ", "ｽ": "ス", "ｾ": "セ", "ｿ": "ソ",
    "ﾀ": "タ", "ﾁ": "チ", "ﾂ": "ツ", "ﾃ": "テ", "ﾄ": "ト",
    "ﾅ": "ナ", "ﾆ": "ニ", "ﾇ": "ヌ", "ﾈ": "ネ", "ﾉ": "ノ",
    "ﾊ": "ハ", "ﾋ": "ヒ", "ﾌ": "フ", "ﾍ": "ヘ", "ﾎ": "ホ",
    "ﾏ": "マ", "ﾐ": "ミ", "ﾑ": "ム", "ﾒ": "メ", "ﾓ": "モ",
    "ﾔ": "ヤ", "ﾕ": "ユ", "ﾖ": "ヨ",
    "ﾗ": "ラ", "ﾘ": "リ", "ﾙ": "ル", "ﾚ": "レ", "ﾛ": "ロ",
    "ﾜ": "ワ", "ｦ": "ヲ", "ﾝ": "ン",
    "ｧ": "ァ", "ｨ": "ィ", "ｩ": "ゥ", "ｪ": "ェ", "ｫ": "ォ",
    "ｯ": "ッ", "ｬ": "ャ", "ｭ": "ュ", "ｮ": "ョ", "ｰ": "ー",
  };
  let result = str;
  // 濁音・半濁音（2文字）を先に変換
  for (const [from, to] of Object.entries(map)) {
    if (from.length === 2) result = result.replaceAll(from, to);
  }
  for (const [from, to] of Object.entries(map)) {
    if (from.length === 1) result = result.replaceAll(from, to);
  }
  return result;
};

/** 全角カタカナのみで構成されているか判定する正規表現 */
const KATAKANA_ONLY = /^[ァ-ヶー　\s]+$/;

/** ひらがな・カタカナのみで構成されているか（API不要） */
const KANA_ONLY = /^[\u3040-\u309F\u30A0-\u30FFー　\s]+$/;

/**
 * テキストをクライアント側でカタカナに変換する（ひらがな・半角カタカナ対応）
 * @param text - 入力テキスト
 * @returns カタカナ変換済みテキスト
 */
const clientConvert = (text: string): string => {
  let result = hiraganaToKatakana(text);
  result = halfToFullKatakana(result);
  return result;
};

/**
 * 会社名からフリガナを自動生成するカスタムフック
 *
 * - ひらがな・半角カタカナ → 即座にクライアント側で全角カタカナに変換
 * - 漢字・英語を含む場合 → デバウンスでバックエンドAPI（Claude Haiku）に変換依頼
 * - ユーザーがフリガナ欄を手動編集した場合は自動上書きを停止
 *
 * @param companyName - 会社名フィールドの現在値
 * @param setValue - react-hook-formのsetValue
 * @param enabled - 有効/無効フラグ（編集ページの初回ロード防止用）
 * @returns kanaManuallyEdited ref（フリガナ欄のonChangeに使用）
 */
export function useKatakanaAutoFill(
  companyName: string | undefined,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  setValue: UseFormSetValue<any>,
  enabled: boolean = true
) {
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const manuallyEdited = useRef(false);
  const lastApiText = useRef("");

  useEffect(() => {
    if (!enabled || manuallyEdited.current) return;

    const text = companyName?.trim() ?? "";

    if (text.length === 0) {
      setValue("company_name_kana", "", { shouldValidate: false });
      lastApiText.current = "";
      return;
    }

    // ① ひらがな・カタカナのみの場合 → 即座にクライアント変換
    if (KANA_ONLY.test(text)) {
      const converted = clientConvert(text);
      setValue("company_name_kana", converted, { shouldValidate: false });
      lastApiText.current = "";
      return;
    }

    // ② 既にカタカナのみの場合 → そのままセット
    if (KATAKANA_ONLY.test(text)) {
      setValue("company_name_kana", text, { shouldValidate: false });
      lastApiText.current = "";
      return;
    }

    // ③ 漢字・英語を含む → クライアント変換を暫定表示 + APIでの精密変換
    const provisional = clientConvert(text);
    if (!KATAKANA_ONLY.test(provisional)) {
      // 暫定値がカタカナのみでなければAPI呼び出しが必要
      if (timerRef.current) clearTimeout(timerRef.current);

      // 同じテキストで既にAPI呼び出し済みならスキップ
      if (lastApiText.current === text) return;

      timerRef.current = setTimeout(async () => {
        try {
          const res = await api.post<{ katakana: string }>(
            "/api/v1/customers/katakana",
            { text }
          );
          if (res.katakana && !manuallyEdited.current) {
            setValue("company_name_kana", res.katakana, {
              shouldValidate: false,
            });
            lastApiText.current = text;
          }
        } catch {
          // API失敗時は手動入力に任せる
        }
      }, 500);
    } else {
      // クライアント変換で十分
      setValue("company_name_kana", provisional, { shouldValidate: false });
    }

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [companyName, setValue, enabled]);

  return manuallyEdited;
}
