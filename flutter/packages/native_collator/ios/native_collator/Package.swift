// swift-tools-version: 5.9
import PackageDescription

// 为上游 1.0.2 补充 Swift Package Manager 清单；沿用系统排序并返回索引，保护 Dart 原始标识。
let package = Package(
    name: "native_collator",
    platforms: [.iOS("13.0")],
    products: [.library(name: "native-collator", targets: ["native_collator"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [.target(
        name: "native_collator",
        dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
        resources: [.process("PrivacyInfo.xcprivacy")]
    )]
)
