# 成信友友 · Flutter

已迁移 **登录、课表、工具、校园和个人中心的常用业务页面**，并补齐校园跑、学业完成情况、问题反馈和本机头像。工程位于仓库根目录 `flutter/`，与已有 Vue / Capacitor 客户端并存，复用原服务接口。

## 先运行

验证工具链：Flutter **3.47.5 stable**、Dart **3.13.4**。依赖以 `pubspec.lock` 为准，不随意执行全量升级。

```bash
cd flutter
python3 tool/sync_calendar.py --check
./tool/flutter.sh pub get
./tool/flutter.sh devices
./tool/flutter.sh run -d <设备标识>
```

默认进入登录页。点击 **先体验一下** 可查看虚构课表，无需账号，不访问教务接口。也可在启动时直接进入体验：

```bash
./tool/flutter.sh run -d <设备标识> --dart-define=DEMO_MODE=true
```

`tool/flutter.sh` 优先使用 `FLUTTER_BIN`，其次是 PATH 中的 Flutter，最后尝试本机隔离安装目录 `~/.local/share/cuit-flutter-sdk/bin/flutter`。macOS 下会为构建进程选择已安装的 Xcode，并为 Dart 原生构建钩子包装 `xcrun`，不修改全局 `xcode-select`。

Android 需要 Android SDK 和 JDK。可通过 `ANDROID_HOME`、`JAVA_HOME` 指定。当前机器的调试构建环境位于 `~/.local/share/cuit-android-sdk`；发布签名没有配置，当前 release 配置也仅供本地验证，不能直接上架。

iOS 模拟器无需个人签名。真机安装需要在 Xcode 给主应用和 `ScheduleWidget` 扩展选择同一 Team，并配置包含 App Groups 的签名；步骤与本机签名限制见 [桌面小组件](docs/DESKTOP_WIDGETS.md)。项目中现有 Team 是本机开发签名配置，其他开发者需要改为自己的团队；证书、私钥、描述文件和密码不进入仓库。新客户端使用独立包名 `org.dpdns.fanxiaogao05.chengxin.flutter`，避免覆盖现有客户端。

## 热更新

客户端通过 `shorebird_code_push` 接入 Shorebird，启动后在后台检查并下载补丁，不等待更新完成才展示页面。“我的 → 关于 → 检查更新”显示检查、下载、失败重试与下次启动生效的状态；下载完成后不强制退出 App。启动和手动操作合并同一个更新任务。普通 Flutter 构建、Debug 和 iOS 模拟器没有补丁运行时，入口显示当前安装包暂不支持在线更新。

