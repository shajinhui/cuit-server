import SwiftUI
import WidgetKit

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let state: ScheduleWidgetState
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        let now = Date()
        let course = WidgetCourse(id: "preview", name: "高等数学", room: "H1208", time: "08:20–10:00", startMillis: nil, endMillis: nil)
        return ScheduleEntry(date: now, state: ScheduleWidgetState(week: 5, courses: [course], message: ""))
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let now = Date()
        if context.isPreview { completion(placeholder(in: context)); return }
        completion(ScheduleEntry(date: now, state: ScheduleWidgetStore.read().state(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let now = Date()
        let data = ScheduleWidgetStore.read()
        let entries = data.timelineDates(after: now).map { ScheduleEntry(date: $0, state: data.state(at: $0)) }
        completion(Timeline(entries: entries, policy: .after(ScheduleWidgetSnapshot.nextMidnight(after: now))))
    }
}

struct ScheduleWidgetView: View {
    let entry: ScheduleEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int { family == .systemSmall ? 1 : family == .systemLarge ? 5 : 2 }
    private var title: String {
        if family != .systemSmall { return "今日课程" }
        return entry.state.courses.first?.ongoing(at: entry.date) == true ? "正在上课" : "下一节课"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.blue)
                Spacer(minLength: 4)
                if family != .systemSmall {
                    Text(dateLabel).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(weekLabel).font(.caption2).foregroundStyle(.secondary)
            if entry.state.courses.isEmpty {
                Spacer(minLength: 0)
                Text(entry.state.message).font(.system(size: family == .systemSmall ? 14 : 16, weight: .medium))
                    .foregroundStyle(.secondary).lineLimit(3).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.state.courses.prefix(limit))) { course in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name).font(.system(size: family == .systemSmall ? 18 : 15, weight: .semibold))
                            .lineLimit(family == .systemSmall ? 2 : 1).minimumScaleFactor(0.85)
                        Text(course.time + (course.ongoing(at: entry.date) ? " · 进行中" : "") + (family == .systemMedium ? " · \(course.room)" : ""))
                            .font(.caption).foregroundStyle(Color.blue).lineLimit(1)
                        if family != .systemMedium {
                            Text(course.room).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            Text(entry.state.courses.count > limit ? "还有 \(entry.state.courses.count - limit) 节 · 点击查看" : "成信友友 · 点击查看课表")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .widgetURL(URL(string: "chengxinyouyou://widget/schedule"))
        .scheduleBackground()
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = ScheduleWidgetSnapshot.calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: entry.date)
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = ScheduleWidgetSnapshot.calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: entry.date) + (entry.state.week > 0 ? " · 第 \(entry.state.week) 周" : "")
    }
}

private extension View {
    @ViewBuilder func scheduleBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(.secondarySystemBackground) }
        } else {
            padding(16).background(Color(.secondarySystemBackground))
        }
    }
}

@main
struct ChengxinScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ScheduleWidgetStore.kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("今日课程")
        .description("查看下一节课的时间、地点和今日课程。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
