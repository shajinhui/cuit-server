# 鸿蒙适配与 HAP 构建

工程目标为 HarmonyOS SDK 26.0.0，兼容版本为 5.0.5(17)，与 Android / iOS 共用 Dart 页面。目标版本参考[华为 DevEco Studio 26.0.0 兼容性表](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/deveco-studio-new-features-2600)。

## 固定工具链

使用 `.flutter-ohos-version` 固定的 **3.44.9+ohos-0.0.1-canary1 / Dart 3.12.2**，来源为 [CPF-Flutter](https://gitcode.com/CPF-Flutter/flutter_flutter)。这是上游预发布标签；Android / iOS 继续使用 `.flutter-version` 固定的官方 Flutter。构建机需要 DevEco Studio 26.0.0、对应 HarmonyOS SDK、Node.js 24、Hvigor 6.26.4 和 ohpm 26.0.0.630。

可以克隆固定标签，然后用 `FLUTTER_OHOS_BIN` 指定工具链。`tool/flutter-ohos.sh` 会校验版本：

```bash
git clone --depth 1 --branch '3.44.9+ohos-0.0.1-canary1' \
  https://gitcode.com/CPF-Flutter/flutter_flutter.git /path/to/flutter-ohos
cd flutter
export FLUTTER_OHOS_BIN=/path/to/flutter-ohos/bin/flutter
export HOS_SDK_HOME=/path/to/DevEco-Studio.app/Contents/sdk
# 将 DevEco 配套 node、ohpm、hvigorw、hdc 加入 PATH 后执行：
./tool/flutter-ohos.sh doctor -v
./tool/flutter-ohos.sh pub get --enforce-lockfile
./tool/flutter-ohos.sh analyze --no-pub
./tool/flutter-ohos.sh test --no-pub
./tool/flutter-ohos.sh build hap --no-pub --no-codesign --debug --target-platform ohos-arm64
```

最后一条生成未签名包，用于编译验证；也可直接运行 `./tool/check-ohos.sh`。在 DevEco Studio 中打开 `ohos/`，配置产品 `default` 的调试签名，再执行 `./tool/flutter-ohos.sh build hap --debug --target-platform ohos-arm64` 和 `./tool/flutter-ohos.sh devices`。产物位于 `ohos/entry/build/default/outputs/default/`，设备安装需要签名 HAP。

官方 Flutter 与 Flutter OH 固定的 SDK 依赖不同，因此分别维护 `pubspec.lock` 和 `pubspec.ohos.lock`。OH 包装脚本在当前命令内使用 OH 锁，结束时恢复 Android / iOS 锁。切回官方 Flutter 后先执行 `./tool/flutter.sh pub get`，以重建对应 SDK 的 `.dart_tool`；同一工程不要同时运行两套工具链。使用相同工具链更新对应锁文件，正式构建使用 `--enforce-lockfile`。

## 已接入的能力

- 文件目录、偏好设置、外部链接、相册图片与文件分享：使用 `packages/ohos_plugins/` 固定的 OHOS 实现，[来源与本地改动](../packages/ohos_plugins/README.md)均有记录。Native 与 Dart 注册器由 OH 工具链生成，不手工维护 `GeneratedPluginRegistrant.ets`。
- 登录凭证、Cookie、校园跑令牌与本机头像：通过 `HarmonySecureStorage.ets` 通道保存。ASSET 保护 AES-256 密钥，独立偏好文件只保存 AES-GCM 密文，键名使用 SHA-256 摘要；退出时按账号前缀删除。较大数据不受 ASSET 单个 SECRET 的 1024 字节限制；[ASSET 文档](https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/security/AssetStoreKit/asset-js-add.md)说明了该限制。
- 玻璃界面：鸿蒙使用磨砂或轻量效果，避开未验证的折射着色器路径。
- 中文排序：暂用 Dart 确定性顺序降级，未提供拼音排序。Shorebird 补丁与桌面小组件在鸿蒙端暂不启用。
- 权限：目前只声明联网权限；图片通过系统相册选择器获取，未启用拍照入口。

## 验证记录（2026-10-13）

| 检查 | 结果 |
| --- | --- |
| 固定 OH SDK 启动与依赖解析 | Dart 3.12.2；依赖解析成功，生成的插件清单包含 5 个 OH 实现。原生注册生成阶段因缺少 HarmonyOS SDK 返回失败 |
| 官方 Flutter 3.47.5 静态分析与测试 | 独立源码目录分析通过，267 项测试通过 |
| OH 工具链静态分析 | 独立源码目录 `analyze --no-pub` 通过 |
| OH 工具链单元与组件测试 | 独立源码目录 267 项通过；运行在 macOS 测试引擎，不代表鸿蒙真机通过 |
| 安全存储 Dart 通道测试 | 2 项通过，覆盖错误传播与账号前缀清理契约 |
| ArkTS 存储运行时模拟 | 冷启动、超过 1 KB 的中文数据、并发初始化、账号隔离、密文认证、失败后恢复及丢失密钥保护通过；未替代 ArkTS 编译与 ASSET 真机验证 |
| HAP 构建 | 已尝试，缺少 HarmonyOS SDK、ohpm、Hvigor；尚未生成 HAP |

存储模拟可在安装 Web 工程依赖后运行 `node tool/test_ohos_storage.cjs`。完成 HAP 后还需要验收登录与重启恢复、退出清理、课表文件缓存、相册裁剪、多图上传、外部链接、ICS 分享、中文字体、返回手势、安全区及滑动性能。
