export interface AcademicYear {
  startYear: number
  endYear: number
}

export function academicYearForDate(date: Date): AcademicYear {
  const year = date.getFullYear()
  const startYear = date.getMonth() < 8 ? year - 1 : year
  return { startYear, endYear: startYear + 1 }
}

export function academicCalendarURL(date: Date) {
  const { startYear, endYear } = academicYearForDate(date)
  return `https://jwc.cuit.edu.cn/xl${startYear}_${endYear}.png`
}