**项目已绑定真实 Shorebird 应用；启用热更新仍需分发一次包含 Shorebird 引擎的基础安装包。** `shorebird.yaml` 已生成并加入资源列表，既有项目应沿用该配置，不重复执行 `init`。其他开发机按 [Shorebird 官方指南](https://docs.shorebird.dev/getting-started/)安装 CLI 后，在本目录执行：

```bash
./tool/shorebird.sh login
./tool/shorebird.sh validate

# 确认 Shorebird 支持 .flutter-version 中的 3.47.5。
./tool/shorebird.sh flutter versions list

# 使用 Shorebird 引擎构建，并按正常流程签名、分发基础安装包。
./tool/shorebird.sh release android
./tool/shorebird.sh release ios

# 修改 Dart 代码后，明确指定基础版本。此例对应当前 0.1.0+2。
./tool/shorebird.sh patch android 0.1.0+2 --track staging
./tool/shorebird.sh patch ios 0.1.0+2 --track staging
```

`init` 生成真实 `shorebird.yaml` 并将其加入 `pubspec.yaml` 的资源列表，随后设置 `auto_update: false`，由客户端统一检查和下载，避免与引擎自动更新重复执行。生成的配置应提交到版本控制；app_id 是公开标识，登录令牌不进入仓库。已有 Shorebird 应用请沿用其真实配置和标识，不重新创建应用，并确保 `auto_update: false` 与资源声明齐全。

基础版本固定使用 `.flutter-version`；补丁使用该基础版本记录的 Flutter 引擎。`SHOREBIRD_BIN` 可指定 CLI 路径。开发用 `flutter build` 产物不包含热更新引擎，正式热更新安装包必须使用 `shorebird release` 构建。当前 Android release 仍需要配置正式签名；iOS 已有 Team 配置，仍需验证主应用与小组件的真机签名和发布描述文件。

补丁先发布到 staging，按[官方测试流程](https://docs.shorebird.dev/code-push/guides/staging-patches/)预览对应基础版本，验证首次启动下载、结束进程后再次启动生效，再通过 Shorebird 控制台将该补丁提升到 stable；客户端默认只接收 stable。iOS 补丁必须用真机测试，Android 可以用模拟器。旧基础版本需要单独发布补丁，发布新基础版本时才修改安装包版本号。

热更新范围为 Dart 代码、Flutter 页面和纯 Dart 依赖；原生插件实现、权限、Flutter 引擎与打包 assets 的修改需要新安装包。补丁撤回后也要再次启动才能切换到回滚版本。本机已下载的补丁或回滚通过本地状态识别，断网不误报为未更新。范围与机制见 [Shorebird 官方文档](https://docs.shorebird.dev/code-push/)。

2026-10-13 已完成账号登录、真实应用绑定和配置检查；基础版本发布和真实补丁下发尚未验收。代码与脚本的本地验证记录见 `test/app_update_test.dart` 与 `tool/test_shorebird.py`，不能将普通 Debug 构建成功视为 OTA 验收。

2026-10-06 本地验证：

| 检查 | 结果 |
| --- | --- |
| Dart 格式、Flutter analyze、校历一致性 | 通过 |
| Flutter 单元与组件测试 | 212 项通过，包含 11 项更新状态、并发、重试和入口验证 |
| 发布脚本隔离测试 | 7 项通过，不连接账号、不上传补丁 |
| Android Debug / iOS Simulator Debug 构建 | 通过 |
| iOS 模拟器使用真实 SDK 检测运行时、展示更新入口 | 通过；普通 Debug 包正确提示不支持在线更新 |
| 本机 Shorebird CLI | 已安装 1.6.124；已查询确认支持项目 Flutter 3.47.5 |
| 账号绑定与项目配置（2026-10-13 复验） | 通过；真实 app_id、资源声明与 auto_update: false 已配置 |
| 正式基础包、真实补丁下载及生效 | 待配置平台发布签名并发布基础包后验收 |

复验原生运行入口（使用已有 iOS 模拟器）：

```bash
./tool/flutter.sh drive --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_update_test.dart \
  -d <已有 iOS 模拟器标识>
```

## 本版内容

| 页面 | 已实现 |
| --- | --- |
| 登录 | 学号、密码校验，密码显隐，提交防重，中文错误，登录恢复，退出清理，独立演示入口 |
| 课表 | 沿用原版日期标题、顶部选周、七列网格；连续课／冲突课合并、非本周淡显、完整详情、本机增删改、配色、透明度、ICS 日历导出 |
| 导航 | 课表、工具、校园、我的；保留各分支状态；选中背景短动画；原生液态玻璃和磨砂降级 |
| 工具 | 成绩、考场、空教室、校历、校园地图、历年试卷、图书馆预约／续座、校园跑与俱乐部 |
| 校园 | 论坛分类、发帖、回复与点赞；评分广场、创建板块／对象、评分／评论／回复／举报、我的内容；二手发布、筛选、联系方式、状态管理 |
| 我的 | 账号信息、15 个原版头像／相册裁剪、学业完成情况、问题反馈、主题、轻量效果、退出 |
| 热更新 | 后台检查与下载、个人中心手动检查、失败重试、下次启动生效提示；实际分发需 Shorebird 账号和基础安装包 |
| 桌面小组件 | Android 可调整卡片大小，iOS 支持小／中／大卡；今日课程、下一节课、点击回到今天、退出清空；iOS 真机需 App Groups 签名 |

桌面卡片入口在“我的 → 桌面小组件”。添加方式、数据流、平台代码、测试和当前 iOS 签名限制见 [桌面小组件](docs/DESKTOP_WIDGETS.md)。新增原生扩展和资源需要安装完整更新包。

原有业务入口已有对应页面。校园跑沿用独立账号与独立服务，支持进度、生成并提交记录、俱乐部报名／取消、签到／签退、日期查询和服务端定时配置；头像与原 Vue 一样仅保存在本机，按账号隔离。

旧 WebView 本机数据的自动导入和旧 Capacitor 更新机制尚未实现。已加入 `ohos/` 工程与鸿蒙平台插件，构建入口和限制见 [鸿蒙构建说明](ohos/README.md)；目前不能据此宣称鸿蒙构建及真机运行已经通过。接口联调范围与真实设备验收见下方验证记录；页面迁移完成不等同于所有真实账号都已验收。

## 一眼看懂代码

```text
lib/
├── main.dart                  启动、等待、启动失败重试
├── app/
│   ├── app.dart               应用、路由和登录访问控制
│   ├── app_dependencies.dart  创建依赖、按会话创建／释放课表对象
│   └── app_shell.dart         四个导航分支的容器
├── core/
│   ├── config/               API 配置和主题／效果偏好
│   ├── network/              Dio、响应外壳、原生／Web Cookie 适配
│   ├── platform/             桌面小组件通道、点击与原生数据同步
│   └── storage/              安全存储、文件缓存、Web 内存实现
├── features/
│   ├── session/              教务登录、会话与个人中心入口
│   ├── schedule/             课表模型、缓存、状态与页面
│   ├── campus/               评分、评论、二手与独立校园认证
│   ├── autorun/              独立凭证、轨迹、状态与校园跑业务
│   ├── profile/              头像、培养方案、反馈的数据与页面
│   ├── app_update/           Shorebird 适配、更新状态与检查入口
│   └── tools/presentation/   工具入口和各服务页面
└── ui/                       统一主题与无业务含义的共用组件
```

数据流：**页面 → ViewModel（复杂流程）→ Repository → API／缓存**。简单表单和读取页面用局部状态调用 Repository；课表与校园跑把并发和会话规则集中在 ViewModel。业务计算和数据请求不放在 `build()` 中。按功能扩展，不新增通用基类、全局服务定位器或无必要的代码生成。注释用中文说明原因和业务规则。

完整规则见 [架构与编码规范](../docs/architecture/FLUTTER_ARCHITECTURE.md)。新增功能先提供小而明确的 Repository 契约，再实现状态与页面；由 `app_dependencies.dart` 组装。

## 接口与数据

默认 API 为现有公开服务地址 `https://api.fanxiaogao05.dpdns.org`。开发环境覆盖方式：

```bash
./tool/flutter.sh run --dart-define=API_BASE_URL=https://your-api.example.com
```

| 接口 | 用途 |
| --- | --- |
| `POST /api/v1/jwxt/session` | 提交 `username` 和 `password` |
| `GET /api/v1/jwxt/session` | 校验已有会话 |
| `DELETE /api/v1/jwxt/session` | 退出会话 |
| `GET /api/v1/jwxt/profile` | 获取并验证学生身份 |
| `GET /api/v1/jwxt/semesters` | 学期目录 |
| `GET /api/v1/schedule/current-week` | 当前教学周兜底数据 |
| `GET /api/v1/jwxt/course-table?semester_id=...` | 学期课表；主动更新追加 `refresh=1` |
| `GET /api/v1/jwxt/plan-completion` | 培养方案预审、学分完成度与课程明细 |
| `POST /api/v1/feedback` | 建议／Bug、Android／iOS、10–2000 字正文 |

教务、图书馆与反馈采用现有 `code / message / data` 响应结构。校园评分与二手通过教务服务签发独立 Bearer 凭证。

论坛也复用独立校园凭证，默认请求 `https://lehi.top/api/v1/forum/*`。2026-10-14 已部署校园后端论坛模块，生产 MySQL 8 的 `004_forum` 迁移及 NGINX 代理已验证；新环境同样需要这些服务端配置，不能只更新客户端。帖子与楼中楼不落盘，刷新重读展开回复，详情返回后列表同步；修改回复正文或目标时换新幂等键，原样重试保留旧键。删除主回复会同时软删除楼中楼，由服务端重新确认计数。举报沿用校园举报接口的 `forum_thread/forum_reply` 类型。

校园跑地址通过 `AUTORUN_API_BASE_URL` 覆盖，默认沿用原 Vue 地址。它使用 `code / msg / response` 外壳和 `POST /api/{action}`，不共享教务 Cookie；只将 `sessionKey` 写入系统安全存储，不保存密码。请求按顺序处理凭证轮换；退出取消请求并清除凭证，返回前台校验是否过期。移动端显式管理本服务 Cookie，并通过系统安全存储保存；密码不落盘，不输出请求正文日志。认证请求不跟随重定向。主服务 401 触发退出，普通断网保留页面数据。

课表缓存按 **API 地址 + 学号 + 缓存版本 + 学期** 隔离，保存于应用私有目录。首次进入优先读缓存，主动更新请求服务端；沿用原版最近学期缓存优先规则，主动刷新或切换学期更新目录，离线保留已有课表。退出立即释放旧 ViewModel、取消请求，再清理该账号缓存及凭证，过期响应不能重新写回。文件写入采用临时文件替换，读写删除按顺序协调。

启动时先校验本机已有身份；网络不可用时允许已验证身份查看缓存并显示离线恢复提示。首次校验可能等待网络超时。没有本机身份时不能进入真实账号课表。未知校历显示“校历待更新”，不猜日期；教学周沿用原版设备本地日期规则，日历导出固定使用 Asia/Shanghai 时区。

校历唯一来源为 `../shared/academiccalendar/calendars.json`：

```bash
python3 tool/sync_calendar.py          # 更新资源副本
python3 tool/sync_calendar.py --check  # 构建前检查
```

## 液态玻璃

安卓导航使用 MIT 开源 [liquid_glass_easy](https://pub.dev/packages/liquid_glass_easy)，固定版本 `4.3.4`，第三方 API 限定在 `ui/components/`。支持 Shader Filter 时使用实时折射和弹簧选中胶囊，也可短长按后拖动切页；原项目的四个 PNG 图标、导航比例和路由继续沿用。iOS 继续使用 UIKit 原生导航。

不支持折射的设备，以及“我的 → 轻量效果”开启时，使用通透磨砂，不捕获整页模拟折射。系统高对比度使用实色，减少动态效果时取消选中项移动动画。字体放大时导航高度随文字增长。[方案比较与性能验证说明](docs/LIQUID_GLASS.md)记录了实现、截图和验收范围；模拟器预览不代表安卓真机帧率。

## 检查与截图

```bash
./tool/check.sh
# 另用 SDK 的 dart 执行格式检查：
dart format --output=none --set-exit-if-changed lib test integration_test test_driver

./tool/flutter.sh build apk --debug
./tool/flutter.sh build ios --simulator --debug

./tool/flutter.sh drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  -d <iOS模拟器标识>
```

单元／组件测试覆盖接口错误、登录防重、身份恢复、缓存隔离、迟到请求、学期竞态、校历边界、重叠课程、切周／详情／导航／退出、小屏和放大字体。iOS 集成流程验证安全存储、文件缓存和演示交互，截图导出到 `screenshots/`。

- [登录页](screenshots/ios-login.png)
- [课表与导航](screenshots/ios-schedule.png)
- [课程详情](screenshots/ios-course-detail.png)
- [添加课程](screenshots/ios-course-editor.png)
- [日历导出](screenshots/ios-calendar-export.png)
- [深色课表](screenshots/ios-schedule-dark.png)

本版发布范围为 Android / iOS。虽然保留 Web 壳和浏览器适配代码，上游玻璃包的着色器仍会在 Web 构建阶段失败，运行时磨砂降级无法绕过资源编译；当前不提供可运行的 Flutter Web 预览。正式 Web/PWA 继续使用原 Vue 工程，未来如需 Flutter Web，先替换或适配渲染依赖再验收。

原生鸿蒙已有 `ohos/` 工程、独立 Flutter OH 工具链入口与本地平台插件，仍需单独验证 HAP 构建、签名、Cookie、安全存储与渲染降级。版本与运行步骤见 [鸿蒙构建说明](ohos/README.md)，不能将 Android APK 兼容视作原生鸿蒙支持。

## 首版验证记录（2026-09-30）

| 检查 | 结果 |
| --- | --- |
| Dart 格式、Flutter analyze、校历资源一致性 | 通过 |
| 数据、ViewModel、组件、文件缓存测试 | 140 项通过（含 117 组原版结果对照、ICS 逐字对照） |
| Android debug APK 构建 | 通过，产物 `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS Simulator debug 构建 | 通过，iPhone 17 Pro / iOS 26.5 |
| iOS 原生存储及完整体验流程 | 通过；截图已检查 |
| Flutter Web release 构建 | 未通过，上游玻璃着色器不兼容 SkSL，见上方平台说明 |
| 真实账号、Android / iOS 真机性能、原生鸿蒙 | 未验证 |

真实教务账号登录和安卓真机性能仍需在用户设备上验收；本次自动化不使用真实账号密码。

## 源码上传检查（2026-10-13）

首次将 Flutter 工程纳入 Git 时，校历同步检查、7 项发布脚本测试、Flutter 静态检查及全量 **267 项**单元与组件测试均通过，应用与测试代码的 Dart 格式已统一。第三方鸿蒙插件源码保留上游许可证与自身构建配置，生成器和其他平台实现不纳入主应用的静态检查，需使用对应插件工具链另行验证。

源码、资源、演示截图和文档进入版本控制；构建缓存、APK／IPA、私钥、签名证书、描述文件与本机 SDK 路径配置不提交。以上检查不替代 Android／iOS／HarmonyOS 的真机验收。

## 课表与原版的对应关系

以 `apps/web/src/pages/SchedulePage.vue`、`features/schedule/model/`、`styles/schedule.css` 为对照来源。底部导航继续使用本次重写所要求的液态玻璃方案。

| 原版内容 | Flutter 实现 |
| --- | --- |
| 日期标题、周次菜单、日期栏、顶部操作 | `schedule_header.dart`、`schedule_week_strip.dart` |
| 40 宽时间栏、七个等宽日期列、前 11 节填满视口 | `course_grid.dart` |
| 合并完整连续安排、当前周连续课、冲突链和非本周避让 | `schedule_layout.dart` |
| 详情保留所有课程安排，实验课显示精确时间 | `course_detail_sheet.dart`、`course_block.dart` |
| 本机添加／修改／删除、单双周与不规则周次 | `course_editor_sheet.dart`、`schedule_local_store.dart` |
| 自动／自定义 15 色、非本周透明度 | `course_palette.dart`、`ScheduleViewModel` |
| 当前周、历史学期、前后台切换／返回课表重置周次 | `academic_calendar.dart`、`ScheduleViewModel` |
| 导出 ICS，提醒 0／5／10／15／30 分钟，系统确认导入 | `calendar_export.dart`、`share_calendar.dart` |

原版通过顶部菜单切周；第一版自行增加的上一周／下一周按钮、左右滑动切周和下拉刷新已移除。课程修改和配色按账号、学期隔离，仅在本机生效，刷新不覆盖本机修改。新客户端不会自动读取旧 WebView 的 IndexedDB，旧数据迁移仍需独立验收。

工具页沿用原版入口、图标和名称搜索，卡片使用 Flutter Material `Card` 与 `InkWell`。具体业务页面已接入，校园跑子导航也沿用原项目的校园跑、俱乐部与个人图标。

八个工具二级页已按 Vue 的主要布局调整：居中标题与圆形返回按钮、筛选卡与弹层、分组明细、座位网格、资料目录和图片工具条。页面对应关系、截图及验证方式见 [工具二级页 UI 对照](docs/TOOLS_UI_PARITY.md)。

登录、个人中心、学业、反馈、关于和校园页面也已继续对齐原版，并修复课程编辑及评分列表的大字体溢出。文件组织、截图和验证范围见 [其他页面 UI 对照](docs/OTHER_PAGES_UI_PARITY.md)。

下拉选择、操作菜单、定位菜单、对话框和底部弹层已统一为公共组件，并接入课表、工具、校园和我的页面。组件职责、调用示例与维护规则见 [公共 UI 组件](docs/UI_COMPONENTS.md)。

对照样例由原版 TypeScript 函数直接生成，覆盖演示数据 0–20 周、空周次、连续安排、冲突链、实验课、中文默认色和 80 组固定种子组合；比较完整条目和完整显示分组。ICS 比较包含中文 UTF-8 折行、稳定 UID、本机覆盖与提醒。

```bash
# 原版规则改动后重新生成样例，再审查期望值变化。
node tool/generate_schedule_reference.cjs
./tool/flutter.sh test test/schedule_parity_test.dart
```

中文排序由系统 ICU 提供，准备好顺序后在 Dart 中比较索引；切周、滚动、透明度和配色调整不重复调用平台排序。`packages/native_collator` 基于 MIT 上游 1.0.2 补充 SPM 清单，使 iOS 无需 CocoaPods；平台侧返回排序索引，原始字符串保留在 Dart，避免分隔符在跨平台传输中丢失；来源、变更和移除条件见该目录 README。核心业务模型只使用普通 Dart 类型。鸿蒙目前使用 Dart 确定性排序降级，中文拼音顺序尚未适配；文件分享已接入固定的 OHOS 实现，仍需真机验证。

验证结论只覆盖样例和已运行设备。字体、系统选择／分享面板和仓鼠加载动画的绘制方式存在原生实现差异，尚未宣称逐像素一致；安卓真机滑动性能与真实教务账号数据仍需验收。

## 补齐迁移与修复（2026-10-06）

新增业务、与 Vue 的对应关系、审查问题修复和本次验证结果见 [迁移补齐记录](docs/MIGRATION_COMPLETION.md)。

```bash
node tool/generate_autorun_reference.cjs
./tool/flutter.sh test test/autorun_parity_test.dart
./tool/flutter.sh drive --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/migration_flow_test.dart \
  -d <已有 iOS 模拟器标识>
```

校园跑与培养方案的对照数据由仓库原 Vue 函数生成；校园跑 HTTP、写操作与反馈测试使用隔离的假响应，未向真实服务提交记录、报名、签到或反馈。
