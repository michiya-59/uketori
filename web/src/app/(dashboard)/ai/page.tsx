"use client";

import { useEffect, useState, useCallback } from "react";
import {
  Sparkles,
  TrendingUp,
  UserSearch,
  Loader2,
  ChevronRight,
  AlertCircle,
  ArrowUpRight,
  ArrowDownRight,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  Line,
  ComposedChart,
  Area,
} from "recharts";
import { api } from "@/lib/api-client";
import { toast } from "sonner";

/**
 * 金額をフォーマットする
 * @param amount - 金額
 * @returns フォーマット済み文字列
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("ja-JP", {
    style: "currency",
    currency: "JPY",
    maximumFractionDigits: 0,
  }).format(amount);
}

/** 売上予測レスポンス型 */
interface ForecastResponse {
  historical: Array<{ month: string; invoiced: number; collected: number; count: number }>;
  pipeline: Array<{ name: string; amount: number; probability: number; status: string; expected_date: string | null }>;
  forecast: Array<{
    month: string;
    predicted: number;
    pipeline_amount: number;
    lower_bound: number;
    upper_bound: number;
    trend_factor: number;
    seasonality_factor: number;
  }>;
  commentary: string;
  confidence: number;
}

/** 取引先分析レスポンス型 */
interface CustomerAnalysisResponse {
  customer_id: string;
  company_name: string;
  statistics: {
    total_invoiced: number;
    total_paid: number;
    total_outstanding: number;
    invoice_count: number;
    overdue_count: number;
    overdue_rate: number;
    avg_payment_days: number;
    last_6m_invoiced: number;
    last_6m_count: number;
    first_transaction_date: string | null;
    last_transaction_date: string | null;
  };
  payment_history: Array<{
    month: string;
    invoiced: number;
    paid: number;
    overdue_amount: number;
  }>;
  credit_score: number | null;
  credit_score_trend: Array<{ date: string; score: number }>;
  risk_assessment: string;
  summary: string;
  recommendations: string[];
  confidence: number;
}

/** 顧客一覧型 */
interface CustomerListItem {
  id: string;
  company_name: string;
  credit_score: number | null;
  total_outstanding: number;
}

/** リスクレベルラベル */
const RISK_LABELS: Record<string, { label: string; color: string }> = {
  low: { label: "低リスク", color: "bg-green-100 text-green-800" },
  medium: { label: "注意", color: "bg-yellow-100 text-yellow-800" },
  high: { label: "警戒", color: "bg-orange-100 text-orange-800" },
  critical: { label: "危険", color: "bg-red-100 text-red-800" },
};

/**
 * AI機能統合ページ
 * AI売上予測・AI書類OCR・AI取引先分析の3つの機能を提供する
 * @returns AI機能ページ要素
 */
export default function AiPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
          <Sparkles className="size-6 text-primary" />
          AI機能
        </h1>
        <p className="mt-1 text-muted-foreground">
          AIを活用した売上予測・取引先分析
        </p>
      </div>

      <Tabs defaultValue="forecast" className="space-y-6">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="forecast" className="flex items-center gap-2">
            <TrendingUp className="size-4" />
            売上予測
          </TabsTrigger>
          <TabsTrigger value="analysis" className="flex items-center gap-2">
            <UserSearch className="size-4" />
            取引先分析
          </TabsTrigger>
        </TabsList>

        <TabsContent value="forecast">
          <RevenueForecastTab />
        </TabsContent>

        <TabsContent value="analysis">
          <CustomerAnalysisTab />
        </TabsContent>
      </Tabs>
    </div>
  );
}

/**
 * AI売上予測タブ
 * @returns 売上予測タブ要素
 */
