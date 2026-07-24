import type { Grade } from '../api'

export type GradeScoreTone = 'failed' | 'normal'

export function displayGradeScore(grade: Grade) {
  return grade.FinalScore || grade.OverallScore || ''
}

export function gradeScoreTone(grade: Grade): GradeScoreTone {
  const score = Number.parseFloat(displayGradeScore(grade))
  return !Number.isNaN(score) && score < 60 ? 'failed' : 'normal'
}

export function countPublishedGrades(grades: Grade[]) {
  return grades.filter((grade) => displayGradeScore(grade)).length
}

export function countFailedGrades(grades: Grade[]) {
  return grades.filter((grade) => gradeScoreTone(grade) === 'failed').length
}
