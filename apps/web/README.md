# 成信友友 Web

`apps/web` 是成信友友的 Vue 3、Vite、PWA 与 Capacitor 客户端工程。

## 页面与能力

- 登录、课表、成绩、考试、空教室、校历、校园地图和历年试卷
- 校园跑进度、轨迹提交、俱乐部活动与签到
- 校园页的评分 / 二手栏目切换；评分板块、图片本地缓存和全屏预览
- 二手出售与求购切换、发布、定价或预算、搜索、联系发布者，以及下架 / 关闭 / 完成管理
- PWA 安装、Android APK 与 iOS 构建

服务端 API 不在公开仓库中；本地开发时通过 `VITE_API_BASE_URL` 或 `VITE_DEV_API_TARGET` 指向已部署的接口。

生产构建未配置 `VITE_API_BASE_URL` 时，教务请求默认使用 `https://api.fanxiaogao05.dpdns.org`，避免登录请求落到静态官网。显式配置仍优先；开发环境未配置时继续通过 Vite 同源代理访问接口。

## 校园二手接口

评分和二手均通过 `VITE_RATINGS_API_BASE_URL` 连接独立的校园后端 `cuit-ratings-api`，沿用 `/api/v1/auth/ratings-token` 签发的登录凭证。二手请求路径为 `/api/v1/marketplace/*`，图片复用 `/api/v1/ratings/assets`。

上线前先部署后端的 `002_marketplace`、`003_marketplace_wanted` 数据库迁移与 NGINX marketplace 路由，并确保上述域名指向包含二手模块的 NestJS 服务。出售点击“我想购买”、求购点击“我有闲置”只获取发布者联系方式，不创建订单、不预订商品、不处理支付。

`/marketplace?type=wanted` 可直接进入求购，发布页可切换出售或求购。请求字段 `listing_type` 为 `sell` / `wanted`，`price_cents` 分别表示售价或预算；求购状态显示为“求购中 / 已关闭 / 已求到”。我的发布也按类型筛选。

## 官网与下载更新

官网按实际能力介绍教务工具、校园评分／二手、新版原生客户端论坛、桌面小组件与应用内公告，并在功能和下载区标注平台／版本边界。网页入口继续使用 Vue；当前公开 APK 仍是原版客户端，新 Flutter 基础包的构建或补丁发布不会自动替换官网下载目标。iOS 以 `shared/config/downloads.ts` 的 `IOS_TESTFLIGHT_URL` 为主要安装入口，PWA 为备用方式；TestFlight 测试不等于 App Store 正式上架。原生鸿蒙尚在验证；本机头像和课程自定义不宣传为跨设备资料同步。

`/official` 每次打开或刷新走网络，不使用 PWA 缓存的应用入口，也不注册新的 Service Worker；已有应用 Worker 仍会检查更新。课表等应用页面保持原有离线能力，不清理用户本地数据。

官网、安卓下载提示统一使用固定入口 `https://fanxiaogao05.dpdns.org/downloads/android`；公告中的下载按钮也应使用该入口。Pages Function 返回不缓存的 `302`，将用户引导到当前 Gitee APK。今后换包只需更新 `src/shared/config/downloads.ts` 的 `LATEST_ANDROID_APK_URL` 并发布，已经打开的旧页面按钮也会获取新的跳转目标。该入口不代理或缓存安装包正文。

公告改为在线读取；`/admin/ratings` 提供管理员公告发布、编辑、定时生效和下架入口。与 Flutter 共用服务，阅读次数、缓存边界、上线顺序见 [在线公告](../../docs/ANNOUNCEMENTS.md)。

## 本地运行

```bash
cd apps/web
pnpm install --frozen-lockfile
pnpm dev
```

提交前执行：

```bash
pnpm run check
```

`check` 会运行 ESLint、单元测试、TypeScript 类型检查和生产构建。

## 目录职责

```text
src/app/       # 根组件、导航、路由和生命周期
src/assets/    # 图片与其他静态资源
src/features/  # 按业务域组织 API、状态、缓存和模型
src/pages/     # 路由页面
src/shared/    # 通用请求、模型、composable 和基础 UI
src/styles/    # 全局样式
```

## 安全边界

前端不保存教务密码、Cookie 或认证票据；真实凭据不得写入代码或静态构建产物。接口地址可通过本地环境变量或部署平台配置覆盖。Service Worker 只缓存前端静态资源，不缓存接口响应。
