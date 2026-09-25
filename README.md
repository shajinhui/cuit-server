# 成信友友 Web

成信友友是面向成都信息工程大学学生的移动端优先校园助手，提供课表、成绩、考试、空教室、校园地图、图书馆和历年试卷等功能。

本公开仓库只包含 Web/PWA 与 Capacitor 客户端。服务端实现、部署配置以及校园跑相关算法已迁移到独立私有仓库，不在公开历史中保留。

- 在线访问：<https://fanxiaogao05.dpdns.org>
- Android 构建说明：[apps/web/ANDROID.md](apps/web/ANDROID.md)
- Web 开发说明：[apps/web/DEVELOPMENT.md](apps/web/DEVELOPMENT.md)

> 本项目是非官方学生项目，与成都信息工程大学及学校教务系统运营方无隶属或授权关系。

## 本地开发

环境要求：Node.js 24、pnpm 10.26.1。

```bash
git clone https://github.com/shajinhui/cuit-server.git
cd cuit-server/apps/web
pnpm install --frozen-lockfile
pnpm dev
```

开发服务器默认运行在 `http://127.0.0.1:5173`。需要连接接口时，在 `apps/web/.env` 中配置 `VITE_API_BASE_URL` 或 `VITE_DEV_API_TARGET`；接口服务不包含在本公开仓库中。

## 验证

```bash
cd apps/web
pnpm run check
```

`pnpm run check` 会依次执行 ESLint、Vitest、TypeScript 类型检查和生产构建。

## 目录

```text
.
├── apps/web/       # Vue 3、Vite、PWA 与 Capacitor 工程
├── shared/         # 前端复用的公开校历数据
├── scripts/        # Web/移动端构建辅助脚本
└── .github/        # Web、Android、iOS CI 配置
```

## 授权

本项目为专有软件，著作权归作者所有。仓库公开仅代表允许浏览，不授予复制、修改、分发、部署或商业使用许可；最终用户可以安装并使用作者官方发布的客户端（PWA、Android APK）用于个人非商业用途。

完整条款见 [LICENSE](LICENSE)。
