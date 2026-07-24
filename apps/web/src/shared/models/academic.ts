export interface Semester {
  ID: string
  SchoolYear: string
  Term: string
  Current?: boolean
}

export function compareSemestersNewestFirst(left: Semester, right: Semester) {
  const schoolYearOrder = right.SchoolYear.localeCompare(left.SchoolYear, 'zh-CN', { numeric: true })
  if (schoolYearOrder !== 0) return schoolYearOrder

  const leftTerm = Number.parseInt(left.Term, 10)
  const rightTerm = Number.parseInt(right.Term, 10)
  if (!Number.isNaN(leftTerm) && !Number.isNaN(rightTerm)) return rightTerm - leftTerm

  return right.Term.localeCompare(left.Term, 'zh-CN', { numeric: true })
}

export function findCurrentSemester(semesters: Semester[], referenceDate = new Date()) {
  const markedCurrent = semesters.find((semester) => semester.Current)
  if (markedCurrent) return markedCurrent

  const month = referenceDate.getMonth() + 1
  const year = referenceDate.getFullYear()
  const academicStartYear = month >= 9 ? year : year - 1
  const schoolYear = `${academicStartYear}-${academicStartYear + 1}`
  const term = month === 1 || month >= 9 ? 1 : 2

  return (
    semesters.find(
      (semester) =>
        semester.SchoolYear === schoolYear &&
        Number.parseInt(semester.Term, 10) === term,
    ) ?? semesters[0]
  )
}
