import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DesktopWidgets") {
      DesktopWidgetBridge.register(messenger: registrar.messenger())
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeTabBar") {
      registrar.register(
        NativeTabBarFactory(messenger: registrar.messenger()),
        withId: "chengxin_youyou/native_tab_bar"
      )
    }
  }
}
