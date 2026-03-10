"use client";

import { useState, useCallback, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Upload,
  CheckCircle2,
  AlertCircle,
  XCircle,
  ChevronLeft,
  FileSpreadsheet,
  Image,
  FileText,
  Loader2,
  Eye,
  Pencil,
  Trash2,
  ShieldCheck,
  ShieldAlert,
  ShieldQuestion,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Input } from "@/components/ui/input";
import { api, ApiClientError } from "@/lib/api-client";
import { Tenant } from "@/types/tenant";
import Link from "next/link";

/** インポート結果の型 */
interface ImportResult {
  imported: number;
  skipped: number;
  batch_id: string;
}

/** AI提案情報 */
interface Suggestion {
  document_uuid: string;
  document_number: string;
  customer_name: string | null;
  remaining_amount: number;
  confidence: number;
  reason: string;
}

/** 未消込明細の型 */
interface UnmatchedStatement {
  id: number;
  transaction_date: string;
  description: string;
  payer_name: string | null;
  amount: number;
  is_matched: boolean;
  ai_match_confidence: number | null;
  ai_match_reason: string | null;
  suggestion?: Suggestion | null;
}

/** 自動マッチ詳細 */
interface AutoMatchDetail {
  payer_name: string;
  amount: number;
  transaction_date: string;
  document_number: string;
  customer_name: string | null;
  confidence: number;
}

/** AIマッチング結果の型 */
interface MatchResults {
  auto_matched: number;
  needs_review: number;
  unmatched: number;
  auto_matched_details: AutoMatchDetail[];
}

/** OCR抽出行の型 */
interface OcrRow {
  date: string;
  description: string;
  amount: string;
  confidence: "high" | "medium" | "low";
  warning: string | null;
}

/** ステップの定義（OCR確認ステップ追加） */
type Step = "upload" | "ocr_loading" | "ocr_confirm" | "matching" | "review";

/** ステップの順序 */
const STEP_ORDER: Step[] = ["upload", "ocr_loading", "ocr_confirm", "matching", "review"];

/**
 * 金額を3桁カンマ区切りでフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatAmount(amount: number): string {
  return `¥${amount.toLocaleString()}`;
}

/**
 * 信頼度に応じたBadgeのvariantを返す
 * @param confidence - 信頼度 (0.0-1.0)
 * @returns Badgeのvariant
 */
function confidenceVariant(confidence: number): "default" | "secondary" | "destructive" {
  if (confidence >= 0.9) return "default";
  if (confidence >= 0.7) return "secondary";
  return "destructive";
}

/**
 * 銀行明細取込ページ
 * ファイル取込 → [OCR確認] → AIマッチング → 結果確認のステップで銀行明細をインポートする
 */
