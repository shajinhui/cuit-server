# iOS 热更新与本机安装

iOS 使用与 Android 相同的更新逻辑：启动和回前台后台检查、失败重试、显示当前补丁，下载完成后下次冷启动生效。必须先安装包含 Shorebird 引擎的基础包；普通 Flutter 安装包不能通过 Dart 补丁补入该引擎。

## 2026-10-18 二手列表优化：正式补丁 7 与验收事故恢复

- 基础版本 `0.1.0+2`，Release `900236`；iOS ARM64 补丁 `7`，Patch ID `728063`，约 2.25 MB，已发布至 `stable`。Android 同批补丁为 `6`。
- 包含二手商品按可见行加载，以及此前的启动、登录状态恢复优化。与图片修复补丁相比，9 个 Dart 文件修改、1 个 Dart 文件新增；依赖和原生配置不变。324 项 Flutter 测试、静态分析、校历和发布脚本检查通过；两个平台构建期间校对的 131 个源文件与配置摘要一致，基础包兼容性检查通过。
- 补丁 7 已先在真机完成 staging 下载和冷启动。恢复 stable 基础包时，旧正式补丁 5 被排入下次启动；正式服务随后返回补丁 7，但更新器因 7 已缓存而跳过安装，没有重新安排启动。日志和原生指针均记录了这一情况。
- **验收操作失误：** 为定向刷新补丁 7 缓存，执行 `devicectl device copy to`，指定 `--destination Library/Application Support/shorebird/shorebird_updater/patches/7` 和 `--remove-existing-content true`。该操作实际影响了整个应用沙盒，普通缓存和偏好文件被清除，并非补丁代码自行清理数据。已立即向用户说明，保留命令、前后目录和恢复记录，相关本机脚本已禁止再次运行。
- **恢复结果：** 没有卸载应用；钥匙串中的登录凭证仍有效，登录和服务器课表已恢复，原企鹅头像已重新选择，界面确认外观跟随系统、轻量效果关闭。用户确认没有本机添加课程、自定义课色或相册头像。更新器身份从原备份恢复，未手写启动指针；正式基础包重新实际下载补丁 7，冷启动后 `last_booted_patch: 7`、`next_boot_patch: 7`、`currently_booting_patch: null`。界面显示“当前补丁：7”和“暂无可用的在线更新”。
- 没有完整的旧沙盒备份，因此不能声称旧缓存和全部本机标记逐字恢复；公告已读等本地记录可能重置。原始基础 APK／IPA 均未改变，源码快照、云端发布、原生下载和启动证据，以及 `ios-data-incident.json` 位于 `build/hot_updates/2026-10-18-marketplace/`。

### 后续真机验证约束

staging 真机验证通过后，先提升补丁到 stable，再恢复原始 stable 基础包，避免旧正式补丁进入下次启动。对照 `next_boot_patch`、`last_booted_patch` 和 `currently_booting_patch` 确认下载及启动成功后再继续操作。

**禁止在用户数据容器使用 `devicectl copy to --remove-existing-content true`，不能把 `--destination` 当作安全的删除范围。** 不能为解决已缓存补丁问题试验删除真实用户沙盒；必要的文件恢复只使用默认保留既有内容的复制，并先在独立 temporary 域验证路径语义。

## 2026-10-17／18 图片修复补丁 5：正式发布与真机验收

