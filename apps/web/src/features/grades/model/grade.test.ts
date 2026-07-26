import { describe, expect, it } from 'vitest'

import type { Grade } from '../api'
import {
  countFailedGrades,
  countPublishedGrades,
  displayGradeScore,
  gradeScoreTone,
} from './grade'

describe('grade model', () => {
  it('uses final score before overall score', () => {
    expect(displayGradeScore(createGrade({ FinalScore: '88', OverallScore: '85' }))).toBe('88')
    expect(displayGradeScore(createGrade({ OverallScore: '85' }))).toBe('85')
    expect(displayGradeScore(createGrade())).toBe('')
  })

  it('marks only numeric scores below 60 as failed', () => {
    expect(gradeScoreTone(createGrade({ FinalScore: '59' }))).toBe('failed')
    expect(gradeScoreTone(createGrade({ FinalScore: '60' }))).toBe('normal')
    expect(gradeScoreTone(createGrade({ FinalScore: '合格' }))).toBe('normal')
  })

  it('counts published and failed grades independently', () => {
    const grades = [
      createGrade({ FinalScore: '59' }),
      createGrade({ OverallScore: '合格' }),
      createGrade(),
    ]

    expect(countPublishedGrades(grades)).toBe(2)
    expect(countFailedGrades(grades)).toBe(1)
  })
})

function createGrade(overrides: Partial<Grade> = {}): Grade {
  return {
    SchoolYearTerm: '',
    CourseCode: '',
    CourseSequence: '',
    CourseName: '',
    CourseCategory: '',
    Credits: '',
    UsualScore: '',
    FinalExamScore: '',
    MakeupScore: '',
    OverallScore: '',
    FinalScore: '',
    GradePoint: '',
    ...overrides,
  }
}
