# Campus Assistant Web

`apps/web` 是校园助手的 PWA 前端目录。

当前已经完成可运行的移动端页面、成绩查询流程和 PWA 构建。

## 计划技术栈

- Vue 3
- TypeScript
- Vite
- Vue Router
- Pinia
- vite-plugin-pwa

## 当前页面

- 登录：按设计稿实现，接入教务登录并统一维护前端登录态。
- 课表：按设计稿实现，当前使用页面示例数据。
- 校园工具：按设计稿实现；只有“查成绩”接入后端，其他入口显示未接入提示。
- 我的：按设计稿实现，当前使用页面示例数据。
- 查成绩：调用 Hertz API 完成教务登录、学期读取和指定学期成绩查询。

## 目录职责

```text
apps/web/
├── public/
│   └── icons/       # PWA 图标
└── src/
    ├── api/         # 后端 API 请求
    ├── assets/      # 图片等静态资源
    ├── components/  # 通用组件
    ├── layouts/     # 页面布局
    ├── router/      # 前端路由
    ├── stores/      # 页面共享状态
    ├── styles/      # 全局样式
    └── views/       # 登录、课表、工具、成绩和个人中心页面
```

## 本地运行

先在仓库根目录启动 API：

```bash
go run ./apps/api
```

再启动前端：

```bash
cd apps/web
pnpm install
pnpm dev
```

如需修改开发代理目标，复制 `.env.example` 为本地 `.env` 并设置 `VITE_DEV_API_TARGET`。

## iPhone / iPad 安装

正式环境应通过 HTTPS 提供页面。在 Safari 中打开页面后，依次选择“分享”→“添加到主屏幕”，并保持“打开为 Web App”开启。

如果设备上已经安装过旧版主屏幕书签，需要先删除旧图标再重新添加，Safari 才会读取新的独立显示模式和 CUIT 应用图标。

## 安全边界

前端只访问本项目后端 API，不直接访问 CAS 或 EAMS，不保存教务密码、CAS Ticket 或学校系统 Cookie。“保持登录状态”只延长后端随机会话 Cookie 的有效期。

Service Worker 只预缓存前端静态资源，不缓存 `/api` 成绩和认证响应。
