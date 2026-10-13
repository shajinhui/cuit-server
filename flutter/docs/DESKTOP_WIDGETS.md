# 桌面课表小组件

Android 和 iOS 使用真实的系统桌面小组件，显示下一节课、今日尚未结束的课程、时间、地点和教学周。入口位于 **我的 → 桌面小组件**。Flutter 中的内容预览用于说明课程内容，实际桌面卡片由各自系统绘制。

## 用户操作

首次使用先登录并同步课表，再添加小组件。演示模式不会把虚构课表发布成真实桌面课程。

| 平台 | 添加方式 | 尺寸与内容 |
| --- | --- | --- |
| Android | 在应用中点击“添加到桌面”，确认系统弹窗；或在桌面长按空白处打开小组件列表，列表里分别列出「下一节课（小）」「今日课程（中）」「今日课程（大）」 | 添加时即可选尺寸，加入后仍可拖动边缘调整。小卡默认 2×2 只显示下一节，中卡 4×2、大卡 4×4，都按高度显示 1–5 节 |
| iOS | 长按主屏幕空白处，编辑 → 添加小组件，搜索“成信友友” | 小卡显示下一节，中卡显示 2 节，大卡显示 5 节 |

点击卡片打开今天的课表；尚未登录时先进入登录页。正在浏览其他周或历史学期，也会回到当天所属学期。今日没有课程、课程已结束、校历未发布和未同步本学期都有明确提示。

已同步的整个学期可以离线显示，课程采用北京时间。服务器修改课程后需打开应用刷新，或点击“同步小组件课表”。本机课程修改会自动同步。新学期仍需打开应用加载新课表，小组件自身不访问教务服务。

退出或切换账号时清空共享课程并请求系统刷新；桌面完成刷新仍由系统调度。系统省电和刷新预算可能推迟显示，不承诺准确到秒的切换。

## 桌面卡片尺寸与调整

iOS 可以在同一个小组件里声明小、中、大三种尺寸；安卓没有这个机制，**添加时能选几个尺寸，取决于清单里注册了几个组件**。因此三个尺寸各注册一个接收者（`ScheduleWidgetSmallProvider`、`ScheduleWidgetProvider`、`ScheduleWidgetLargeProvider`），共用 `ScheduleWidgetProvider` 的渲染代码，只有默认格数与可调整范围不同。刷新、午夜闹钟与退出清空都遍历全部组件，只有在最后一个卡片被移除时才停掉闹钟。

三种尺寸都声明 `resizeMode="horizontal|vertical"`，并写死 `minResizeWidth/Height` 与 `maxResizeWidth/Height`。上限不能省：缺省时框架按 `0` 下发，由各家桌面自行解释，部分桌面会因此限制放大。上下限之间就是用户能拖出的范围；布局在同一份 `schedule_widget.xml` 里按高度决定显示 1–5 节，宽度小于 220dp 自动切成窄卡文案。

真机上仍看不到可拖动的边框时，按这个顺序排查：

1. 移除卡片重新添加一次。桌面会缓存组件信息，覆盖安装不会更新已存在卡片的能力。
2. 满宽卡片（4 列桌面上的 4×2）横向没有放大空间，纵向拖动最直观。
3. 确认系统实际识别到的能力，`dumpsys` 里应能看到三个组件及各自的 resize 模式：

```bash
adb shell dumpsys appwidget | grep -i -A 12 chengxin
```

如果里面只有旧组件、没有 `ScheduleWidgetSmallProvider`，说明手机上还是旧安装包。

## 一眼看懂数据流

```text
登录会话 → ScheduleViewModel / Repository / 本机课程
                    ↓
       DesktopWidgetController 选择实际当前学期
                    ↓
       createDesktopWidgetSnapshot 生成整学期摘要
                    ↓
       DesktopWidgets / MethodChannel（串行写入）
                ↙                  ↘
 Android 私有 SharedPreferences     iOS App Groups 原子 JSON 文件
                ↓                  ↓
 AppWidgetProvider / RemoteViews    WidgetKit / SwiftUI / Timeline
                ↓                  ↓
          系统桌面              系统主屏幕
```

排课规则只在 Dart 中执行，继续使用正式课表的 `buildScheduleEntries`、校历和节次时间。摘要保留冲突课程、实验课的实际时间、本机手动课程和覆盖修改；原生代码只按日期读取，并隐藏已结束的课程。摘要没有账号、密码、Cookie、Token 或学生个人资料。

`DesktopWidgetController` 与页面当前选中周分离，读取实际当天所属学期；历史学期排序不能直接用于当前学期，因此为摘要单独准备排序索引。主动同步时，页面也持有本学期数据就通过正式 ViewModel 一起刷新，避免切周后把旧数据写回桌面；正在浏览历史学期则单独加载本学期，不改变浏览内容。连续修改合并发布，切周、滚动和透明度调整不重复写入。销毁后拒绝旧异步结果，平台写入队列确保退出后的清空不会被旧任务覆盖。

