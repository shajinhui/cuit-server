# 项目长期记忆

## 仓库形态
- `cuit-server`（成信友友）main 分支只含前端：`apps/web`（Vue3+Vite+PWA+Capacitor）。
- Go 后端源码在 `.claude/worktrees/` 的 `claude/*` 分支，已 add 未 commit；改后端前先确认落在哪个 worktree。
- `flutter/` 工程未纳入 git（untracked），是移动端主力。
- 校园评分/二手/论坛走独立服务 cuit-ratings-api（NestJS，不在本仓库），Bearer 凭证由主服务 `/api/v1/auth/ratings-token` 签发。
- 校历唯一事实来源：`shared/academiccalendar/calendars.json`。

## 用户偏好
- 新功能只做 Flutter 端，不做 PWA/Web 端（2026-10-13 论坛模块时明确）。

## 环境要点
- Flutter SDK：`$HOME/.local/share/cuit-flutter-sdk/bin/flutter`（或用 `flutter/tool/flutter.sh` 包装脚本）。
- 跑 `flutter test` 必须先去掉代理环境变量（`env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy`），否则沙箱代理导致 flutter_tester WebSocket 握手失败。
- `flutter analyze` 会在 `packages/ohos_plugins`（预置鸿蒙插件）报 800+ 条预存问题，评估改动时只看 lib/ 和 test/。
- 安卓原生单测（Robolectric）可在本机离线跑：`cd flutter/android && JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home ANDROID_HOME=$HOME/.local/share/cuit-android-sdk ./gradlew :app:testDebugUnitTest --tests '*ScheduleWidgetProviderTest' --offline`；报告在 `flutter/build/app/test-results/`。只改原生、Dart 侧编译不过时加 `-x compileFlutterBuildDebug -x copyFlutterAssetsDebug`。
- 已在构建的 APK 上核对原生声明：`aapt2 dump xmltree <apk> --file res/xx.xml`（release 包资源名会被混淆成 `res/BG.xml` 之类，先用 `aapt2 dump resources` 查映射）。

## 桌面小组件（安卓）
- 安卓没有「同组件多尺寸」，添加时的小／中／大 = 清单里注册三个 receiver（`ScheduleWidgetSmallProvider` 2×2 / `ScheduleWidgetProvider` 4×2 / `ScheduleWidgetLargeProvider` 4×4），共用一份 `ScheduleWidgetProvider` 渲染代码（基类须 `open`），一次刷新遍历 `providerClasses` 覆盖全部尺寸；`onDisabled` 要在三个组件都空了才停闹钟。
- 每种尺寸都必须写 `resizeMode="horizontal|vertical"` 与 `maxResizeWidth/Height`（缺省时框架下发 0，放大能力由各家桌面自行解释）；下限 160dp 是硬指标：标题+周次+一节课的时间地点约需 156dp。
