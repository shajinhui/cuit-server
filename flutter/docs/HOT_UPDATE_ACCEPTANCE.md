# Android 热更新验收

2026-10-15 已完成基础包发布、真实补丁下发和冷启动生效验收。

- 基础版本：`0.1.0+2`；Shorebird Release：`900236`，状态 `active`。
- 补丁：`1`；Patch ID：`721144`，通道 `stable`，未撤回。
- Flutter：`3.47.5`；Shorebird revision：`ff900e7fbab20fdeb40905ee631baa8d49bd0fa1`。
- Android 正式签名：RSA 4096 位，APK v2 验签通过。
- 证书 SHA-256：`52865c02d8d28a0d6169fa82655631828478c7f56fb1292af1759d4f19fcf371`。
- APK SHA-256：`f090190ea06f2736b28777a44b50b774cc892563b0f51c7e9d58ac5ecbd52d76`。

## 2026-10-18 二手列表优化：正式补丁 6

- Android 补丁 `6`，Patch ID `728061`，已发布至 `stable`，覆盖 ARM32、ARM64、x86_64；目标基础版本仍为 `0.1.0+2`（Release `900236`）。
- 二手列表按可见行及附近少量内容构建，避免屏幕外商品图片同时下载；保留原有双列布局和大字体单列显示。40 件带图商品的回归用例中，首屏图片加载由 40 次降至不超过 8 次，滚动后再加载后续商品。单张图片仍下载完整文件，本补丁不包含服务端缩略图或持久图片缓存。
- 同步包含此前已完成的启动和登录状态恢复优化：启动先读取本机身份及有效凭证，显示缓存课表后再联网刷新。与上次图片补丁相比，9 个 Dart 文件修改、1 个 Dart 文件新增；依赖及原生配置不变。
- 324 项 Flutter 测试、静态分析、校历和发布脚本检查通过；构建期间的 131 个源文件与配置摘要一致。Shorebird 基础包兼容性检查通过，未使用忽略原生或资源差异的选项。
- 已在本机原有 Android 15 / API 35 ARM64 镜像创建的临时设备验证补丁 6 下载和冷启动：`last_booted_patch: 6`、`next_boot_patch: 6`、`currently_booting_patch: null`，无 AndroidRuntime 致命异常。验证后关闭并删除临时 AVD，没有下载新镜像。
- 归档的原始基础 APK／IPA 摘要保持一致；源码快照、构建日志、云端结果和实际运行指针位于 `build/hot_updates/2026-10-18-marketplace/`。iOS 同批补丁状态见 [iOS 热更新与本机安装](IOS_HOT_UPDATE.md)。

## 2026-10-17 图片修复：正式补丁 4

- Android 补丁 `4`，Patch ID `726773`，已发布至 `stable`，覆盖 ARM32、ARM64、x86_64；继续面向基础版本 `0.1.0+2`。
- 包含图片失败重试、点击全屏缩放预览、并发鉴权修复、缩略图解码和缓存限制，以及评分、论坛、二手的统一选图压缩参数。
- 313 项 Flutter 测试与静态检查通过；130 个源文件和配置已记录摘要。与前次补丁相比只有 8 个 Dart 文件变化，原生和资源兼容性检查通过，未使用忽略差异的发布选项。
- 使用本机已有 Android 15 / API 35 ARM64 镜像创建一次性设备，基础包实际下载补丁 4；冷启动后 `last_booted_patch: 4`、`next_boot_patch: 4`、`currently_booting_patch: null`，未出现 AndroidRuntime 致命异常。
- 验收后已关闭并删除本次临时 AVD，没有下载系统镜像。云端、构建、下载及冷启动证据位于 `build/hot_updates/2026-10-17-images/`。实际图片交互通过组件测试，未向线上发布测试评分或帖子。

iOS 图片修复补丁 5 已于 2026-10-18 在用户 iPhone 完成正式通道下载和冷启动生效验收；手机保持原始基础包、更新器身份及原有数据，详见 [iOS 热更新与本机安装](IOS_HOT_UPDATE.md)。

