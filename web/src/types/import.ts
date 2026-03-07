/** インポート元サービス種別 */
export type ImportSourceType =
  | 'board'
  | 'freee'
  | 'misoca'
  | 'makeleaps'
  | 'excel'
  | 'csv_generic'

/** インポートジョブステータス */
export type ImportJobStatus =
  | 'pending'
  | 'parsing'
  | 'mapping'
  | 'previewing'
  | 'importing'
  | 'completed'
  | 'failed'

/** インポート統計情報 */
export interface ImportStats {
  total_rows: number
  success_count: number
  error_count: number
  skip_count: number
}

/** インポートエラー詳細 */
export interface ImportErrorDetail {
  row: number
  column: string
  message: string
}

/** インポートジョブ */
export interface ImportJob {
  uuid: string
  user_uuid: string
  source_type: ImportSourceType
  status: ImportJobStatus
  file_url: string
  file_name: string
  file_size: number
  parsed_data: Record<string, unknown>[] | null
  column_mapping: Record<string, string> | null
  preview_data: Record<string, unknown>[] | null
  import_stats: ImportStats | null
  error_details: ImportErrorDetail[] | null
  ai_mapping_confidence: number | null
  started_at: string | null
  completed_at: string | null
  created_at: string
  updated_at: string
}

/** カラムマッピング定義 */
export interface ColumnMapping {
  id: number
  source_type: ImportSourceType
  source_column_name: string
  target_table: string
  target_column: string
  transform_rule: string | null
  is_required: boolean
}

/** インポートジョブ作成リクエスト */
export interface ImportJobCreateRequest {
  source_type: ImportSourceType
  file: File
}

/** カラムマッピング更新リクエスト */
export interface ColumnMappingUpdateRequest {
  column_mapping: Record<string, string>
}
