# 工具二级页与 Vue 的对应关系

这次以 `apps/web/src/pages/` 下的原页面及对应 CSS 为依据，调整八个工具二级页的大体布局、信息层级、颜色、圆角和间距。日期、时间与分享继续使用系统面板。

| 页面 | 保留的原版布局 | Flutter 文件 |
| --- | --- | --- |
| 成绩 | 当前学期、已出成绩／挂科统计、分组明细与右侧分数；平时、期末、补考、绩点 | `grades_page.dart` |
| 考场安排 | 学期与考试批次筛选、今日考试、按日期分组；左侧时间、右侧课程和地点 | `exams_page.dart` |
| 空教室 | 首页节次选择、更多筛选底部弹层、按教学楼分组的结果与容量 | `classrooms_page.dart` |
| 校历 | 学年副标题、圆角原图查看区、放大／原图工具条与来源说明 | `calendar_page.dart` |
| 校园地图 | 两校区胶囊切换、圆角地图区、缩放工具条、保存与参考说明 | `campus_map_page.dart` |
| 历年试卷 | 共享库概览、搜索、面包屑、分组目录、文件类型标记与下载按钮 | `past_exams_page.dart` |
| 图书馆 | 三项预约类型、筛选卡、两列座位卡、确认弹窗、带操作按钮的预约记录 | `library_page.dart` |
| 校园跑与俱乐部 | 大标题、双栏运动进度、圆形执行按钮；货车装饰、签到与定时卡、日期活动区及独立子导航 | `autorun_page.dart` |

所有文件位于 `lib/features/tools/presentation/`。`academic_tool_pages.dart` 保留现有路由导出入口；成绩、考试、空教室分别维护自己的页面。公共学期筛选与空状态位于 `academic_tool_widgets.dart`。

`tool_page_scaffold.dart` 保留工具页的名称和返回提示，居中标题、44 像素圆形按钮、灰色背景、蓝色强调色及分组容器复用 `ui/components/page_layout.dart`。页面显式采用局部主题。分组使用轻量圆角表面；列表行没有重复叠加阴影和模糊。

普通字号沿用原版比例。小屏或大字体时，筛选、运动进度自动纵排，按钮标签允许换行，页面内容可滚动。现有服务、原项目图标、地图图片、预约校验及校园跑状态管理继续复用。

## 预览与验证

截图来自已有的 iPhone 17 Pro / iOS 26.5 模拟器。成绩、考试、教室、图书馆和校园跑使用隔离的虚构 HTTP 样例；校历读取教务处原图，地图与资料目录使用项目现有资源。测试没有向真实服务提交预约、运动记录或报名。

| 页面预览 | 截图 |
| --- | --- |
| 成绩 | [浅色](../screenshots/tools-grades.png) / [深色](../screenshots/tools-grades-dark.png) |
| 考场安排 | [预览](../screenshots/tools-exams.png) |
| 空教室 | [首页](../screenshots/tools-classrooms.png) / [筛选弹层](../screenshots/tools-classrooms-filters.png) / [结果](../screenshots/tools-classrooms-results.png) |
| 图书馆 | [筛选](../screenshots/tools-library.png) / [座位](../screenshots/tools-library-seats.png) / [确认](../screenshots/tools-library-confirm.png) / [记录](../screenshots/tools-library-reservations.png) |
| 历年试卷 | [预览](../screenshots/tools-past-exams.png) |
| 校园地图与校历 | [地图](../screenshots/tools-campus-map.png) / [校历](../screenshots/tools-calendar.png) |
| 校园跑 | [登录](../screenshots/tools-autorun-login.png) / [进度](../screenshots/tools-autorun.png) / [俱乐部](../screenshots/tools-club.png) / [账号](../screenshots/tools-autorun-account.png) |

新增组件测试验证弹层校区选择与查询参数、成绩统计与分项、座位预约参数，以及八个二级页在 320 像素宽、1.5 倍字体下的布局和主要交互。模拟器集成测试验证正式页面的渲染、筛选弹层、座位确认与子页切换。

2026-10-06 验证结果：

| 检查 | 结果 |
| --- | --- |
| Dart 格式与 Flutter 静态检查 | 通过，无问题 |
| 全量 Flutter 测试 | 219 项通过 |
| 校历资源一致性与热更新脚本测试 | 通过 |
| iOS 模拟器页面交互与截图 | 通过，17 张截图已更新 |
| Android 调试包与 iOS 模拟器调试构建 | 通过 |

```bash
./tool/flutter.sh test --no-pub test/tool_pages_test.dart
./tool/flutter.sh drive --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/tool_pages_preview_test.dart \
  -d <已有模拟器标识>
```

真实账号数据、文件下载与系统分享的外部服务结果，以及安卓真机性能，需在对应设备和账号上验收。