## 代码位置

| 文件 | 职责 |
| --- | --- |
| `lib/core/platform/desktop_widgets.dart` | 小组件平台契约、通道、写入排序、点击回调 |
| `lib/features/schedule/models/desktop_widget_snapshot.dart` | 正式排课规则转换为版本化摘要 |
| `lib/features/schedule/presentation/desktop_widget_controller.dart` | 当前学期加载、监听修改、合并同步、状态提示 |
| `lib/features/schedule/presentation/desktop_widget_page.dart` | 添加说明、内容预览、主动同步 |
| `lib/app/app_dependencies.dart` / `app.dart` | 登录退出清理、依赖生命周期、点击后导航 |
| `android/.../MainActivity.kt` | 保存摘要、请求固定、处理冷／热启动点击 |
| `android/.../ScheduleWidgetProvider.kt` | RemoteViews、大小调整、刷新与点击 Intent，小／中／大三种入口共用 |
| `android/app/src/main/res/xml/schedule_widget_info*.xml` | Android 三种尺寸的默认格数与可调整范围，各对应清单里一个接收者 |
| `android/app/src/main/res/layout/schedule_widget*.xml` | Android 标题、课程和页脚布局 |
| `ios/Shared/ScheduleWidgetData.swift` | 主应用与扩展共用的数据模型、今日状态和时间轴 |
| `ios/Runner/DesktopWidgetBridge.swift` / `SceneDelegate.swift` | 原子共享写入、WidgetKit 刷新、系统链接 |
| `ios/ScheduleWidget/` | 独立 WidgetKit 扩展、SwiftUI 小中大布局、扩展权限 |

摘要版本为 `1`，包含 `status`、`message`、`semester`、`updatedAt` 和 `days`。每天包含 `date`、`week` 和 `courses`；课程包含稳定标识、名称、地点、时间文案、开始／结束毫秒时间戳、节次与颜色。时间不可解析时使用节次文案，不凭空生成时间。未登录等状态的 `days` 为空。原生端遇到损坏数据或未知版本显示空状态，不继续显示旧课程。

Android 使用半小时系统刷新，并为上下课、午夜安排非精确闹钟；接收日期、时间、时区、重启和更新广播。不申请精确闹钟权限。iOS 为当前日期的上下课与午夜预先提供 Timeline，应用发布摘要后请求 `reloadTimelines`。两端都不要求 Flutter 在后台常驻。

## iOS 签名与打包

主应用和扩展必须使用同一开发者团队，并同时启用 App Groups：

```text
主应用：org.dpdns.fanxiaogao05.chengxin.flutter
扩展：  org.dpdns.fanxiaogao05.chengxin.flutter.ScheduleWidget
共享组：group.org.dpdns.fanxiaogao05.chengxin.flutter
```

