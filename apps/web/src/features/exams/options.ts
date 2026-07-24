import type { ExamBatch } from './api'

// 页面只展示稳定的业务类型；每个学期真实的 EAMS 批次 ID 由后端查询时解析。
export const examBatches: ExamBatch[] = [
  { ID: 'final', Name: '期末考试' },
  { ID: 'makeup', Name: '开学补考' },
]