function RevenueForecastTab() {
  const [data, setData] = useState<ForecastResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [months, setMonths] = useState("3");

  const fetchForecast = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.post<ForecastResponse>("/api/v1/ai/revenue_forecast", { months: Number(months) });
      setData(res);
    } catch {
      toast.error("売上予測の取得に失敗しました");
    } finally {
      setLoading(false);
    }
  }, [months]);

  /** 過去データと予測データを結合してチャート用データを生成する */
  const chartData = data ? [
    ...data.historical.slice(-6).map((h) => ({
      month: h.month,
      実績: h.invoiced,
      回収: h.collected,
    })),
    ...data.forecast.map((f) => ({
      month: f.month,
      予測: f.predicted,
      下限: f.lower_bound,
      上限: f.upper_bound,
    })),
  ] : [];

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TrendingUp className="size-5 text-primary" />
            AI売上予測
          </CardTitle>
          <CardDescription>
            過去の売上実績とパイプラインデータからAIが売上を予測します
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-end gap-4">
            <div className="space-y-2">
              <Label>予測月数</Label>
              <Select value={months} onValueChange={setMonths}>
                <SelectTrigger className="w-[180px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="1">1ヶ月</SelectItem>
                  <SelectItem value="3">3ヶ月</SelectItem>
                  <SelectItem value="6">6ヶ月</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <Button onClick={fetchForecast} disabled={loading}>
              {loading ? <Loader2 className="size-4 animate-spin mr-2" /> : <Sparkles className="size-4 mr-2" />}
              予測を実行
            </Button>
          </div>
        </CardContent>
      </Card>

      {data && (
        <>
          {/* AIコメント */}
          <Card className="border-primary/20 bg-primary/5">
            <CardContent className="py-4">
              <div className="flex items-start gap-3">
                <Sparkles className="size-5 text-primary mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-medium text-primary mb-1">AIによる分析コメント</p>
                  <p className="text-sm">{data.commentary}</p>
                  <Badge variant="outline" className="mt-2">
                    確信度: {(data.confidence * 100).toFixed(0)}%
                  </Badge>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* チャート */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">売上推移と予測</CardTitle>
              <CardDescription>過去6ヶ月の実績と今後の予測</CardDescription>
            </CardHeader>
            <CardContent>
              {chartData.length > 0 ? (
                <ResponsiveContainer width="100%" height={350}>
                  <ComposedChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="month" fontSize={12} tickLine={false} axisLine={false} />
                    <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(v: number) => `${(v / 10000).toFixed(0)}万`} />
                    <Tooltip formatter={(value) => formatCurrency(Number(value))} />
                    <Legend />
                    <Bar dataKey="実績" fill="hsl(220 70% 55%)" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="回収" fill="hsl(160 60% 45%)" radius={[4, 4, 0, 0]} />
                    <Line type="monotone" dataKey="予測" stroke="hsl(280 70% 55%)" strokeWidth={2} strokeDasharray="5 5" dot={{ r: 4 }} />
                    <Area type="monotone" dataKey="上限" stroke="none" fill="hsl(280 70% 55%)" fillOpacity={0.1} />
                  </ComposedChart>
                </ResponsiveContainer>
              ) : (
                <p className="py-16 text-center text-muted-foreground">データがありません</p>
              )}
            </CardContent>
          </Card>

          {/* 予測テーブル */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">月別予測詳細</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>月</TableHead>
                    <TableHead className="text-right">予測売上</TableHead>
                    <TableHead className="text-right">パイプライン</TableHead>
                    <TableHead className="text-right">下限</TableHead>
                    <TableHead className="text-right">上限</TableHead>
                    <TableHead className="text-right">トレンド</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.forecast.map((f) => (
                    <TableRow key={f.month}>
                      <TableCell className="font-medium">{f.month}</TableCell>
                      <TableCell className="text-right font-semibold">{formatCurrency(f.predicted)}</TableCell>
                      <TableCell className="text-right">{formatCurrency(f.pipeline_amount)}</TableCell>
                      <TableCell className="text-right text-muted-foreground">{formatCurrency(f.lower_bound)}</TableCell>
                      <TableCell className="text-right text-muted-foreground">{formatCurrency(f.upper_bound)}</TableCell>
                      <TableCell className="text-right">
                        {f.trend_factor >= 1 ? (
                          <span className="text-green-600 flex items-center justify-end gap-1">
                            <ArrowUpRight className="size-3" />
                            {((f.trend_factor - 1) * 100).toFixed(1)}%
                          </span>
                        ) : (
                          <span className="text-red-600 flex items-center justify-end gap-1">
                            <ArrowDownRight className="size-3" />
                            {((1 - f.trend_factor) * 100).toFixed(1)}%
                          </span>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

/**
 * AI取引先分析タブ
 * @returns 取引先分析タブ要素
 */
function CustomerAnalysisTab() {
  const [customers, setCustomers] = useState<CustomerListItem[]>([]);
  const [selectedId, setSelectedId] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<CustomerAnalysisResponse | null>(null);

  useEffect(() => {
    const fetchCustomers = async () => {
      try {
        const res = await api.get<{ customers: CustomerListItem[] }>("/api/v1/customers", { per_page: 100 });
        setCustomers(res.customers);
      } catch {
        // silent
      }
    };
    fetchCustomers();
  }, []);

  /**
   * 取引先分析を実行する
   */
  const runAnalysis = async () => {
    if (!selectedId) return;
    try {
      setLoading(true);
      setResult(null);
      const res = await api.get<CustomerAnalysisResponse>(`/api/v1/ai/customer_analysis/${selectedId}`);
      setResult(res);
    } catch {
      toast.error("取引先分析に失敗しました");
    } finally {
      setLoading(false);
    }
  };

  const riskInfo = result ? RISK_LABELS[result.risk_assessment] ?? RISK_LABELS.medium : null;

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <UserSearch className="size-5 text-primary" />
            AI取引先分析
          </CardTitle>
          <CardDescription>
            取引先の支払い傾向・リスク・推奨アクションをAIが分析します
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-end gap-4">
            <div className="space-y-2 flex-1 max-w-md">
              <Label>取引先を選択</Label>
              <Select value={selectedId} onValueChange={setSelectedId}>
                <SelectTrigger>
                  <SelectValue placeholder="取引先を選択してください" />
                </SelectTrigger>
                <SelectContent>
                  {customers.map((c) => (
                    <SelectItem key={c.id} value={c.id}>
                      {c.company_name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button onClick={runAnalysis} disabled={loading || !selectedId}>
              {loading ? <Loader2 className="size-4 animate-spin mr-2" /> : <Sparkles className="size-4 mr-2" />}
              分析を実行
            </Button>
          </div>
        </CardContent>
      </Card>

      {result && (
        <>
          {/* AIサマリー */}
          <Card className="border-primary/20 bg-primary/5">
            <CardContent className="py-4">
              <div className="flex items-start gap-3">
                <Sparkles className="size-5 text-primary mt-0.5 shrink-0" />
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <p className="text-sm font-medium text-primary">AI分析結果: {result.company_name}</p>
                    {riskInfo && (
                      <Badge className={riskInfo.color}>{riskInfo.label}</Badge>
                    )}
                    <Badge variant="outline">確信度: {(result.confidence * 100).toFixed(0)}%</Badge>
                  </div>
                  <p className="text-sm">{result.summary}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* KPIカード */}
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">累計請求額</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xl font-bold">{formatCurrency(result.statistics.total_invoiced)}</p>
                <p className="text-xs text-muted-foreground mt-1">{result.statistics.invoice_count}件</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">未回収残高</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xl font-bold">{formatCurrency(result.statistics.total_outstanding)}</p>
                <p className="text-xs text-muted-foreground mt-1">遅延{result.statistics.overdue_count}件</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">与信スコア</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xl font-bold">{result.credit_score ?? "-"}<span className="text-sm font-normal text-muted-foreground">/100</span></p>
                <p className="text-xs text-muted-foreground mt-1">遅延率 {result.statistics.overdue_rate}%</p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm text-muted-foreground">平均支払日数</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-xl font-bold">{result.statistics.avg_payment_days}<span className="text-sm font-normal text-muted-foreground">日</span></p>
              </CardContent>
            </Card>
          </div>

          {/* 推奨アクション */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <AlertCircle className="size-5 text-primary" />
                推奨アクション
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2">
                {result.recommendations.map((rec, idx) => (
                  <li key={idx} className="flex items-start gap-2">
                    <ChevronRight className="size-4 text-primary mt-0.5 shrink-0" />
                    <span className="text-sm">{rec}</span>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>

          {/* 月次取引履歴チャート */}
          {result.payment_history.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">月次取引推移</CardTitle>
                <CardDescription>直近12ヶ月の請求額と入金額</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={result.payment_history}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="month" fontSize={12} tickLine={false} axisLine={false} />
                    <YAxis fontSize={12} tickLine={false} axisLine={false} tickFormatter={(v: number) => `${(v / 10000).toFixed(0)}万`} />
                    <Tooltip formatter={(value) => formatCurrency(Number(value))} />
                    <Legend />
                    <Bar dataKey="invoiced" name="請求額" fill="hsl(220 70% 55%)" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="paid" name="入金額" fill="hsl(160 60% 45%)" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}
