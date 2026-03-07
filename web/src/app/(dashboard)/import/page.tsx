"use client";

import { useState, useCallback } from "react";
import {
  Upload,
  FileSpreadsheet,
  FileText,
  ArrowRight,
  ArrowLeft,
  Check,
  AlertCircle,
  Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
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
import { api, ApiClientError } from "@/lib/api-client";

/** インポートジョブ型 */
interface ImportJob {
  uuid: string;
  source_type: string;
  status: string;
  file_name: string;
  column_mapping: MappingItem[] | null;
  ai_mapping_confidence: string | null;
  import_stats: ImportStats | null;
  error_details: ErrorDetail[] | null;
}

/** マッピング項目 */
interface MappingItem {
  source: string;
  target_table: string | null;
  target_column: string | null;
  confidence: number;
  method: string | null;
}

/** インポート統計 */
interface ImportStats {
  total_rows: number;
  success_count: number;
  error_count: number;
  skip_count: number;
}

/** エラー詳細 */
interface ErrorDetail {
  row: number;
  column: string | null;
  message: string;
}

/** ウケトリカラムの選択肢 */
const TARGET_OPTIONS: Record<string, string[]> = {
  customers: ["company_name", "company_name_kana", "customer_code", "postal_code", "address_line1", "phone", "email", "notes"],
  customer_contacts: ["name", "email", "phone", "department", "position"],
  documents: ["document_number", "subject", "issue_date", "due_date", "total_amount", "notes"],
  products: ["name", "code", "description", "unit", "unit_price"],
  projects: ["name", "code", "description", "status"],
};

/** テーブル名ラベル */
const TABLE_LABELS: Record<string, string> = {
  customers: "顧客",
  customer_contacts: "連絡先",
  documents: "帳票",
  document_items: "帳票明細",
  products: "品目",
  projects: "案件",
};

/** ソースタイプの表示ラベルとアイコン */
const SOURCE_TYPES = [
  { value: "board", label: "board", description: "boardからのCSVエクスポート", icon: FileSpreadsheet },
  { value: "excel", label: "Excel", description: ".xlsx / .xls ファイル", icon: FileSpreadsheet },
  { value: "csv_generic", label: "CSV", description: "汎用CSVファイル", icon: FileText },
];

/**
 * 確信度に応じた色を返す
 * @param confidence - 確信度 (0-1)
 * @returns Tailwind CSS色クラス
 */
function confidenceColor(confidence: number): string {
  if (confidence >= 0.8) return "text-green-600";
  if (confidence >= 0.5) return "text-yellow-600";
  return "text-red-600";
}

/**
 * 確信度に応じたプログレスバー色を返す
 * @param confidence - 確信度 (0-1)
 * @returns Tailwind CSSクラス
 */
function confidenceBg(confidence: number): string {
  if (confidence >= 0.8) return "bg-green-500";
  if (confidence >= 0.5) return "bg-yellow-500";
  return "bg-red-500";
}

/**
 * データ移行ウィザードページ
 * 5ステップ: ソース選択 → ファイルアップロード → マッピング確認 → プレビュー → 実行＆結果
 */
export default function ImportWizardPage() {
  const [step, setStep] = useState(1);
  const [sourceType, setSourceType] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [importJob, setImportJob] = useState<ImportJob | null>(null);
  const [mappings, setMappings] = useState<MappingItem[]>([]);
  const [preview, setPreview] = useState<Record<string, string>[]>([]);
  const [totalRows, setTotalRows] = useState(0);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [executing, setExecuting] = useState(false);
  const [polling, setPolling] = useState(false);

  /**
   * ファイルをアップロードしてインポートジョブを作成する
   */
  const handleUpload = async () => {
    if (!file || !sourceType) return;
    setUploading(true);
    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("source_type", sourceType);
      const data = await api.upload<{ import_job: ImportJob }>("/api/v1/imports", formData);
      setImportJob(data.import_job);
      setMappings(data.import_job.column_mapping || []);
      setStep(3);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "アップロードに失敗しました");
      }
    } finally {
      setUploading(false);
    }
  };

  /**
   * プレビューデータを取得する
   */
  const handlePreview = async () => {
    if (!importJob) return;
    setLoadingPreview(true);
    try {
      // マッピング変更を保存
      await api.patch(`/api/v1/imports/${importJob.uuid}/mapping`, { mappings });

      const data = await api.get<{ preview: Record<string, string>[]; total_rows: number }>(
        `/api/v1/imports/${importJob.uuid}/preview`
      );
      setPreview(data.preview);
      setTotalRows(data.total_rows);
      setStep(4);
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "プレビューの取得に失敗しました");
      }
    } finally {
      setLoadingPreview(false);
    }
  };

  /**
   * インポートを実行する
   */
  const handleExecute = async () => {
    if (!importJob) return;
    setExecuting(true);
    try {
      await api.post(`/api/v1/imports/${importJob.uuid}/execute`, {});
      setStep(5);
      pollResult();
    } catch (e) {
      if (e instanceof ApiClientError) {
        toast.error(e.body?.error?.message || "実行に失敗しました");
      }
      setExecuting(false);
    }
  };

  /**
   * インポート結果をポーリングする
   */
  const pollResult = useCallback(async () => {
    if (!importJob) return;
    setPolling(true);

    const maxAttempts = 30;
    for (let i = 0; i < maxAttempts; i++) {
      try {
        const data = await api.get<{ import_job: ImportJob }>(
          `/api/v1/imports/${importJob.uuid}/result`
        );
        if (data.import_job.status === "completed" || data.import_job.status === "failed") {
          setImportJob(data.import_job);
          setPolling(false);
          setExecuting(false);
          return;
        }
      } catch {
        // ignore
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
    setPolling(false);
    setExecuting(false);
    toast.error("タイムアウト: インポート結果を確認してください");
  }, [importJob]);

  /**
   * マッピングのターゲットカラムを変更する
   * @param index - マッピングのインデックス
   * @param value - 新しい "table.column" 値
   */
  const updateMapping = (index: number, value: string) => {
    const parts = value.split(".");
    const table = parts[0] ?? null;
    const column = parts[1] ?? null;
    setMappings((prev) =>
      prev.map((m, i) =>
        i === index ? { ...m, target_table: table, target_column: column, confidence: 1.0, method: "manual" } : m
      )
    );
  };

  /**
   * ウィザードをリセットする
   */
  const resetWizard = () => {
    setStep(1);
    setSourceType("");
    setFile(null);
    setImportJob(null);
    setMappings([]);
    setPreview([]);
    setTotalRows(0);
    setExecuting(false);
    setPolling(false);
  };

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">データ移行</h1>
        <p className="text-sm text-muted-foreground">
          他サービスからのデータをインポートします
        </p>
      </div>

      {/* ステップインジケーター */}
      <div className="flex items-center gap-2">
        {["移行元選択", "ファイル", "マッピング", "プレビュー", "結果"].map((label, i) => (
          <div key={label} className="flex items-center gap-2">
            <div className={`flex size-8 items-center justify-center rounded-full text-sm font-medium ${
              step > i + 1 ? "bg-primary text-primary-foreground" :
              step === i + 1 ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
            }`}>
              {step > i + 1 ? <Check className="size-4" /> : i + 1}
            </div>
            <span className={`text-sm hidden sm:inline ${step === i + 1 ? "font-medium" : "text-muted-foreground"}`}>
              {label}
            </span>
            {i < 4 && <ArrowRight className="size-4 text-muted-foreground" />}
          </div>
        ))}
      </div>

      {/* Step 1: ソース選択 */}
      {step === 1 && (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold">移行元を選択</h2>
          <div className="grid gap-4 sm:grid-cols-3">
            {SOURCE_TYPES.map((src) => (
              <Card
                key={src.value}
                className={`cursor-pointer transition-colors hover:border-primary ${
                  sourceType === src.value ? "border-primary ring-2 ring-primary/20" : ""
                }`}
                onClick={() => setSourceType(src.value)}
              >
                <CardContent className="flex flex-col items-center gap-3 pt-6 pb-4">
                  <src.icon className="size-12 text-muted-foreground" />
                  <h3 className="font-semibold">{src.label}</h3>
                  <p className="text-xs text-muted-foreground text-center">{src.description}</p>
                </CardContent>
              </Card>
            ))}
          </div>
          <div className="flex justify-end">
            <Button onClick={() => setStep(2)} disabled={!sourceType}>
              次へ
              <ArrowRight className="ml-2 size-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Step 2: ファイルアップロード */}
      {step === 2 && (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold">ファイルをアップロード</h2>
          <div
            className={`rounded-lg border-2 border-dashed p-12 text-center transition-colors ${
              file ? "border-primary bg-primary/5" : "border-muted-foreground/25 hover:border-muted-foreground/50"
            }`}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const f = e.dataTransfer.files[0];
              if (f) setFile(f);
            }}
          >
            {file ? (
              <div className="space-y-2">
                <FileSpreadsheet className="mx-auto size-12 text-primary" />
                <p className="font-medium">{file.name}</p>
                <p className="text-sm text-muted-foreground">
                  {(file.size / 1024).toFixed(1)} KB
                </p>
                <Button variant="outline" size="sm" onClick={() => setFile(null)}>
                  変更
                </Button>
              </div>
            ) : (
              <div className="space-y-2">
                <Upload className="mx-auto size-12 text-muted-foreground/50" />
                <p className="text-muted-foreground">
                  ファイルをドラッグ＆ドロップ、または
                </p>
                <label className="inline-block">
                  <input
                    type="file"
                    accept=".csv,.xlsx,.xls"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) setFile(f);
                    }}
                  />
                  <Button variant="outline" asChild>
                    <span>ファイルを選択</span>
                  </Button>
                </label>
              </div>
            )}
          </div>
          <div className="flex justify-between">
            <Button variant="outline" onClick={() => setStep(1)}>
              <ArrowLeft className="mr-2 size-4" />
              戻る
            </Button>
            <Button onClick={handleUpload} disabled={!file || uploading}>
              {uploading ? (
                <>
                  <Loader2 className="mr-2 size-4 animate-spin" />
                  解析中...
                </>
              ) : (
                <>
                  アップロード
                  <ArrowRight className="ml-2 size-4" />
                </>
              )}
            </Button>
          </div>
        </div>
      )}

      {/* Step 3: マッピング確認 */}
      {step === 3 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">カラムマッピング確認</h2>
            {importJob?.ai_mapping_confidence && (
              <Badge variant="outline">
                AI確信度: {(Number(importJob.ai_mapping_confidence) * 100).toFixed(0)}%
              </Badge>
            )}
          </div>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>元カラム</TableHead>
                  <TableHead>マッピング先</TableHead>
                  <TableHead className="w-[120px]">確信度</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {mappings.map((m, i) => (
                  <TableRow key={i}>
                    <TableCell className="font-medium">{m.source}</TableCell>
                    <TableCell>
                      <Select
                        value={m.target_table && m.target_column ? `${m.target_table}.${m.target_column}` : "skip"}
                        onValueChange={(v) => {
                          if (v === "skip") {
                            setMappings((prev) =>
                              prev.map((item, idx) =>
                                idx === i ? { ...item, target_table: null, target_column: null, confidence: 0 } : item
                              )
                            );
                          } else {
                            updateMapping(i, v);
                          }
                        }}
                      >
                        <SelectTrigger className="w-[280px]">
                          <SelectValue placeholder="マッピング先を選択" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="skip">スキップ</SelectItem>
                          {Object.entries(TARGET_OPTIONS).map(([table, columns]) =>
                            columns.map((col) => (
                              <SelectItem key={`${table}.${col}`} value={`${table}.${col}`}>
                                {TABLE_LABELS[table] || table} &gt; {col}
                              </SelectItem>
                            ))
                          )}
                        </SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <div className="h-2 w-16 overflow-hidden rounded-full bg-muted">
                          <div
                            className={`h-full ${confidenceBg(m.confidence)}`}
                            style={{ width: `${m.confidence * 100}%` }}
                          />
                        </div>
                        <span className={`text-xs font-medium ${confidenceColor(m.confidence)}`}>
                          {(m.confidence * 100).toFixed(0)}%
                        </span>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          <div className="flex justify-between">
            <Button variant="outline" onClick={() => setStep(2)}>
              <ArrowLeft className="mr-2 size-4" />
              戻る
            </Button>
            <Button onClick={handlePreview} disabled={loadingPreview}>
              {loadingPreview ? (
                <>
                  <Loader2 className="mr-2 size-4 animate-spin" />
                  プレビュー生成中...
                </>
              ) : (
                <>
                  プレビュー
                  <ArrowRight className="ml-2 size-4" />
                </>
              )}
            </Button>
          </div>
        </div>
      )}

      {/* Step 4: プレビュー */}
      {step === 4 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">プレビュー</h2>
            <span className="text-sm text-muted-foreground">
              先頭 {Math.min(10, totalRows)}件 / 全{totalRows}件
            </span>
          </div>
          {preview.length > 0 && preview[0] != null && (
            <div className="rounded-md border overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    {Object.keys(preview[0]).map((key) => (
                      <TableHead key={key}>{key}</TableHead>
                    ))}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {preview.map((row, i) => (
                    <TableRow key={i}>
                      {Object.values(row).map((val, j) => (
                        <TableCell key={j}>{val || "-"}</TableCell>
                      ))}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
          <div className="flex justify-between">
            <Button variant="outline" onClick={() => setStep(3)}>
              <ArrowLeft className="mr-2 size-4" />
              マッピング修正
            </Button>
            <Button onClick={handleExecute} disabled={executing}>
              {executing ? (
                <>
                  <Loader2 className="mr-2 size-4 animate-spin" />
                  実行中...
                </>
              ) : (
                <>
                  インポート実行
                  <ArrowRight className="ml-2 size-4" />
                </>
              )}
            </Button>
          </div>
        </div>
      )}

      {/* Step 5: 結果 */}
      {step === 5 && (
        <div className="space-y-4">
          <h2 className="text-lg font-semibold">インポート結果</h2>

          {polling ? (
            <Card>
              <CardContent className="flex flex-col items-center gap-4 py-12">
                <Loader2 className="size-12 animate-spin text-primary" />
                <p className="text-muted-foreground">インポートを実行中...</p>
                <Progress value={undefined} className="w-64" />
              </CardContent>
            </Card>
          ) : importJob?.import_stats ? (
            <>
              <div className="grid gap-4 sm:grid-cols-4">
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium">合計行数</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold">{importJob.import_stats.total_rows}</div>
                  </CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium text-green-600">成功</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-green-600">{importJob.import_stats.success_count}</div>
                  </CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium text-yellow-600">スキップ</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-yellow-600">{importJob.import_stats.skip_count}</div>
                  </CardContent>
                </Card>
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium text-destructive">エラー</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold text-destructive">{importJob.import_stats.error_count}</div>
                  </CardContent>
                </Card>
              </div>

              {importJob.error_details && importJob.error_details.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <AlertCircle className="size-4 text-destructive" />
                      エラー詳細
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="rounded-md border">
                      <Table>
                        <TableHeader>
                          <TableRow>
                            <TableHead className="w-[80px]">行</TableHead>
                            <TableHead>エラー内容</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {importJob.error_details.map((err, i) => (
                            <TableRow key={i}>
                              <TableCell className="font-mono text-sm">{err.row}</TableCell>
                              <TableCell className="text-sm text-destructive">{err.message}</TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </div>
                  </CardContent>
                </Card>
              )}
            </>
          ) : (
            <Card>
              <CardContent className="py-12 text-center text-muted-foreground">
                結果を取得できませんでした
              </CardContent>
            </Card>
          )}

          <div className="flex justify-end">
            <Button onClick={resetWizard}>
              新しいインポートを開始
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
