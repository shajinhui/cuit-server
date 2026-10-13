# 登录、校园与个人中心 UI 优化

这轮继续以原 Vue 页面及 CSS 为依据，统一灰色背景、圆角分组、文字层级和标题栏。正常字号保留原版的大体结构；小屏与大字体优先保证内容、筛选和按钮可用。

| 页面 | 调整内容 | 主要文件 |
| --- | --- | --- |
| 登录 | 居中品牌、圆角登录面板、两行分组输入、胶囊登录按钮；保留密码显隐、错误提示、帮助和体验入口 | `session/presentation/login_page.dart` |
| 我的 | 96 像素头像、居中姓名与学籍摘要、分组信息和菜单、轻量效果与外观设置、独立退出按钮 | `session/presentation/profile_page.dart` |
| 头像选择 | 弹层覆盖主导航，继续使用原项目 15 个头像与相册入口 | `profile/presentation/profile_avatar_button.dart` |
| 学业完成情况 | 学分与百分比概览、绩点和审核结果、分类明细；课程左侧信息、右侧成绩和状态 | `profile/presentation/plan_completion_page.dart` |
| 问题反馈 | 交流群提示、类型与平台分组选择、独立描述卡与字数、提交状态 | `profile/presentation/feedback_page.dart` |
| 关于 | 独立页面、原项目应用图标、介绍和分组链接；数据与隐私、源码、开源许可 | `profile/presentation/about_page.dart` |
| 校园首页 | 居中评分／二手切换、白色搜索框、蓝色引导卡和紧凑列表；切换栏目回到顶部 | `campus/presentation/campus_page.dart` |
| 评分板块与对象详情 | 80 像素小封面、标题作者与介绍、评分分布、评论区、底部添加／评论操作 | `rating_board_page.dart` / `rating_item_page.dart` |
| 二手与求购 | 出售保留两列图片卡，求购没有图片时直接展示描述；价格、校区换行，大字体改为单列 | `campus_page.dart` / `marketplace_item_page.dart` |
| 发布与我的内容 | 统一标题栏、圆角表单和分类切换；缩小空图片选择区，保留校验与操作 | `rating_editor_page.dart` / `marketplace_editor_page.dart` / `ratings_mine_page.dart` / `marketplace_mine_page.dart` |
| 课表弹层 | 修复课程编辑中节次、周次下拉框的大字体溢出；七列网格、排课、切周和详情规则继续沿用 | `schedule/presentation/widgets/course_editor_sheet.dart` |

文件位于 `lib/features/` 对应功能目录。公共页面样式在 `lib/ui/components/page_layout.dart`：`PageScaffold`、`PageCard`、`PageSegmentedControl` 等普通组件直接组合，不引入新的状态框架或依赖。`tool_page_scaffold.dart` 保留工具页原有名称和返回提示，复用同一实现。

校园封面只在资源标识或数据源改变时重新加载。搜索输入触发重建时复用已有 Future，减少重复请求和占位图闪烁。校园作者头像支持原项目的预设头像资源。

## 模拟器预览

使用已有 iPhone 17 Pro / iOS 26.5 模拟器，运行正式应用路由和页面。账号、课表、校园与培养方案采用虚构测试数据；没有向真实服务提交评分、评论、商品或反馈。

| 页面 | 截图 |
| --- | --- |
| 登录与课表 | [登录](../screenshots/pages-login.png) / [课表](../screenshots/pages-schedule.png) |
| 课表弹层 | [详情](../screenshots/pages-course-detail.png) / [编辑](../screenshots/pages-course-editor.png) |
| 个人中心 | [浅色](../screenshots/pages-profile.png) / [深色](../screenshots/pages-profile-dark.png) / [头像](../screenshots/pages-avatar-picker.png) |
| 学业、反馈、关于 | [学业](../screenshots/pages-plan-completion.png) / [反馈](../screenshots/pages-feedback.png) / [关于](../screenshots/pages-about.png) |
| 校园评分 | [首页](../screenshots/pages-campus.png) / [板块](../screenshots/pages-rating-board.png) / [对象](../screenshots/pages-rating-item.png) |
| 校园二手 | [出售](../screenshots/pages-marketplace.png) / [求购](../screenshots/pages-wanted.png) / [详情](../screenshots/pages-marketplace-item.png) / [发布](../screenshots/pages-marketplace-editor.png) |

