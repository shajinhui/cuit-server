import EventKit
import Flutter
import UIKit

/// 直接把课表写进系统日历（EventKit），不再生成 ics 交给分享面板。
///
/// 写入目标是一个由本应用创建的独立日历（名字取学期名），因此不会污染用户
/// 自己的日历。同一学期重复导入时，先按 URL 标记清掉上次写入的日程。
enum SystemCalendarBridge {
  private static let store = EKEventStore()
  /// EKEventStore 不是线程安全的，所有读写排到同一条串行队列上。
  private static let queue = DispatchQueue(label: "chengxin.system-calendar")

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "chengxin_youyou/system_calendar",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestAccess":
        requestAccess(result)
      case "importEvents":
        importEvents(call.arguments, result: result)
      case "openSettings":
        openSettings()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func requestAccess(_ result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
        result(true)
        return
      }
      store.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      if EKEventStore.authorizationStatus(for: .event) == .authorized {
        result(true)
        return
      }
      store.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  private static func importEvents(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let title = (args["calendarName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty,
      let rawEvents = args["events"] as? [[String: Any]]
    else {
      result(FlutterError(code: "bad_arguments", message: "导入参数缺失", details: nil))
      return
    }
    let marker = args["marker"] as? String ?? ""
    queue.async {
      do {
        let calendar = try ensureCalendar(named: title)
        if !marker.isEmpty {
          removePrevious(marker: marker, calendar: calendar, events: rawEvents)
        }
        var written = 0
        for raw in rawEvents {
          guard let startMillis = (raw["start"] as? NSNumber)?.doubleValue,
            let endMillis = (raw["end"] as? NSNumber)?.doubleValue,
            endMillis > startMillis
          else { continue }
          let event = EKEvent(eventStore: store)
          event.calendar = calendar
          event.title = raw["title"] as? String ?? "课程"
          let detail = raw["detail"] as? String ?? ""
          if !detail.isEmpty { event.notes = detail }
          let location = raw["location"] as? String ?? ""
          if !location.isEmpty { event.location = location }
          event.startDate = Date(timeIntervalSince1970: startMillis / 1000)
          event.endDate = Date(timeIntervalSince1970: endMillis / 1000)
          event.isAllDay = false
          let uid = raw["uid"] as? String ?? ""
          if !marker.isEmpty, let url = URL(string: "\(marker)#\(uid)") {
            // URL 只作为「这条日程由本应用写入」的标记，用于下次导入时清理。
            event.url = url
          }
          let minutes = (raw["reminderMinutes"] as? NSNumber)?.intValue ?? 0
          if minutes > 0 {
            event.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60))
          }
          do {
            try store.save(event, span: .thisEvent, commit: false)
            written += 1
          } catch {
            // 单条失败（例如时间冲突校验）不阻断整批写入。
            continue
          }
        }
        try store.commit()
        DispatchQueue.main.async { result(written) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "calendar_write",
              message: "写入系统日历失败：\(error.localizedDescription)",
              details: nil
            )
          )
        }
      }
    }
  }

  /// 找到本应用为该学期创建的日历，没有就建一个。
  private static func ensureCalendar(named title: String) throws -> EKCalendar {
    if let existing = store.calendars(for: .event).first(where: { $0.title == title }) {
      return existing
    }
    guard let source = preferredSource() else {
      throw NSError(
        domain: "chengxin.system-calendar",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "本机没有可用的日历账户"]
      )
    }
    let calendar = EKCalendar(for: .event, eventStore: store)
    calendar.title = title
    calendar.source = source
    calendar.cgColor = UIColor(
      red: 0x08 / 255.0,
      green: 0x78 / 255.0,
      blue: 0xE8 / 255.0,
      alpha: 1
    ).cgColor
    try store.saveCalendar(calendar, commit: true)
    return calendar
  }

  private static func preferredSource() -> EKSource? {
    if let source = store.defaultCalendarForNewEvents?.source { return source }
    if let local = store.sources.first(where: { $0.sourceType == .local }) { return local }
    return store.sources.first(where: { $0.sourceType == .calDAV }) ?? store.sources.first
  }

  /// 清掉上一次导入写入的日程；EventKit 的时间范围查询限制在 4 年内，
  /// 这里取本次导入范围前后各 500 天，足以覆盖相邻学期。
  private static func removePrevious(
    marker: String,
    calendar: EKCalendar,
    events: [[String: Any]]
  ) {
    let millis = events.compactMap { ($0["start"] as? NSNumber)?.doubleValue }
    guard let earliest = millis.min(), let latest = millis.max() else { return }
    let window: TimeInterval = 500 * 24 * 60 * 60
    let start = Date(timeIntervalSince1970: earliest / 1000 - window)
    let end = Date(timeIntervalSince1970: latest / 1000 + window)
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
    for event in store.events(matching: predicate) {
      guard let url = event.url?.absoluteString, url.hasPrefix(marker) else { continue }
      try? store.remove(event, span: .thisEvent, commit: false)
    }
  }

  private static func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    DispatchQueue.main.async {
      UIApplication.shared.open(url)
    }
  }
}
