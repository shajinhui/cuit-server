import { describe, expect, it } from 'vitest'

import type { PlanCompletionItem } from './api'
import { completionStatusTone, creditProgress, groupPlanCompletionItems } from './model'

const requirement: PlanCompletionItem = {
  Kind: 'requirement',
  Sequence: '',
  CourseCode: '',
  Name: '必修课程',
  RequiredCredits: '10',
  EarnedCredits: '8',
  Score: '',
  Status: '缺 2 学分',
  Remark: '',
}

const course: PlanCompletionItem = {
  Kind: 'course',
  Sequence: '1',
  CourseCode: 'TEST001',
  Name: '测试课程',
  RequiredCredits: '2',
  EarnedCredits: '2',
  Score: '80',
  Status: '是',
  Remark: '',
}

describe('creditProgress', () => {
  it('根据要求学分和实修学分计算并限制完成度', () => {
    expect(creditProgress('160', '100')).toBe(62.5)
    expect(creditProgress('2', '3')).toBe(100)
  })

  it('无效学分不生成误导性的完成度', () => {
    expect(creditProgress('', '10')).toBeNull()
    expect(creditProgress('0', '0')).toBeNull()
  })
})

describe('completionStatusTone', () => {
  it('先识别未完成状态，避免把未通过判断为通过', () => {
    expect(completionStatusTone('未通过')).toBe('incomplete')
    expect(completionStatusTone('缺 2 学分')).toBe('incomplete')
    expect(completionStatusTone('预审通过')).toBe('complete')
    expect(completionStatusTone('是')).toBe('complete')
  })
})

describe('groupPlanCompletionItems', () => {
  it('按教务原始顺序把课程归入最近的要求分类', () => {
    const groups = groupPlanCompletionItems([requirement, course])

    expect(groups).toHaveLength(1)
    expect(groups[0].requirement?.Name).toBe('必修课程')
    expect(groups[0].courses[0].CourseCode).toBe('TEST001')
  })

  it('保留出现在第一个要求分类前的课程', () => {
    const groups = groupPlanCompletionItems([course, requirement])

    expect(groups).toHaveLength(2)
    expect(groups[0].requirement).toBeNull()
    expect(groups[0].courses).toEqual([course])
  })
})