## 2026-10-16 正式补丁 2

- 目标基础版本仍为 `0.1.0+2`，Release `900236`；Android 补丁 `2`，Patch ID `723568`，已提升至 `stable`，包含 ARM32、ARM64 和 x86_64 三个架构。
- 本次 Dart 更新包含课表周次按钮缩小、公告默认入口改为“成信友友二群”（`https://qm.qq.com/q/oY2MdsQgco`），以及当前源码中的校园页和通用布局调整。
- 使用已安装的 Android 15 / API 35 ARM64 系统镜像创建一次性测试设备，没有下载模拟器镜像。原始基础包通过 staging 实际下载补丁 2；结束进程并再次启动后，原生更新器记录 `last_booted_patch: 2`、`next_boot_patch: 2`，`currently_booting_patch: null`，未出现 AndroidRuntime 致命异常。
- `./tool/check.sh` 通过：298 项 Flutter 测试、静态分析、校历与发布脚本检查。发布前后校对 128 个源文件与配置摘要，未发生构建期间源码变动。
- 云端结果、下载及启动记录、源码摘要归档至 `build/hot_updates/2026-10-16/`。本次没有改变基础 APK，也未将补丁构建产物当作基础包分发。iOS 进度与验收见 [iOS 热更新与本机安装](IOS_HOT_UPDATE.md)。

## 实际验证

使用 Android 15 / API 35 ARM64 模拟器和真实 Shorebird SDK，业务使用体验账号，没有登录学校账号。

1. 正式基础包包含三个架构的 Shorebird 运行时，实际检测到更新能力可用。
2. staging 通道下载补丁 1，下载后界面仍显示基础版本，并提示下次启动生效。
3. 结束进程再启动，原生引擎加载补丁 1，页面显示“当前补丁：1”。
4. 关闭网络，显示“更新失败，请检查网络后重试”，不误报最新。
5. 恢复网络并回到前台，在同一进程自动重试成功，保持运行补丁 1。
6. 将补丁提升到 stable；重新安装正式基础 APK，并清空此专用测试设备上的应用数据。
7. 正式基础包从 stable 重新下载补丁 1；首次网络中断后手动重试成功。
8. 冷启动后再次确认“当前补丁：1”，并且默认请求 stable 通道。

本次补丁修复网络错误被 SDK bool 检查接口折叠成“没有更新”的问题，改用可返回失败原因的 `update()` 接口；同时增加回前台自动检查和五分钟检查限频。手动检查不受间隔限制，失败后回前台可立即重试。

## 校验与产物

- 全量 Flutter 测试：290 项通过，其中更新专项 17 项。
- 发布脚本测试：7 项通过；Flutter analyze 无问题。
- 此处 OTA 验收平台为 Android ARM64；其余两个 Android 架构已构建并检查运行时符号。iOS 于 2026-10-17 完成补丁 3 的真机下载、冷启动及 stable 发布验收，见 [iOS 热更新与本机安装](IOS_HOT_UPDATE.md)。App Store 分发签名尚未完成。
- 安装包：`build/releases/0.1.0+2/chengxin-youyou-0.1.0+2-shorebird-signed.apk`。
- AAB、公开签名证书、验签输出、云端状态 JSON、源码摘要和截图同在 `build/releases/0.1.0+2/`。
- 首次安装此基础包后，联网等待提示“更新已准备好”，彻底关闭再打开 App 生效。

分发时使用已归档的基础包；`shorebird patch` 会覆盖构建目录里的 AAB，不将补丁构建产物当作新的基础版本分发。

后续仅修改 Dart 代码，保持目标基础版本号，先发布到 staging 验证：

```bash
./tool/shorebird.sh patch android 0.1.0+2 --track staging
# 将下面的补丁号替换为本次实际生成的号码
./tool/shorebird.sh patches set-track --release 0.1.0+2 --patch 2 --track stable
```

原生插件、权限或打包资源变化需要发布新的基础版本。签名备份和构建说明见 [Android 正式签名](ANDROID_SIGNING.md)。