export default function BankImportPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("upload");
  const [bankFormat, setBankFormat] = useState("auto");
  const [file, setFile] = useState<File | null>(null);
  const [importing, setImporting] = useState(false);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);
  const [matchResults, setMatchResults] = useState<MatchResults | null>(null);
  const [unmatchedStatements, setUnmatchedStatements] = useState<UnmatchedStatement[]>([]);
  const [loadingReview, setLoadingReview] = useState(false);

  // プラン制限
  const [tenantPlan, setTenantPlan] = useState<string | null>(null);
  const isFreePlan = tenantPlan === "free";

  useEffect(() => {
    api.get<{ tenant: Tenant }>("/api/v1/tenant")
      .then((data) => setTenantPlan(data.tenant.plan))
      .catch(() => {});
  }, []);

  // OCR確認ステート
  const [ocrRows, setOcrRows] = useState<OcrRow[]>([]);
  const [editingRowIndex, setEditingRowIndex] = useState<number | null>(null);
  const [editForm, setEditForm] = useState<{ date: string; description: string; amount: string }>({
    date: "",
    description: "",
    amount: "",
  });

  // 手動マッチ
  const [matchingManual, setMatchingManual] = useState(false);

  /** 対応ファイル拡張子 */
  const ACCEPTED_EXTENSIONS = [".csv", ".pdf", ".jpg", ".jpeg", ".png", ".webp"];

  /**
   * ファイルが対応形式か判定する
   * @param f - チェック対象のファイル
   * @returns 対応形式ならtrue
   */
  const isAcceptedFile = (f: File): boolean => {
    const ext = f.name.toLowerCase().slice(f.name.lastIndexOf("."));
    return ACCEPTED_EXTENSIONS.includes(ext);
  };

  /**
   * ファイルがOCR対象（画像/PDF）か判定する
   * @param f - チェック対象のファイル
   * @returns OCR対象ならtrue
   */
  const isOcrFile = (f: File): boolean => {
    const ext = f.name.toLowerCase().slice(f.name.lastIndexOf("."));
    return [".pdf", ".jpg", ".jpeg", ".png", ".webp"].includes(ext);
  };

  /**
   * ファイルドロップハンドラー
   */
  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const droppedFile = e.dataTransfer.files[0];
    if (droppedFile && isAcceptedFile(droppedFile)) {
      setFile(droppedFile);
    } else {
      toast.error("CSV・PDF・画像ファイル（JPG/PNG）を選択してください");
    }
  }, []);

  /**
   * ファイル選択ハンドラー
   */
  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = e.target.files?.[0];
    if (selected) setFile(selected);
  }, []);

  /**
   * 取込開始 — CSVは直接インポート、画像/PDFはOCRプレビューへ
   */
  const handleStartImport = async () => {
    if (!file) return;

    if (isOcrFile(file)) {
      // OCRプレビューフロー
      setStep("ocr_loading");
      try {
        const formData = new FormData();
        formData.append("file", file);
        const result = await api.upload<{ rows: OcrRow[]; warnings_count: number }>(
          "/api/v1/bank_statements/ocr_preview",
          formData
        );
        setOcrRows(result.rows);
        setStep("ocr_confirm");
        if (result.warnings_count > 0) {
          toast.warning(`${result.warnings_count}件の読み取りに注意が必要です。確認してください。`);
        } else {
          toast.success(`${result.rows.length}件の明細を読み取りました。内容を確認してください。`);
        }
      } catch (e) {
        if (e instanceof ApiClientError) {
          toast.error(e.body?.error?.message || "AI読み取りに失敗しました");
        }
        setStep("upload");
      }
    } else {
      // CSV直接インポート
      await doImport();
    }
  };

  /**
   * CSVインポートまたは確認済みOCRデータのインポート実行
   */
  const doImport = async (confirmedRows?: OcrRow[]) => {
    setImporting(true);
    setStep("matching");

    try {
      let result: ImportResult;

      if (confirmedRows) {
        // OCR確認済みデータ
        result = await api.post<ImportResult>("/api/v1/bank_statements/import", {
          confirmed_rows: confirmedRows.map((r) => ({
            date: r.date,
            description: r.description,
            amount: r.amount,
          })),
          bank_format: bankFormat,
        });
      } else if (file) {
        // CSVファイル
        const formData = new FormData();
        formData.append("file", file);
        formData.append("bank_format", bankFormat);
        result = await api.upload<ImportResult>("/api/v1/bank_statements/import", formData);
      } else {
        return;
      }

      setImportResult(result);
      if (result.imported > 0) {
        toast.success(`${result.imported}件の明細をインポートしました`);
      } else {
        toast.info(`新規明細は0件でした（${result.skipped}件は取込済み）`);
      }

      // AIマッチング（全未マッチ対象）
      const matchRes = await api.post<MatchResults>("/api/v1/bank_statements/ai_match", {});
      setMatchResults(matchRes);
      setStep("review");
      // 常にバッチIDで絞り込み（今回のインポート分のみ表示）
      await loadUnmatched(result.batch_id);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "インポートに失敗しました");
      }
      setStep("upload");
    } finally {
      setImporting(false);
    }
  };

  /**
   * OCR確認済みデータでインポート実行
   */
  const handleConfirmOcr = () => {
    if (ocrRows.length === 0) {
      toast.error("インポートする明細がありません");
      return;
    }
    doImport(ocrRows);
  };

  /**
   * OCR行の編集を開始する
   * @param index - 行インデックス
   */
  const startEditing = (index: number) => {
    const row = ocrRows[index];
    if (!row) return;
    setEditingRowIndex(index);
    setEditForm({ date: row.date, description: row.description, amount: row.amount });
  };

  /**
   * OCR行の編集を確定する
   */
  const saveEditing = () => {
    if (editingRowIndex === null) return;
    setOcrRows((prev) =>
      prev.map((row, i) =>
        i === editingRowIndex
          ? { ...row, date: editForm.date, description: editForm.description, amount: editForm.amount, confidence: "high" as const, warning: null }
          : row
      )
    );
    setEditingRowIndex(null);
  };

  /**
   * OCR行を削除する
   * @param index - 行インデックス
   */
  const removeOcrRow = (index: number) => {
    setOcrRows((prev) => prev.filter((_, i) => i !== index));
  };

  /**
   * 未消込明細を読み込む（現在のインポートバッチのみ）
   */
  const loadUnmatched = async (batchId?: string) => {
    setLoadingReview(true);
    try {
      const params: Record<string, string> = { per_page: "100" };
      if (batchId) params.batch_id = batchId;
      const data = await api.get<{ bank_statements: UnmatchedStatement[] }>("/api/v1/bank_statements/unmatched", params);
      setUnmatchedStatements(data.bank_statements);
    } catch {
      toast.error("未消込明細の取得に失敗しました");
    } finally {
      setLoadingReview(false);
    }
  };

  /**
   * AI提案を確定して手動マッチングする
   */
  const handleConfirmMatch = async (stmt: UnmatchedStatement) => {
    if (!stmt.suggestion?.document_uuid) return;
    setMatchingManual(true);
    try {
      await api.post(`/api/v1/bank_statements/${stmt.id}/match`, {
        document_uuid: stmt.suggestion.document_uuid,
      });
      toast.success("消込を確定しました");
      setUnmatchedStatements((prev) => prev.filter((s) => s.id !== stmt.id));
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "消込に失敗しました");
      }
    } finally {
      setMatchingManual(false);
    }
  };

  /**
   * ステップ比較用ヘルパー
   */
  const stepIndex = (s: Step) => STEP_ORDER.indexOf(s);

  /**
   * 信頼度アイコンを返す
   */
  const confidenceIcon = (confidence: string) => {
    switch (confidence) {
      case "high":
        return <ShieldCheck className="size-4 text-green-500" />;
      case "medium":
        return <ShieldQuestion className="size-4 text-amber-500" />;
      case "low":
        return <ShieldAlert className="size-4 text-red-500" />;
      default:
        return null;
    }
  };

  /** ステップインジケーター用定義 */
  const stepIndicators = file && isOcrFile(file)
    ? [
        { key: "upload" as Step, label: "明細取込", icon: Upload },
        { key: "ocr_confirm" as Step, label: "読取確認", icon: Eye },
        { key: "matching" as Step, label: "AI消込中", icon: Loader2 },
        { key: "review" as Step, label: "結果確認", icon: CheckCircle2 },
      ]
    : [
        { key: "upload" as Step, label: "明細取込", icon: Upload },
        { key: "matching" as Step, label: "AI消込中", icon: Loader2 },
        { key: "review" as Step, label: "結果確認", icon: CheckCircle2 },
      ];

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" asChild className="size-10 sm:size-9">
          <Link href="/payments">
            <ChevronLeft className="size-5 sm:size-4" />
          </Link>
        </Button>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">銀行明細取込</h1>
          <p className="text-sm text-muted-foreground">
            CSV・写真・PDFから銀行明細を取り込み、AIで自動消込を行います
          </p>
        </div>
      </div>

      {/* ステップインジケーター */}
      <div className={`grid gap-3 sm:gap-4 ${stepIndicators.length === 4 ? "grid-cols-4" : "grid-cols-3"}`}>
        {stepIndicators.map(({ key, label, icon: Icon }, index) => {
          const isActive = step === key || (key === "ocr_confirm" && step === "ocr_loading");
          const isPast = stepIndex(step) > stepIndex(key);
          return (
            <div
              key={key}
              className={`flex items-center justify-center gap-1.5 sm:gap-2 rounded-lg px-2 py-2.5 sm:px-4 sm:py-2.5 text-xs sm:text-sm font-medium whitespace-nowrap ${
                isActive
                  ? "bg-primary text-primary-foreground"
                  : isPast
                  ? "bg-muted text-muted-foreground"
                  : "text-muted-foreground"
              }`}
            >
              <Icon className={`size-3.5 sm:size-4 shrink-0 ${(step === "matching" && key === "matching") || (step === "ocr_loading" && key === "ocr_confirm") ? "animate-spin" : ""}`} />
              <span>{index + 1}. {label}</span>
            </div>
          );
        })}
      </div>

      {/* Step 1: 明細取込 */}
      {step === "upload" && (
        <Card>
          <CardHeader>
            <CardTitle>明細ファイルを取込</CardTitle>
            <CardDescription>
              銀行の取引明細をドラッグ＆ドロップまたは選択してください。CSV・PDF・写真（JPG/PNG）に対応しています。
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* フリープラン制限 */}
            {isFreePlan && (
              <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 dark:border-red-900 dark:bg-red-950/30">
                <p className="text-sm font-medium text-red-700 dark:text-red-400">
                  Freeプランでは銀行明細取込・AI消込をご利用いただけません
                </p>
                <p className="mt-1 text-xs text-red-600 dark:text-red-500">
                  Starter プラン以上にアップグレードすると、CSV・写真・PDFからの明細取込とAI自動消込が利用できます。
                </p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-2 border-red-300 text-red-700 hover:bg-red-100 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
                  asChild
                >
                  <Link href="/settings/billing">プランを確認する</Link>
                </Button>
              </div>
            )}

            <div className="space-y-2">
              <label className="text-sm font-medium">銀行フォーマット</label>
              <Select value={bankFormat} onValueChange={setBankFormat} disabled={isFreePlan}>
                <SelectTrigger className="w-[250px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="auto">自動判定</SelectItem>
                  <SelectItem value="mufg">三菱UFJ銀行</SelectItem>
                  <SelectItem value="smbc">三井住友銀行</SelectItem>
                  <SelectItem value="mizuho">みずほ銀行</SelectItem>
                  <SelectItem value="rakuten">楽天銀行</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div
              onDrop={isFreePlan ? undefined : handleDrop}
              onDragOver={isFreePlan ? undefined : (e) => e.preventDefault()}
              className={`flex flex-col items-center justify-center rounded-lg border-2 border-dashed p-12 transition-colors ${
                isFreePlan
                  ? "border-muted-foreground/15 bg-muted/50 opacity-60 cursor-not-allowed"
                  : file
                  ? "border-primary bg-primary/5"
                  : "border-muted-foreground/25 hover:border-muted-foreground/50"
              }`}
            >
              {file && !isFreePlan ? (
                <>
                  {isOcrFile(file) ? (
                    file.name.toLowerCase().endsWith(".pdf") ? (
                      <FileText className="mb-3 size-10 text-primary" />
                    ) : (
                      <Image className="mb-3 size-10 text-primary" />
                    )
                  ) : (
                    <FileSpreadsheet className="mb-3 size-10 text-primary" />
                  )}
                  <p className="text-sm font-medium">{file.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {(file.size / 1024).toFixed(1)} KB
                  </p>
                  {isOcrFile(file) && (
                    <Badge variant="secondary" className="mt-2">
                      AI読み取り（OCR） — ダブルパス検証
                    </Badge>
                  )}
                  <Button
                    variant="ghost"
                    size="sm"
                    className="mt-2"
                    onClick={() => setFile(null)}
                  >
                    ファイルを変更
                  </Button>
                </>
              ) : (
                <>
                  <Upload className="mb-3 size-10 text-muted-foreground/50" />
                  <p className="text-sm text-muted-foreground">
                    ファイルをドラッグ＆ドロップ
                  </p>
                  <p className="mt-1 text-xs text-muted-foreground/70">
                    CSV・PDF・写真（JPG / PNG）
                  </p>
                  <p className="text-xs text-muted-foreground/50">
                    または
                  </p>
                  <label className={`mt-2 ${isFreePlan ? "cursor-not-allowed" : "cursor-pointer"}`}>
                    <input
                      type="file"
                      accept=".csv,.pdf,.jpg,.jpeg,.png,.webp"
                      className="hidden"
                      onChange={handleFileSelect}
                      disabled={isFreePlan}
                    />
                    <span className={`text-sm ${isFreePlan ? "text-muted-foreground" : "text-primary hover:underline"}`}>
                      ファイルを選択
                    </span>
                  </label>
                </>
              )}
            </div>

            <div className="flex justify-end">
              <Button onClick={handleStartImport} disabled={!file || importing || isFreePlan}>
                {file && isOcrFile(file) ? "AI読み取りを開始" : "取込を開始"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* OCR読み取り中 */}
      {step === "ocr_loading" && (
        <Card>
          <CardContent className="flex flex-col items-center py-12">
            <Loader2 className="mb-4 size-12 animate-spin text-primary" />
            <p className="text-lg font-medium">AI読み取り中...</p>
            <p className="text-sm text-muted-foreground">
              画像・PDFから明細データを抽出しています（ダブルパス検証）
            </p>
            <p className="mt-2 text-xs text-muted-foreground/70">
              正確性のため2回読み取って結果を突合しています
            </p>
          </CardContent>
        </Card>
      )}

      {/* OCR確認・修正ステップ */}
      {step === "ocr_confirm" && (
        <div className="space-y-4">
          {/* サマリー */}
          <div className="grid gap-3 sm:gap-4 grid-cols-3">
            <Card>
              <CardContent className="flex items-center gap-3 pt-5 pb-4">
                <ShieldCheck className="size-8 text-green-500 shrink-0" />
                <div>
                  <p className="text-xl font-bold">{ocrRows.filter((r) => r.confidence === "high").length}</p>
                  <p className="text-xs text-muted-foreground">読取OK</p>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="flex items-center gap-3 pt-5 pb-4">
                <ShieldQuestion className="size-8 text-amber-500 shrink-0" />
                <div>
                  <p className="text-xl font-bold">{ocrRows.filter((r) => r.confidence === "medium").length}</p>
                  <p className="text-xs text-muted-foreground">読取あいまい</p>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="flex items-center gap-3 pt-5 pb-4">
                <ShieldAlert className="size-8 text-red-500 shrink-0" />
                <div>
                  <p className="text-xl font-bold">{ocrRows.filter((r) => r.confidence === "low").length}</p>
                  <p className="text-xs text-muted-foreground">読取不正確</p>
                </div>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>読み取り結果の確認</CardTitle>
              <CardDescription>
                AIが2回読み取った結果を突合しました。ここでは読み取り精度のみ表示しています（請求書との照合は次のステップで行います）。赤・黄色の行は特に注意して確認・修正してください。
              </CardDescription>
            </CardHeader>
            <CardContent>
              {ocrRows.length === 0 ? (
                <div className="flex flex-col items-center py-12 text-muted-foreground">
                  <AlertCircle className="mb-2 size-8 opacity-50" />
                  <p>明細データが抽出されませんでした</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="w-12">読取</TableHead>
                        <TableHead>取引日</TableHead>
                        <TableHead>摘要</TableHead>
                        <TableHead className="text-right">金額</TableHead>
                        <TableHead className="w-24">操作</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {ocrRows.map((row, idx) => (
                        <TableRow
                          key={idx}
                          className={
                            row.confidence === "low"
                              ? "bg-red-50 dark:bg-red-950/20"
                              : row.confidence === "medium"
                              ? "bg-amber-50 dark:bg-amber-950/20"
                              : ""
                          }
                        >
                          {editingRowIndex === idx ? (
                            <>
                              <TableCell>{confidenceIcon(row.confidence)}</TableCell>
                              <TableCell>
                                <Input
                                  value={editForm.date}
                                  onChange={(e) => setEditForm((p) => ({ ...p, date: e.target.value }))}
                                  className="h-8 w-32"
                                  placeholder="YYYY/MM/DD"
                                />
                              </TableCell>
                              <TableCell>
                                <Input
                                  value={editForm.description}
                                  onChange={(e) => setEditForm((p) => ({ ...p, description: e.target.value }))}
                                  className="h-8"
                                />
                              </TableCell>
                              <TableCell className="text-right">
                                <Input
                                  value={editForm.amount}
                                  onChange={(e) => setEditForm((p) => ({ ...p, amount: e.target.value }))}
                                  className="h-8 w-28 text-right"
                                  placeholder="金額"
                                />
                              </TableCell>
                              <TableCell>
                                <div className="flex gap-1">
                                  <Button size="sm" onClick={saveEditing}>
                                    保存
                                  </Button>
                                  <Button size="sm" variant="ghost" onClick={() => setEditingRowIndex(null)}>
                                    取消
                                  </Button>
                                </div>
                              </TableCell>
                            </>
                          ) : (
                            <>
                              <TableCell>
                                <div className="flex items-center gap-1">
                                  {confidenceIcon(row.confidence)}
                                </div>
                              </TableCell>
                              <TableCell className="whitespace-nowrap">{row.date}</TableCell>
                              <TableCell>
                                <div>
                                  <span>{row.description}</span>
                                  {row.warning && (
                                    <p className="mt-0.5 text-xs text-red-600 dark:text-red-400">
                                      ⚠ {row.warning}
                                    </p>
                                  )}
                                </div>
                              </TableCell>
                              <TableCell className="text-right font-medium whitespace-nowrap">
                                ¥{Number(row.amount).toLocaleString()}
                              </TableCell>
                              <TableCell>
                                <div className="flex gap-1">
                                  <Button
                                    size="sm"
                                    variant="ghost"
                                    onClick={() => startEditing(idx)}
                                    title="編集"
                                  >
                                    <Pencil className="size-3.5" />
                                  </Button>
                                  <Button
                                    size="sm"
                                    variant="ghost"
                                    onClick={() => removeOcrRow(idx)}
                                    title="削除"
                                    className="text-red-500 hover:text-red-700"
                                  >
                                    <Trash2 className="size-3.5" />
                                  </Button>
                                </div>
                              </TableCell>
                            </>
                          )}
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>

          <div className="flex items-center justify-between">
            <Button variant="outline" onClick={() => { setStep("upload"); setOcrRows([]); }}>
              やり直す
            </Button>
            <div className="flex items-center gap-3">
              {ocrRows.some((r) => r.confidence === "low") && (
                <p className="text-sm text-red-600 dark:text-red-400">
                  ⚠ 要確認の行があります
                </p>
              )}
              <Button onClick={handleConfirmOcr} disabled={ocrRows.length === 0}>
                確認完了 — {ocrRows.length}件をインポート
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* AIマッチング中 */}
      {step === "matching" && (
        <Card>
          <CardContent className="flex flex-col items-center py-12">
            <Loader2 className="mb-4 size-12 animate-spin text-primary" />
            <p className="text-lg font-medium">AI消込を実行中...</p>
            <p className="text-sm text-muted-foreground">
              {importResult && `${importResult.imported}件の明細をAIが分析しています`}
            </p>
          </CardContent>
        </Card>
      )}

      {/* 結果確認 */}
      {step === "review" && (
        <div className="space-y-6">
          {matchResults && (
            <div className="grid gap-4 md:grid-cols-3">
              <Card>
                <CardContent className="flex items-center gap-4 pt-6">
                  <CheckCircle2 className="size-10 text-green-500" />
                  <div>
                    <p className="text-2xl font-bold">{matchResults.auto_matched}</p>
                    <p className="text-sm text-muted-foreground">自動消込済み</p>
                  </div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="flex items-center gap-4 pt-6">
                  <AlertCircle className="size-10 text-amber-500" />
                  <div>
                    <p className="text-2xl font-bold">{matchResults.needs_review}</p>
                    <p className="text-sm text-muted-foreground">要確認</p>
                  </div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="flex items-center gap-4 pt-6">
                  <XCircle className="size-10 text-red-500" />
                  <div>
                    <p className="text-2xl font-bold">{matchResults.unmatched}</p>
                    <p className="text-sm text-muted-foreground">未マッチ</p>
                  </div>
                </CardContent>
              </Card>
            </div>
          )}

          {/* 自動マッチ結果 */}
          {matchResults && matchResults.auto_matched_details && matchResults.auto_matched_details.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <ShieldCheck className="size-5 text-green-500" />
                  自動消込済み
                </CardTitle>
                <CardDescription>
                  AIが高い確度で自動的に消込した明細です
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>取引日</TableHead>
                      <TableHead>振込名</TableHead>
                      <TableHead className="text-right">金額</TableHead>
                      <TableHead>マッチした請求書</TableHead>
                      <TableHead>信頼度</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {matchResults.auto_matched_details.map((detail, i) => (
                      <TableRow key={i} className="bg-green-50/50">
                        <TableCell className="whitespace-nowrap">{detail.transaction_date}</TableCell>
                        <TableCell>{detail.payer_name}</TableCell>
                        <TableCell className="text-right font-medium">{formatAmount(detail.amount)}</TableCell>
                        <TableCell>
                          <div>
                            <p className="text-sm font-medium">{detail.document_number}</p>
                            <p className="text-xs text-muted-foreground">{detail.customer_name}</p>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge variant="default">{Math.round(detail.confidence * 100)}%</Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          )}

          {/* 要確認・未マッチ明細 */}
          {unmatchedStatements.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <AlertCircle className="size-5 text-amber-500" />
                  要確認・未マッチ明細
                </CardTitle>
                <CardDescription>
                  AI提案がある場合は確認して消込を確定できます
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>取引日</TableHead>
                      <TableHead>振込名</TableHead>
                      <TableHead className="text-right">金額</TableHead>
                      <TableHead>AI提案</TableHead>
                      <TableHead>信頼度</TableHead>
                      <TableHead className="w-[100px]">操作</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {unmatchedStatements.map((stmt) => (
                      <TableRow key={stmt.id}>
                        <TableCell className="whitespace-nowrap">
                          {stmt.transaction_date}
                        </TableCell>
                        <TableCell>{stmt.payer_name || stmt.description}</TableCell>
                        <TableCell className="text-right font-medium">
                          {formatAmount(stmt.amount)}
                        </TableCell>
                        <TableCell>
                          {stmt.suggestion ? (
                            <div>
                              <p className="text-sm font-medium">{stmt.suggestion.document_number}</p>
                              <p className="text-xs text-muted-foreground">{stmt.suggestion.customer_name}</p>
                            </div>
                          ) : (
                            <span className="text-sm text-muted-foreground">候補なし</span>
                          )}
                        </TableCell>
                        <TableCell>
                          {stmt.suggestion ? (
                            <div className="flex items-center gap-2">
                              <Progress
                                value={(stmt.suggestion.confidence ?? 0) * 100}
                                className="w-16"
                              />
                              <Badge variant={confidenceVariant(stmt.suggestion.confidence ?? 0)}>
                                {Math.round((stmt.suggestion.confidence ?? 0) * 100)}%
                              </Badge>
                            </div>
                          ) : (
                            "-"
                          )}
                        </TableCell>
                        <TableCell>
                          {stmt.suggestion && (
                            <Button
                              size="sm"
                              onClick={() => handleConfirmMatch(stmt)}
                              disabled={matchingManual}
                            >
                              確定
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          )}

          {/* すべて消込済み */}
          {!loadingReview && unmatchedStatements.length === 0 && (!matchResults?.auto_matched_details?.length) && (
            <Card>
              <CardContent className="flex flex-col items-center py-12 text-muted-foreground">
                <CheckCircle2 className="mb-2 size-8 opacity-50" />
                <p>すべての明細が消込済みです</p>
              </CardContent>
            </Card>
          )}

          <div className="flex justify-end">
            <Button onClick={() => router.push("/payments")}>
              入金一覧に戻る
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
