import { describe, expect, it } from 'vitest'

import {
  browsePastExamDirectory,
  formatPastExamSize,
  parentPastExamDirectory,
  parsePastExamsIndex,
  pastExamBreadcrumbs,
  pastExamFileProxyPath,
  searchPastExamFiles,
  type PastExamFile,
} from './model'

const files: PastExamFile[] = [
  { path: '数据结构/2023/A卷.pdf', name: 'A卷.pdf', extension: 'pdf', size: 2_048 },
  { path: '数据结构/2023/答案.docx', name: '答案.docx', extension: 'docx', size: 4_096 },
  { path: '数据结构/2022/试题.pdf', name: '试题.pdf', extension: 'pdf', size: 1_024 },
  { path: '操作系统/期末真题.jpg', name: '期末真题.jpg', extension: 'jpg', size: 512 },
]

describe('历年试卷目录模型', () => {
  it('按当前路径汇总直属文件夹和文件', () => {
    expect(browsePastExamDirectory(files, '')).toEqual([
      {
        type: 'directory',
        name: '操作系统',
        path: '操作系统',
        fileCount: 1,
        totalBytes: 512,
      },
      {
        type: 'directory',
        name: '数据结构',
        path: '数据结构',
        fileCount: 3,
        totalBytes: 7_168,
      },
    ])
    expect(browsePastExamDirectory(files, '数据结构/2023')).toEqual([
      { ...files[1], type: 'file' },
      { ...files[0], type: 'file' },
    ])
  })

  it('支持多关键词搜索并生成面包屑', () => {
    expect(searchPastExamFiles(files, '数据结构 答案')).toEqual([files[1]])
    expect(pastExamBreadcrumbs('数据结构/2023')).toEqual([
      { label: '全部课程', path: '' },
      { label: '数据结构', path: '数据结构' },
      { label: '2023', path: '数据结构/2023' },
    ])
    expect(parentPastExamDirectory('数据结构/2023')).toBe('数据结构')
  })

  it('生成固定 commit 的安全代理路径', () => {
    expect(
      pastExamFileProxyPath(
        'e75cb68572992fef61064b29c82713a19e7b8aef',
        '数据结构/一堆卷子/历年题.pdf',
      ),
    ).toBe(
      '/past-exams/files/e75cb68572992fef61064b29c82713a19e7b8aef/%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84/%E4%B8%80%E5%A0%86%E5%8D%B7%E5%AD%90/%E5%8E%86%E5%B9%B4%E9%A2%98.pdf',
    )
    expect(() =>
      pastExamFileProxyPath('main', '数据结构/试卷.pdf'),
    ).toThrow('资料版本号无效')
  })

  it('校验索引统计并格式化大小', () => {
    const value = {
      schemaVersion: 1,
      repository: 'andream7/cuit_sharing',
      branch: 'main',
      commit: 'e75cb68572992fef61064b29c82713a19e7b8aef',
      updatedAt: '2025-07-22T08:30:04.000Z',
      sourceURL: 'https://github.com/andream7/cuit_sharing',
      totalFiles: 1,
      totalBytes: 2_048,
      files: [files[0]],
    }
    expect(parsePastExamsIndex(value).files).toEqual([files[0]])
    expect(() => parsePastExamsIndex({ ...value, totalFiles: 2 })).toThrow(
      '资料目录统计信息不一致',
    )
    expect(formatPastExamSize(2_048)).toBe('2 KB')
    expect(formatPastExamSize(4_718_592)).toBe('4.5 MB')
  })
})
