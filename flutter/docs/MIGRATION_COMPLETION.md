# Flutter 迁移补齐记录

更新日期：2026 年 10 月 6 日。

本次补齐上轮审查指出的四项业务缺口，并修复已确认的问题。沿用原 Vue 的接口、业务规则、图标、头像和地图资源，新增代码采用普通 Dart 类、明确的状态字段和中文业务注释。

## 本次完成的功能

| 功能 | 已完成的行为 | 代码入口 |
| --- | --- | --- |
| 校园跑与俱乐部 | 独立登录／恢复／退出、有效次数与距离、两校区轨迹与完整记录提交、日期查询、报名／取消、签到／签退、倒计时、服务端定时配置、过期与上游错误提示 | `lib/features/autorun/`、`lib/features/tools/presentation/autorun_page.dart` |
| 学业完成情况 | 总体学分、完成度、GPA、审核信息、分类要求、课程学分／成绩／状态／备注、刷新与错误恢复 | `lib/features/profile/models/plan_completion.dart`、`lib/features/profile/presentation/plan_completion_page.dart` |
| 问题反馈 | 建议／Bug、Android／iOS、10–2000 字校验、提交防重、失败保留内容、成功清空、原项目 QQ 群入口 | `lib/features/profile/presentation/feedback_page.dart` |
| 本机头像 | 原项目 15 张预设头像、相册选择、居中裁为 512×512、账号隔离、恢复头像、小屏弹窗滚动 | `lib/features/profile/data/profile_avatar.dart`、`lib/features/profile/presentation/profile_avatar_button.dart` |

个人中心的两个新页面通过 `ProfileRepository` 复用主服务 Cookie。体验账号不请求真实培养方案、不发送反馈。头像仅保存在本机，不上传服务器。

校园跑使用独立 Dio 客户端和 `sessionKey`，不携带教务 Cookie，也不保存密码。请求及凭证恢复按顺序执行，防止旧凭证覆盖轮换后的新值；退出取消旧请求、等待旧写入结束，再删除凭证。返回前台校验登录状态，过期时清空账号数据。定时任务由现有服务端执行，手机退到后台不执行本地轮询任务。

## 审查问题修复

| 原问题 | 修复行为 |
| --- | --- |
| 旧校园请求在账号切换后遇到 401，可能使用新账号凭证重发 | 请求绑定会话代数，切换时取消请求；响应与重试前校验会话 |
| 图书馆页面关闭后，能力响应继续触发加载 | 初始化等待能力请求后检查 `mounted`，关闭时使旧请求编号失效 |
| 图书馆旧座位响应覆盖新自修室内容 | 座位、区域与预约查询检查请求编号，只提交当前结果 |
| 最终成绩为空字符串时未展示总评，也漏算未通过课程 | 展示及汇总共用“非空最终成绩 → 非空总评 → 无数据”的规则 |
| 图书馆忽略必填备注与服务端长度限制 | 读取预约能力，规则加载失败时阻止预约；弹窗校验必填、长度与验证码 |
| 未展开旧回复时发新回复，会把新回复当成完整缓存 | 只向已加载列表追加；首次回复后读取服务端完整回复列表 |
| 校园图片读取失败后永久复用失败缓存 | 失败／空结果移出缓存，再次进入可重新请求；成功仍复用缓存 |
| 价格 1.20 显示为替换占位符 | 用匹配回调保留捕获小数位，正确显示 1.2 |

交互测试还修复了图书馆预约弹窗的控制器释放时机：控制器由弹窗组件持有，退场动画结束、组件移除时才释放。预约参数在发起时保存，避免读取验证码期间改变筛选条件后串单。

## 本次验证

| 检查 | 结果 |
| --- | --- |
| Dart 格式、Flutter analyze、校历资源一致性 | 通过，静态检查无问题 |
| 单元与组件测试 | 201 项通过，包含全部原有测试及本次回归测试 |
| Vue 跨语言对照 | 原版函数直接生成期望数据；有效进度、活动状态、签到窗口、校区、学分完成度及两校区完整提交记录通过对照 |
| Android debug APK | 构建通过；`build/app/outputs/flutter-apk/app-debug.apk` |
| iOS Simulator debug 与新增流程 | 构建通过；现有 iPhone 17 Pro / iOS 26.5 模拟器上两个业务流程通过，截图已检查 |

校园跑、反馈、预约及校园写操作的自动化测试使用隔离的假 HTTP 响应，没有向真实服务提交记录、报名、签到、预约或反馈。截图中的账号、课程和活动为测试样例。iOS 主导航流程通过正式 Dart 选中回调切页，真实 UIKit 触摸仍需人工验收。

真实账号接口联调、安卓真机滑动性能、手机后台状态、相册授权面板及正式签名分发仍需设备验收。本次未自动安装到用户手机；原生鸿蒙、旧 WebView 数据导入与旧 Capacitor 更新机制未包含在此次补齐范围内。

## 复核入口

```bash
./tool/flutter.sh analyze
./tool/flutter.sh test
node tool/generate_autorun_reference.cjs
./tool/flutter.sh test test/autorun_parity_test.dart
./tool/flutter.sh drive --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/migration_flow_test.dart \
  -d <已有 iOS 模拟器标识>
```

只有原 Vue 规则变化时才重新生成对照数据，并审查期望值的变化。

截图：[个人中心](../screenshots/ios-profile-updated.png)、[头像选择](../screenshots/ios-avatar-picker.png)、[学业完成情况](../screenshots/ios-plan-completion.png)、[问题反馈](../screenshots/ios-feedback.png)、[校园跑登录](../screenshots/ios-autorun-login.png)、[校园跑进度](../screenshots/ios-autorun-progress.png)、[俱乐部](../screenshots/ios-autorun-club.png)。