## 验证

组件测试覆盖 320 像素宽、1.5 倍字体、深色模式下的校园首页和九种二级页面状态、个人中心、学业与反馈，以及课表详情、课程编辑、日历弹层。单独检查封面重建复用请求；原有登录、查询、预约、发布表单校验、课表计算与状态测试继续运行。

```bash
./tool/flutter.sh test --no-pub
./tool/flutter.sh drive --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/other_pages_preview_test.dart \
  -d <已有模拟器标识>
```

本轮验证使用模拟器与隔离样例；真实服务数据、外部链接和安卓真机帧率不由截图测试证明。

### 2026-10-06 验证记录

| 检查 | 结果 |
| --- | --- |
| Dart 格式检查 | 127 个文件，无需调整 |
| Flutter 静态检查 | 通过，无问题 |
| 全量组件与单元测试 | 223 项通过 |
| 校历同步检查 | 与原项目一致 |
| Shorebird 工具测试 | 7 项通过 |
| iOS 模拟器页面预览 | 进入、返回、切换流程通过，生成并检查 17 张截图 |
| Android 调试构建 | 通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk` |
| iOS 模拟器正式应用构建 | 通过，已安装并启动在已有 iPhone 17 Pro 模拟器 |

本轮更新了模拟器应用，尚未将这些页面调整安装到实体手机。

### 2026-10-09 安卓字体放大布局修复

检查安卓 320 像素宽屏幕在 1～3 倍系统字体下的工具首页时，发现工具卡片固定 124 像素高会让入口名称撑出卡片。现在卡片在大字体下使用 152 像素高度，入口名称允许两行，并把卡片内部文字缩放上限设为 1.5 倍；页面仍可上下滚动，普通字号的两列布局不变。

新增 `test/android_pages_layout_test.dart`，覆盖工具首页三档字体、底部安全区、四个主入口切换和滚动。Flutter 静态检查通过，全量 **252 项**测试通过。新的 Android Release APK 已构建并通过 APK v2 签名校验：`build/app/outputs/flutter-apk/chengxin-youyou-android-layout-fix2.apk`。

### 2026-10-08 安卓课表布局修复

针对安卓截图中的三处问题调整 `schedule_header.dart` 和 `course_grid.dart`：

- 日期和当前周提示独立于下方操作行；宽度不足时提示自动换行，周次胶囊不再覆盖日期。
- 添加、同步、更多按钮的玻璃外观缩到 36，图标缩到 22；保留 44 的点击范围。
- 根据 Scaffold 提供的实际导航高度缩小课表视口，滚动内容也不绘制到导航下方。空间足够时前 11 节铺满可见区域，小屏保留最低行高，通过滚动查看剩余节次。

`test/android_schedule_layout_test.dart` 在完整应用路由中验证 320、360、440 宽屏幕，包括底部安全区、两倍系统字体时增高的导航、日期显示、按钮触摸范围、初始节次位置、滚动到最后一节以及选周操作。iOS 继续使用已有顶部与网格布局。

本次使用 Flutter 安卓平台组件测试，没有连接安卓真机或下载模拟器，不能把几何布局验证当成安卓真机截图或帧率验收。

格式与 Flutter 静态检查通过，全量 248 项测试通过；其中新增 3 项完整应用布局回归测试。

Android Release 构建与 APK 签名校验通过，安装包为 `build/app/outputs/flutter-apk/chengxin-youyou-android-layout-fix.apk`，包含桌面小组件。使用原有本地测试签名，需在手机安装新版后核对实际显示。