在 Xcode 登录可用开发者账号，分别给 `Runner` 和 `ScheduleWidget` 选择同一个 Team，在 Signing & Capabilities 中注册并选择上述共享组，生成包含该权限的主应用与扩展描述文件。Apple 当前的 [iOS 能力表](https://developer.apple.com/help/account/reference/supported-capabilities-ios) 已将 App Groups 列为免费 Apple Developer 账号可用；本机也已通过 Personal Team 实际生成这两份描述文件。配置依据见 [Apple App Groups 文档](https://developer.apple.com/documentation/xcode/configuring-app-groups)。

项目已为主应用和扩展的 Debug、Release、Profile 配置设置相同的开发签名团队。团队编号不是认证凭据；密码、私钥、证书和描述文件由本机 Xcode 与钥匙串管理，仓库不保存这些文件。更换开发者账号时，需要同时修改两个 Target 的 Team。

**本机 2026-10-08 真机签名已通过：** 先在 Xcode 的 Apple Accounts 中刷新描述文件，再在两个 Target 中选择已有 Personal Team。主应用与扩展的描述文件均包含上述 App Groups 和测试 iPhone 的设备标识。Release 完整构建成功，`codesign --verify --deep --strict` 通过，并已使用 `devicectl` 覆盖安装到测试 iPhone，保留原有应用数据。安装后查询确认新安装路径，应用启动命令也已成功。

这次主应用的开发描述文件于 **2026-10-15 17:25（北京时间）** 到期。到期前需要重新签名并安装；不能把这份个人开发签名包当作长期分发包。此前命令行的 `No Accounts` 不代表 Xcode 界面没有登录账号；本次通过界面的自动签名生成描述文件后，命令行已能使用本地描述文件完成签名。

直接调用 `xcodebuild` 时，需要沿用 `tool/flutter.sh` 建立的 `.dart_tool/local_toolchain` 路径，否则原生 Dart 构建钩子可能使用系统的 Command Line Tools 而找不到 iPhone SDK：

```bash
env PATH="$PWD/.dart_tool/local_toolchain:$PATH" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS'
```

这次包含 Kotlin、Swift、系统权限、扩展和原生资源，需要完整更新安装包，不能仅通过 Shorebird 的 Dart 补丁发布。

## 验证与复验

样本使用虚构账号和课程，不连接真实教务系统。

```bash
cd flutter
./tool/flutter.sh analyze
./tool/flutter.sh test

# Dart 测试生成两端共用的摘要样本。
./tool/flutter.sh test test/desktop_widget_test.dart

# 原生 Swift 模型验证，不需要签名或下载模拟器。
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swiftc ios/Shared/ScheduleWidgetData.swift \
  ios/Tests/ScheduleWidgetDataTests.swift -o build/widget-tests/ios-widget-tests
build/widget-tests/ios-widget-tests build/widget-tests/snapshot.json

# 在 Android 资源环境真正应用 RemoteViews，不使用安卓模拟器。
# ANDROID_HOME 应指向已安装的 SDK。
cd android
ANDROID_HOME=<已安装SDK绝对路径> ./gradlew :app:testDebugUnitTest --tests '*ScheduleWidgetProviderTest'
cd ..

# 使用已有 iOS 模拟器，驱动与测试通过本机端口 18765 协调系统链接。
WIDGET_TEST_DEVICE=<已有模拟器标识> ./tool/flutter.sh drive --no-pub \
  --driver=test_driver/desktop_widget_driver.dart \
  --target=integration_test/desktop_widget_test.dart \
  -d <同一模拟器标识>
```

`tool/desktop_widget_preview.dart` 是仅供开发验收的假数据入口，使用正式页面和原生通道；发布构建使用默认 `lib/main.dart`。集成测试截图记录添加说明页和打开课表流程，不是桌面小组件的实际截图。

2026-10-08 本机验证记录：

| 检查 | 结果 |
| --- | --- |
| Dart 格式、Flutter analyze、校历一致性 | 通过 |
| 全量 Flutter 测试 | 248 项通过，包含 10 项小组件测试和 3 项安卓课表布局测试 |
| Android 原生 RemoteViews | 4 项通过：大小调整、最小尺寸布局、点击 Intent、上下课、换日、退出、损坏数据与未知版本 |
| Swift 原生共享数据模型 | 通过：同一 Dart 摘要解码、冲突课程、上下课、北京时间换日、退出、时间轴 |
| iOS 模拟器原生流程 | 通过：实际 App Groups 文件、系统 URL → SceneDelegate → Dart → 今日课表、退出后共享文件清空 |
| Android Release APK | 构建通过，包含小组件 Provider 和原生资源，APK 签名校验通过；仍使用本地调试证书 |
| iOS 真机架构 Release 未签名编译 | 通过，主应用包含 `ScheduleWidget.appex`；未签名产物不能直接安装 |
| iOS 真机签名、安装与启动 | 通过：主应用及扩展均已签名，共享组权限匹配；完整 Release 已覆盖安装到测试 iPhone，安装后查询和应用启动成功 |

仍需在真实桌面手动添加、检查各尺寸与系统字体放大、切换明暗主题，并验证省电、重启、覆盖安装后的行为。Android 未连接设备，本次没有下载安卓模拟器。iOS 模拟器桌面窗口暂未能通过电脑控制工具连接，不能把模型、共享文件与跳转测试视为桌面排版验收。

2026-10-13 补齐三种尺寸入口：

| 检查 | 结果 |
| --- | --- |
| 静态契约 `test/android_widget_variants_test.dart` | 5 项通过：三种尺寸的目标格数、`resizeMode`、调整上下限、清单注册与标签唯一、三个组件共用一份渲染 |
| 小组件 Dart 测试 | 15 项通过（含 `test/desktop_widget_test.dart` 原有 10 项） |
| 安卓原生 RemoteViews | 5 项通过，新增 `sizeVariantsRenderFromTheSameProvider`：小卡按窄卡渲染 1 节、中卡 4 节，且一次刷新覆盖三个组件 |
| 合并后清单 `processDebugManifestForPackage` | 三个接收者、三份 provider 配置、三个不同标签均已合入 |
| 真实桌面添加列表出现小／中／大 | 待装机确认：本机无安卓设备与模拟器 |

原生测试在本机离线执行（只改原生代码、Dart 侧暂时编译不过时可跳过 Flutter 资源任务）：

```bash
cd android
JAVA_HOME=<JDK 17 绝对路径> ANDROID_HOME=<已安装 SDK 绝对路径> \
  ./gradlew :app:testDebugUnitTest --tests '*ScheduleWidgetProviderTest' --offline
# 需要绕开 Dart 编译时追加：-x compileFlutterBuildDebug -x copyFlutterAssetsDebug
```

三种尺寸的改动同样包含原生资源与清单，**不能只发 Dart 补丁**。
