# native_collator 的本地 SPM 适配

来源：[pub.dev/native_collator 1.0.2](https://pub.dev/packages/native_collator/versions/1.0.2)，MIT 协议见 LICENSE。

沿用上游 Android Collator、iOS String.compare 排序能力；增加 iOS Swift Package Manager 清单并调整 Swift 文件目录。通道改为返回稳定排序后的索引，避免 iOS 长字符串桥接截断 NUL 分隔符；比较时把 NUL 换成同样无 ICU 排序权重的 WORD JOINER，原始课程标识始终保留在 Dart。原生集成测试覆盖这一回归。未复制无关示例、IDE 文件与发布工具配置。根工程通过 path 依赖引用，便于读到全部适配代码。

用途仅为加载课表时准备中文配色顺序与普通文本排序。课表计算、切周和滚动不调用平台通道。iOS 和 Android 需要各自验证；原生鸿蒙需要另外实现排序适配。

移除条件：上游发布可用的 SPM 支持且两端对照测试通过后，恢复 pub.dev 依赖并删除本目录。
