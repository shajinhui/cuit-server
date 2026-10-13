import Flutter
import Foundation
import WidgetKit

enum DesktopWidgetBridge {
    private static var channel: FlutterMethodChannel?
    private static var pendingOpen = false
    private static var clientReady = false
    private static let writer = DispatchQueue(label: "chengxin.desktop-widget.writer")

    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "chengxin_youyou/desktop_widgets", binaryMessenger: messenger)
        self.channel = channel
        clientReady = false
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "consumeLaunch":
                clientReady = true
                let opened = pendingOpen
                pendingOpen = false
                result(opened)
            case "requestPin":
                // iOS 由用户在系统小组件列表添加，没有直接固定到桌面的 API。
                result(false)
            case "publish":
                guard let raw = call.arguments as? String, let data = raw.data(using: .utf8) else {
                    result(FlutterError(code: "invalid_snapshot", message: "课表摘要缺失", details: nil))
                    return
                }
                writer.async {
                    do {
                        let snapshot = try JSONDecoder().decode(ScheduleWidgetSnapshot.self, from: data)
                        guard snapshot.version == 1, let url = ScheduleWidgetStore.fileURL else {
                            throw CocoaError(.fileWriteNoPermission)
                        }
                        // 原子替换避免扩展读到半份 JSON；重启后首次解锁即可读取。
                        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        WidgetCenter.shared.reloadTimelines(ofKind: ScheduleWidgetStore.kind)
                        DispatchQueue.main.async { result(nil) }
                    } catch {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "widget_storage", message: "保存桌面课表失败", details: nil))
                        }
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func handle(url: URL) -> Bool {
        guard url.scheme == "chengxinyouyou", url.host == "widget", url.path == "/schedule" else { return false }
        if clientReady, let channel {
            channel.invokeMethod("openSchedule", arguments: nil)
        } else {
            pendingOpen = true
        }
        return true
    }
}