- 基础版本 `0.1.0+2`，Release `900236`；iOS ARM64 补丁 `5`，Patch ID `726777`，约 2.07 MB，2026-10-17 已发布至 `stable`，2026-10-18 完成真机下载和冷启动生效验收。
- 包含图片失败重试、点击全屏缩放预览、并发鉴权修复、缩略图解码和缓存限制，以及评分、论坛、二手的统一选图压缩参数。构建前的 313 项 Flutter 测试及静态检查通过，构建期间校验的 130 个源文件和配置摘要一致；与上次补丁相比仅 8 个 Dart 文件变化，原生及资源兼容性检查通过。
- 手机使用已覆盖恢复的原始 stable 基础包，实际下载后 `next_boot_patch: 5`；明确结束当前安装路径对应的主应用进程后重新启动，原生记录为 `last_booted_patch: 5`、`next_boot_patch: 5`、`currently_booting_patch: null`，确认补丁 5 已加载并启动成功。真机界面同时显示“当前补丁：5”和“暂无可用的在线更新”，课表及原有个人资料正常显示。
- 操作前后的更新器身份一致，基础版本仍为 `0.1.0+2`，没有卸载、清空应用数据或分发补丁构建产物作为新基础包。
- 此前手机连接更新服务时收到 RST，TCP `so_error: 54`，界面提示更新失败；Safari 访问 `https://api.shorebird.dev/` 也提示网络连接断开。用户于 2026-10-18 连接可用代理后，同一正式基础包成功下载并运行补丁 5。本次没有修改用户代理配置，记录保留此前失败与最终成功两组证据。
- 构建、云端状态、下载与冷启动指针、更新器身份校验及源文件摘要位于 `build/hot_updates/2026-10-17-images/`，最终验证日志为 `ios-proxy-20261018-verification.log`。图片交互已通过组件测试，实际平台选图和上传压缩效果尚未在手机上人工验收，未向线上发布测试评分或帖子。

## 2026-10-15 验证结果

- 基础版本 `0.1.0+2` 已发布至 Shorebird Release `900236`，独立查询确认 `ios: active`，Android 保持 `active`。
- Flutter `3.47.5`，revision `ff900e7fbab20fdeb40905ee631baa8d49bd0fa1`，Shorebird engine `c663a2682e6adfc60a1aaff99ff62baa891dcf87`。
- IPA、主应用及 `ScheduleWidget` 的签名、App Groups 和版本一致性检查通过；Flutter 引擎包含更新、当前补丁及下次启动补丁等四个 Shorebird 接口。
- 已通过 `devicectl` 覆盖安装到原 iPhone，未卸载或清空应用。启动成功后查询到对应新安装路径的进程，设备上的更新器状态文件已初始化为 `release_version: 0.1.0+2`。
- 发布后再次启动时手机已自动锁屏，系统拒绝启动；解锁后可直接打开已安装的新版本。iOS 本次未发布新的 Dart 补丁，不能把基础包验证视为真实 OTA 下载验收。
- 发布脚本 8 项测试通过，包含 Shorebird 清理 `.dart_tool` 后仍能正确选择 iOS SDK 的回归验证。

安装包：`build/releases/0.1.0+2/ios/chengxin-youyou-0.1.0+2-shorebird-development.ipa`。SHA-256：`16c9a368602cfe2a0db14d1d912c052faf200da58d40c98e14388c277a9a7e28`。该目录同时保存云端状态、签名结果、源文件摘要和真机运行时验证信息。后续补丁基于此基础包发布，安装包使用已归档的原始 IPA。

## 2026-10-17 补丁 3：正式发布与真机验收

- 目标基础版本 `0.1.0+2`，Release `900236`；iOS ARM64 补丁 `3`，Patch ID `723596`，约 1.90 MB，已从 `staging` 提升到 `stable`。
- 包含课表周次按钮缩小、公告默认二群链接、校园页和通用布局的最新 Dart 调整。构建前的 298 项 Flutter 测试、静态分析及原生和资源兼容性检查通过；本次复核 128 个源文件及配置摘要，与补丁构建时一致。
- 使用原始 IPA 的副本，仅调整测试通道并沿用原签名，覆盖安装到 iPhone 17 Pro Max。实际下载后，原生状态为 `next_boot_patch: 3`、`last_booted_patch: null`，确认下载与生效是两个阶段。
- 结束进程并再次启动后，原生状态为 `last_booted_patch: 3`、`next_boot_patch: 3`、`currently_booting_patch: null`，确认真实补丁已加载且启动成功。
- 正式发布后，已覆盖恢复原始 stable 通道基础包，再次启动仍运行补丁 3。整个过程没有卸载或清空应用，更新器身份保持不变。
- 补丁构建、基础包元数据恢复记录保存在 `build/hot_updates/2026-10-16/`；本次真机验收及最终云端状态归档至 `build/hot_updates/2026-10-17/`。

