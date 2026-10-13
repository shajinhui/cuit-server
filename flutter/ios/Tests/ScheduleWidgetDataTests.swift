import Foundation

// 使用 Dart 测试导出的同一份 JSON，验证原生解码、上下课及跨日规则。
@main
struct ScheduleWidgetDataTests {
    static func main() throws {
        let raw = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let snapshot = try JSONDecoder().decode(ScheduleWidgetSnapshot.self, from: raw)
        let parser = ISO8601DateFormatter()
        let before = parser.date(from: "2026-10-08T00:19:00Z")!
        let start = parser.date(from: "2026-10-08T00:20:00Z")!
        let end = parser.date(from: "2026-10-08T02:00:00Z")!
        precondition(snapshot.state(at: before).courses.count == 4)
        precondition(snapshot.state(at: start).courses.prefix(2).allSatisfy { $0.ongoing(at: start) })
        precondition(snapshot.state(at: end).courses.count == 2)
        precondition(!snapshot.state(at: end).courses.contains { $0.name == "高等数学" })
        let nextDay = ScheduleWidgetSnapshot.nextMidnight(after: before)
        precondition(nextDay == parser.date(from: "2026-10-08T16:00:00Z")!)
        precondition(snapshot.state(at: nextDay).courses.isEmpty)
        precondition(snapshot.state(at: nextDay).message.contains("没有课程"))
        let dates = snapshot.timelineDates(after: before)
        precondition(dates == dates.sorted() && Set(dates).count == dates.count)
        precondition(dates.contains(start) && dates.contains(end) && dates.contains(nextDay))
        precondition(ScheduleWidgetSnapshot.empty.state(at: before).courses.isEmpty)
        print("iOS 小组件共享数据测试通过：解码、冲突课、上下课、北京时间换日、空课表、退出状态。")
    }
}
