# 系统推送

移动端使用 Firebase Cloud Messaging（FCM）。Android 直接由 FCM 投递，iOS 由 Firebase 转发到 APNs；Web/PWA 和鸿蒙继续使用应用内消息。

## Firebase 项目

1. 在 Firebase 项目中注册 Android 包名 `org.dpdns.fanxiaogao05.chengxin.flutter`，下载 `google-services.json` 到 `flutter/android/app/`。
2. 注册 iOS Bundle ID `org.dpdns.fanxiaogao05.chengxin.flutter`，下载 `GoogleService-Info.plist`，加入 Xcode 的 Runner target。Firebase 控制台上传 Apple Push Notification authentication key。
3. 在 Xcode 的 Signing & Capabilities 中确认 Push Notifications 已开启；Release 使用 production APNs entitlement，Debug 使用 development entitlement。

配置文件和服务账号私钥不提交 Git。没有这些配置时，应用仍可构建并继续使用应用内消息，但不会取得 FCM 令牌。

也可以不放置平台配置文件，在构建时传入以下公开客户端参数：

```text
--dart-define=FIREBASE_API_KEY=...
--dart-define=FIREBASE_APP_ID=...
--dart-define=FIREBASE_MESSAGING_SENDER_ID=...
--dart-define=FIREBASE_PROJECT_ID=...
--dart-define=FIREBASE_IOS_BUNDLE_ID=org.dpdns.fanxiaogao05.chengxin.flutter
```

## 服务端

在 `cuit-ratings-api` 服务的环境变量中配置：

```text
FCM_PROJECT_ID=your-firebase-project-id
FCM_CLIENT_EMAIL=firebase-adminsdk-...@your-firebase-project.iam.gserviceaccount.com
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

服务端启动时会应用 `010_push_devices.sql` 与 `013_announcement_push.sql`。论坛回复和应用公告都与业务数据在同一事务写入推送 outbox，后台服务每 5 秒发送一次，失败指数退避，Firebase 返回失效令牌时自动停用。必须先发布后端迁移和服务，再发布带 Firebase 配置的移动端。

## 客户端行为

- 首次启动会请求通知权限并注册当前 FCM 令牌；账号切换后令牌绑定到新账号。
- 应用在前台收到回复时使用本地通知展示；后台或被系统终止时由 FCM/APNs 展示。
- 应用在前台收到公告时使用“应用公告”通知渠道展示；点击公告通知会打开工具页并刷新公告。
- 点击回复通知会打开对应论坛帖子并定位到回复。
- 评分评论回复不产生推送，仍保留后续扩展空间。