## 2026-10-16 基础包元数据恢复

首次生成 iOS 补丁时发现原发布缺少 `ios_supplement`，导致链接阶段无法读取 `App.ct.link`。`ios: active` 只能说明基础版本已发布，不能替代补丁链路验收。

本次在隔离目录恢复基础版本的 125 个源文件和配置摘要，使用相同 Flutter/引擎，并保留生成插件注册文件的原始 URI。重新构建后，用官方 `analyze_snapshot --dump_blobs` 导出原始 IPA 与恢复构建的四个 Dart 快照区域，内容逐字节一致，SHA-256 均为 `ece1ff576b94a950bfa98ce34b7ee7e39742b204c3e312749f97eb9925f4d845`。在此校验通过后，仅补传 `ios_supplement`；云端原始 `xcarchive` 和 `runner` 产物保持不变，现有安装包无需更换。

恢复的元数据已同时保存到 `build/releases/0.1.0+2/ios/supplement/`；本次校验、源码摘要和上传记录位于 `build/hot_updates/2026-10-16/`。以后发布或续传时须保留并上传 `build/ios/shorebird/` 的补充元数据，不能只保存 IPA 和 xcarchive。

## 本机开发签名

2026-10-15 已通过 Xcode 续签主应用和 `ScheduleWidget`，沿用 Team `6N2B8WNHR8`、原包名和 App Groups。主应用描述文件有效至 **2026-10-22 16:31:19（北京时间）**，小组件有效至同日 16:31:22。

本机使用 Apple Development / Personal Team 签名，只适用于已注册设备。热更新不能延长 Apple 描述文件有效期；到期前需要重新签名并覆盖安装。App Store / TestFlight 分发还需要付费开发者团队、发布证书和对应的分发描述文件。

主应用包名为 `org.dpdns.fanxiaogao05.chengxin.flutter`，扩展为该包名追加 `.ScheduleWidget`，共享组为 `group.org.dpdns.fanxiaogao05.chengxin.flutter`。证书私钥和描述文件保留在本机钥匙串及 Xcode 目录，不进入仓库。

## 构建及后续补丁

在 `flutter/` 中执行：

```bash
./tool/shorebird.sh release ios --export-options-plist=ios/ExportOptions-development.plist
# 后续修改 Dart 代码时，沿用目标基础版本：
./tool/shorebird.sh patch ios 0.1.0+2 --track staging --export-options-plist=ios/ExportOptions-development.plist
# 真机验证补丁后，将实际生成的补丁号提升到 stable：
./tool/shorebird.sh patches set-track --release 0.1.0+2 --patch <实际补丁号> --track stable
```

`ios/ExportOptions-development.plist` 禁用自动修改版本号，避免导出后的版本与 Shorebird 记录不一致。其他团队需同时调整两个 Target 和此文件的 Team。

`tool/shorebird.sh` 和 `tool/flutter.sh` 把本机 `xcrun` 包装器放在 `.build/local_toolchain`，在原生 Dart 构建钩子中选择 Xcode 的 iOS SDK，不修改全局 `xcode-select`。Shorebird 的 iOS 构建会删除 `.dart_tool`，因此不能把包装器放在那里。脚本回归测试已验证：删除 `.dart_tool` 并移除 `DEVELOPER_DIR` 后，仍能找到 iPhone SDK。

原生插件、小组件、权限和打包资源变化需要发布完整新基础包。签名范围与桌面组件说明见 [桌面小组件](DESKTOP_WIDGETS.md)，发布与预览流程见 [Shorebird 官方文档](https://docs.shorebird.dev/code-push/preview/)。
