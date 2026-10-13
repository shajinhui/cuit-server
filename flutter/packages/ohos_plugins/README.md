# 固定的鸿蒙插件实现

应用继续使用 pub.dev 的 Dart 接口包。这里通过直接路径依赖接入 OHOS 实现，Android / iOS 仍使用各接口包的原生插件。源码固定到下列提交，避免 Git 分支变化或构建时网络拉取影响可复现性；保留每个插件的许可证。

| 实现 | 上游提交 | 原始分支 |
| --- | --- | --- |
| `path_provider_ohos` | `d4e49daa0acbd0bc419d58b1da27d64d44fab54b` | `br_path_provider-v2.1.5_ohos` |
| `shared_preferences_ohos` | `860dc91d2263f58c26545c7c69e4d5cd765dfb4a` | `br_shared_preferences-v2.5.3_ohos` |
| `url_launcher_ohos` | `ae4494a78db5a9e0fe760b0eba9231605ae45716` | `br_url_launcher-v6.3.2_ohos` |
| `image_picker_ohos` | `1af98579e1a95d4fca19e422d26f5b6856ac38ba` | `br_image_picker-v1.2.1_ohos` |
| `share_plus_ohos` | `bfd882da6893c4c8bfa1648ac637c2d557e6f4fa` | `br_share_plus-v12.0.1_ohos` |

前四项来源：[CPF-Flutter/flutter_packages](https://gitcode.com/CPF-Flutter/flutter_packages)。分享实现来源：[openharmony-sig/flutter_plus_plugins](https://gitcode.com/openharmony-sig/flutter_plus_plugins)。

本地调整：移除各实现的示例与测试工程；分享包改名为 `share_plus_ohos`，只保留鸿蒙原生实现，依赖已发布的 `share_plus_platform_interface`。插件目录从主应用 lint 中排除，上游生成器不使用主应用的 Dart 规则；应用调用仍参与静态检查和编译。

安全存储使用本项目的 `ohos/entry/src/main/ets/platform/HarmonySecureStorage.ets`，ASSET 保存 AES-256 密钥，AES-GCM 密文保存到独立偏好文件。未采用上游把 RSA 私钥写进偏好文件的实现。

升级时先核对对应平台接口版本，运行 OHOS `pub get` 检查原生与 Dart 注册器，然后构建 HAP 并验证缓存、选择图片、外部链接、日历分享与安全存储的真实设备行为。
