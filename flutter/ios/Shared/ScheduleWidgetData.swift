import Foundation

// 与 Dart 的 desktop_widget_snapshot.dart 对应；原生端不重复排课规则。
struct WidgetCourse: Codable, Identifiable {
    let id: String
    let name: String
    let room: String
    let time: String
    let startMillis: Double?
    let endMillis: Double?

    func ongoing(at date: Date) -> Bool {
        guard let start = startMillis, let end = endMillis else { return false }
        let now = date.timeIntervalSince1970 * 1000
        return start <= now && now < end
    }
}

struct WidgetDay: Codable {
    let date: String
    let week: Int
    let courses: [WidgetCourse]
}

struct ScheduleWidgetSnapshot: Codable {
    let version: Int
    let status: String
    let message: String
    let days: [WidgetDay]

    static let empty = ScheduleWidgetSnapshot(
        version: 1, status: "loggedOut", message: "登录后查看今日课程", days: []
    )

    func state(at date: Date) -> ScheduleWidgetState {
        if version != 1 || status != "ready" {
            return ScheduleWidgetState(week: 0, courses: [], message: message.isEmpty ? "打开应用同步课表" : message)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Self.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let day = days.first(where: { $0.date == formatter.string(from: date) }) else {
            return ScheduleWidgetState(week: 0, courses: [], message: "当前不在已同步的教学周内")
        }
        let now = date.timeIntervalSince1970 * 1000
        let remaining = day.courses.filter { ($0.endMillis ?? Double.greatestFiniteMagnitude) > now }
        let message = day.courses.isEmpty ? "今天没有课程\n好好休息" : remaining.isEmpty ? "今日课程已结束" : ""
        return ScheduleWidgetState(week: day.week, courses: remaining, message: message)
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    static func nextMidnight(after date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }

    // 预先提供上下课和换日的条目，不依赖 Flutter 在后台持续运行。
    func timelineDates(after now: Date) -> [Date] {
        let midnight = Self.nextMidnight(after: now)
        var dates: Set<Date> = [now, midnight]
        for course in days.flatMap(\.courses) {
            for millis in [course.startMillis, course.endMillis].compactMap({ $0 }) {
                let date = Date(timeIntervalSince1970: millis / 1000)
                if date > now && date < midnight { dates.insert(date) }
            }
        }
        return dates.sorted()
    }
}

struct ScheduleWidgetState {
    let week: Int
    let courses: [WidgetCourse]
    let message: String
}

enum ScheduleWidgetStore {
    static let group = "group.org.dpdns.fanxiaogao05.chengxin.flutter"
    static let kind = "ChengxinScheduleWidget"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("schedule-widget-v1.json")
    }

    static func read() -> ScheduleWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ScheduleWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
