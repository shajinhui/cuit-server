# 在线公告

Flutter Android / iOS / 鸿蒙与 Vue Web / Capacitor 共用校园服务的在线公告。公告不再写死在安装包中。实现位于 `flutter/lib/features/announcements/` 和 `apps/web/src/features/announcements/`；服务端位于独立私有仓库 `cuit-ratings-api/src/announcements/`。

## 发布方式

部署新的前后端后，在网页登录已有校园管理员账号，打开 `/admin/ratings` 的“公告管理”。权限沿用服务端 `RATINGS_ADMIN_SUBJECTS`，普通用户不能读取管理列表或发布。

1. 新建公告，填写标题、纯文本正文和目标平台；默认只发 Android。
2. 可添加 HTTPS 按钮、开始／结束时间，或关闭自动提醒，改为仅在工具页手动查看。
3. “保存草稿”不公开；“发布公告”二次确认后生效；“下架”从在线列表移除。
4. 修改后重新发布生成新内容版本，重新计算最多两次的提醒。再次保存原请求不会重复创建或增加版本；版本冲突需要重新选取最新记录，不能直接覆盖。

管理界面时间按操作设备本地时区输入，提交时转换为 UTC。链接禁止 HTTP、脚本、账号信息和控制字符；正文作为纯文本显示，不渲染服务器提供的 HTML。

## 客户端规则

- 启动后台获取，返回前台再次检查（自动请求至少间隔五分钟）；工具页可立即手动刷新。
- 同一 `ID + revision` 最多自动提醒两次，每次应用启动最多自动弹一条最新公告。手动查看也计入阅读次数，但始终可再次打开。
- 自动提醒只在主导航首页、前台、无键盘或其他弹窗时出现。Flutter 体验模式不自动弹出，但工具页可手动查看。
- 公告失败不影响教务登录或课表；首次失败显示重试，已有缓存则显示“离线缓存”。断网不自动弹出可能已被后台撤回的旧内容。
- 获取成功但列表为空会清除旧内容。缓存内未开始／过期的公告不展示。下架在下一次成功检查时生效，离线设备无法立即感知下架。
- 公开列表最多返回最近 20 条有效公告；工具页可查看该列表。阅读记录最多保留 100 个内容版本。
- 公告与学生账号无关，缓存按服务地址、平台和缓存版本隔离；不缓存登录凭证或学生信息。退出账号保留公开公告阅读记录。
- 这是应用内公告，不是 App 关闭后的系统通知推送，不需要通知权限或 FCM。

## 接口

默认地址 `https://lehi.top`。Flutter 可使用 `--dart-define=ANNOUNCEMENTS_API_BASE_URL=https://your-campus-api.example` 覆盖；Vue 使用已有 `VITE_RATINGS_API_BASE_URL`。

| 接口 | 认证 | 用途 |
| --- | --- | --- |
| `GET /api/v1/ratings/announcements?platform=android` | 无 | 已发布、目标平台匹配且在有效期内的公开列表 |
| `GET /api/v1/admin/ratings/announcements?cursor=...` | 校园 JWT + 管理员 | 草稿、公开、下架记录及分页 |
| `PUT /api/v1/admin/ratings/announcements/:id` | 校园 JWT + 管理员 | 新建、修改、发布、下架 |

响应沿用 `code / message / data`，公开和管理接口均设置 `Cache-Control: no-store`。读取公告的独立 HTTP 客户端不携带教务 Cookie 或校园 Token。

PUT 使用客户端生成的 ID。新建 `expected_version=0`，编辑使用最近读取的 `version`。字段为 `title/body/platform/status/auto_show/action/starts_at/expires_at/expected_version`；`status` 为 `draft/published/archived`；`platform` 为 `all/android/ios/ohos/web`；`action` 为 `null` 或 `{label,url}`。时间为含时区的 ISO 字符串或 `null`。公开 `revision` 与数据库版本一致。

## 上线顺序与验证范围

先部署校园后端（启动迁移 `005_announcements.sql`），再发布网页与新客户端，最后由管理员主动发布首条公告。迁移不预置广告或自动向用户发送任何消息。现有 NGINX 的 ratings/admin 路由已经覆盖，无需新增代理规则。

已完成本机测试和安卓 Debug 构建；线上状态以对应提交的部署 CI 与公开接口检查为准，本机构建不代表安装包已经公开发布。旧 Flutter 包需要更新一次；接入后发布新公告无需重打 APK。旧 Capacitor 包需获取包含在线公告改造的前端更新。

回归测试覆盖阅读次数、版本重置、离线／空列表、缓存损坏、并发请求、迟到响应、链接安全、工具入口、窄屏大字体与深色对话框；后端使用隔离本机 MySQL 和临时 JWT 验证权限、迁移、发布／下架、有效期及管理分页。测试不接学校系统，不在生产创建公告；真实手机网络与覆盖安装仍需发布后验收。
