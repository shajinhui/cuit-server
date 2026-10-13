import Flutter
import UIKit

private let nativeTabBarViewType = "chengxin_youyou/native_tab_bar"

final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeTabBarPlatformView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

private final class NativeTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let containerView: UIView
  private let tabBar = UITabBar()
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    containerView = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "\(nativeTabBarViewType)/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    containerView.backgroundColor = .clear
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.delegate = self
    tabBar.items = [
      UITabBarItem(title: "课表", image: tabIcon("nav-schedule", scale: 1.25), tag: 0),
      UITabBarItem(title: "工具", image: tabIcon("nav-tools", scale: 1.5), tag: 1),
      UITabBarItem(title: "校园", image: tabIcon("nav-ratings", scale: 1.35), tag: 2),
      UITabBarItem(title: "我的", image: tabIcon("nav-profile-tab", scale: 1.17), tag: 3),
    ]
    tabBar.selectedItem = tabBar.items?.first
    containerView.addSubview(tabBar)

    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      tabBar.topAnchor.constraint(equalTo: containerView.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "导航栏已关闭", details: nil))
        return
      }

      guard call.method == "setSelectedIndex",
            let index = call.arguments as? Int,
            let items = self.tabBar.items,
            items.indices.contains(index) else {
        result(FlutterMethodNotImplemented)
        return
      }

      self.tabBar.selectedItem = items[index]
      result(nil)
    }
  }

  func view() -> UIView {
    containerView
  }

  /// 按原 Vue 导航栏的图标比例绘制到系统标签栏尺寸内，并保留系统着色行为。
  private func tabIcon(_ name: String, scale: CGFloat) -> UIImage? {
    guard let image = UIImage(named: name) else { return nil }

    let size: CGFloat = 25
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let renderedImage = renderer.image { _ in
      let drawSize = size * scale
      image.draw(
        in: CGRect(
          x: (size - drawSize) / 2,
          y: (size - drawSize) / 2,
          width: drawSize,
          height: drawSize
        )
      )
    }
    return renderedImage.withRenderingMode(.alwaysTemplate)
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("onSelect", arguments: item.tag)
  }
}
