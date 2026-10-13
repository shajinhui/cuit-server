import Flutter
import UIKit

public class NativeCollatorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "native_collator", binaryMessenger: registrar.messenger())
    let instance = NativeCollatorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "sortIndices",
      let args = call.arguments as? [String: Any],
      let input = args["input"] as? [String],
      let locale = args["locale"] as? String
    {
      let localeObj = Locale(identifier: locale)
      // 返回索引，避免桥接长字符串时截断内部 NUL；相同排序权重保持原输入顺序。
      let sorted = input.indices.sorted {
        let comparison = input[$0].compare(input[$1], locale: localeObj)
        return comparison == .orderedSame ? $0 < $1 : comparison == .orderedAscending
      }
      result(sorted)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
