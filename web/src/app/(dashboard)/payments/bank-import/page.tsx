"use client";

import { useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  Upload,
  CheckCircle2,
  AlertCircle,
  XCircle,
  ChevronLeft,
  FileSpreadsheet,
  Loader2,
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { api, ApiClientError } from "@/lib/api-client";
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

/** AIマッチング結果の型 */
interface MatchResults {
  auto_matched: number;
  needs_review: number;
  unmatched: number;
}

/** ステップの定義 */
type Step = "upload" | "matching" | "review";

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
 * CSV取込 → AIマッチング → 結果確認のステップで銀行明細をインポートする
 */
export default function BankImportPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("upload");
  const [bankFormat, setBankFormat] = useState("generic");
  const [file, setFile] = useState<File | null>(null);
  const [importing, setImporting] = useState(false);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);
  const [matchResults, setMatchResults] = useState<MatchResults | null>(null);
  const [unmatchedStatements, setUnmatchedStatements] = useState<UnmatchedStatement[]>([]);
  const [loadingReview, setLoadingReview] = useState(false);

  // 手動マッチダイアログ
  const [matchTarget, setMatchTarget] = useState<UnmatchedStatement | null>(null);
  const [matchingManual, setMatchingManual] = useState(false);

  /**
   * ファイルドロップハンドラー
   */
  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const droppedFile = e.dataTransfer.files[0];
    if (droppedFile && (droppedFile.name.endsWith(".csv") || droppedFile.name.endsWith(".CSV"))) {
      setFile(droppedFile);
    } else {
      toast.error("CSVファイルを選択してください");
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
   * インポート実行
   */
  const handleImport = async () => {
    if (!file) return;
    setImporting(true);
    setStep("matching");

    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("bank_format", bankFormat);

      const result = await api.upload<ImportResult>("/api/v1/bank_statements/import", formData);
      setImportResult(result);

      // AIマッチングを待つ（少し待ってから結果を取得）
      toast.success(`${result.imported}件の明細をインポートしました`);

      // AIマッチング結果をポーリング
      await new Promise((resolve) => setTimeout(resolve, 2000));
      const matchRes = await api.post<MatchResults>("/api/v1/bank_statements/ai_match", {
        batch_id: result.batch_id,
      });
      setMatchResults(matchRes);
      setStep("review");

      // 未消込明細を取得
      await loadUnmatched();
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
   * 未消込明細を読み込む
   */
  const loadUnmatched = async () => {
    setLoadingReview(true);
    try {
      const data = await api.get<{ bank_statements: UnmatchedStatement[] }>("/api/v1/bank_statements/unmatched", {
        per_page: "100",
      });
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
            CSVファイルから銀行明細を取り込み、AIで自動消込を行います
          </p>
        </div>
      </div>

      {/* ステップインジケーター */}
      <div className="flex items-center gap-4">
        {[
          { key: "upload", label: "1. CSV取込", icon: Upload },
          { key: "matching", label: "2. AI消込中", icon: Loader2 },
          { key: "review", label: "3. 結果確認", icon: CheckCircle2 },
        ].map(({ key, label, icon: Icon }) => (
          <div
            key={key}
            className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium ${
              step === key
                ? "bg-primary text-primary-foreground"
                : step > key
                ? "bg-muted text-muted-foreground"
                : "text-muted-foreground"
            }`}
          >
            <Icon className={`size-4 ${step === "matching" && key === "matching" ? "animate-spin" : ""}`} />
            {label}
          </div>
        ))}
      </div>

      {/* Step 1: CSV取込 */}
      {step === "upload" && (
        <Card>
          <CardHeader>
            <CardTitle>CSVファイルを取込</CardTitle>
            <CardDescription>
              銀行からダウンロードした取引明細CSVをドラッグ＆ドロップまたは選択してください
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">銀行フォーマット</label>
              <Select value={bankFormat} onValueChange={setBankFormat}>
                <SelectTrigger className="w-[250px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="generic">汎用（自動判定）</SelectItem>
                  <SelectItem value="mufg">三菱UFJ銀行</SelectItem>
                  <SelectItem value="smbc">三井住友銀行</SelectItem>
                  <SelectItem value="mizuho">みずほ銀行</SelectItem>
                  <SelectItem value="rakuten">楽天銀行</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div
              onDrop={handleDrop}
              onDragOver={(e) => e.preventDefault()}
              className={`flex flex-col items-center justify-center rounded-lg border-2 border-dashed p-12 transition-colors ${
                file ? "border-primary bg-primary/5" : "border-muted-foreground/25 hover:border-muted-foreground/50"
              }`}
            >
              {file ? (
                <>
                  <FileSpreadsheet className="mb-3 size-10 text-primary" />
                  <p className="text-sm font-medium">{file.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {(file.size / 1024).toFixed(1)} KB
                  </p>
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
                    CSVファイルをドラッグ＆ドロップ
                  </p>
                  <p className="text-xs text-muted-foreground/50">
                    または
                  </p>
                  <label className="mt-2 cursor-pointer">
                    <input
                      type="file"
                      accept=".csv"
                      className="hidden"
                      onChange={handleFileSelect}
                    />
                    <span className="text-sm text-primary hover:underline">
                      ファイルを選択
                    </span>
                  </label>
                </>
              )}
            </div>

            <div className="flex justify-end">
              <Button onClick={handleImport} disabled={!file || importing}>
                {importing ? "取込中..." : "取込を開始"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Step 2: AIマッチング中 */}
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

      {/* Step 3: 結果確認 */}
      {step === "review" && (
        <div className="space-y-6">
          {/* サマリーカード */}
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

          {/* 未消込明細テーブル */}
          <Card>
            <CardHeader>
              <CardTitle>要確認・未マッチ明細</CardTitle>
              <CardDescription>
                AI提案を確認して消込を確定、またはスキップしてください
              </CardDescription>
            </CardHeader>
            <CardContent>
              {loadingReview ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="size-8 animate-spin text-muted-foreground" />
                </div>
              ) : unmatchedStatements.length === 0 ? (
                <div className="flex flex-col items-center py-12 text-muted-foreground">
                  <CheckCircle2 className="mb-2 size-8 opacity-50" />
                  <p>すべての明細が消込済みです</p>
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>取引日</TableHead>
                      <TableHead>振込名</TableHead>
                      <TableHead className="text-right">金額</TableHead>
                      <TableHead>AI提案</TableHead>
                      <TableHead>信頼度</TableHead>
                      <TableHead className="w-[150px]">操作</TableHead>
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
                          <div className="flex gap-1">
                            {stmt.suggestion && (
                              <Button
                                size="sm"
                                onClick={() => handleConfirmMatch(stmt)}
                                disabled={matchingManual}
                              >
                                確定
                              </Button>
                            )}
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => {
                                setUnmatchedStatements((prev) => prev.filter((s) => s.id !== stmt.id));
                              }}
                            >
                              スキップ
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>

          {/* 完了ボタン */}
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
