# 成信友友 Web 前端开发规范

本文档是 `apps/web` 的长期开发约束。新增功能、修复缺陷和重构代码时均应遵守；当前代码与本文冲突时，应在同一次修改中同步代码或文档，不能让规范长期失真。

## 1. 基本原则

1. 保持轻量，不为了“以后可能需要”提前引入框架、抽象层或空目录。
2. 按业务功能组织代码，让一个功能的 API、状态、模型、组件和测试尽量放在一起。
3. 页面负责组装，业务规则放进 `features/`，跨业务基础能力放进 `shared/`。
4. Pinia 只保存确实需要跨组件共享的业务状态；页面临时状态优先使用 `ref`、`computed`。
5. 网络、IndexedDB、用户输入等外部边界必须处理错误；纯内部数据不重复堆砌防御性判断。
6. 优先复用 Vue、TypeScript 和现有依赖，不为简单问题增加新包。
7. 修改范围保持聚焦，不顺手重写无关页面、样式或公共接口。

## 2. 目录职责

```text
src/
├── app/          # 根组件、路由、应用导航、跨功能生命周期编排
├── assets/       # 图片、图标等静态资源
├── features/     # 按业务域组织的功能模块
├── pages/        # 与路由一一对应的页面组件
├── shared/       # 无业务归属的公共基础能力
├── styles/       # 全局基础样式和现有页面样式入口
└── main.ts       # Vite 应用启动入口
```

### `app/`

- 只负责应用启动后的整体组装。
- 路由配置放在 `app/router.ts`。
- 应用级导航放在 `app/components/`。
- 同时操作多个 feature 的流程放在应用用例中，例如 `sessionLifecycle.ts`。
- 不在这里实现成绩计算、课表转换等单一业务规则。

### `features/`

每个业务功能拥有自己的目录，例如：

```text
features/schedule/
├── api.ts
├── cache.ts
├── store.ts
├── index.ts
├── components/
├── composables/
└── model/
    ├── calendar.ts
    └── calendar.test.ts
```

只创建功能当前真正需要的文件。没有缓存、store 或组件时，不建立对应空目录。

职责约定：

- `api.ts`：请求参数、响应类型和本功能的后端接口。
- `store.ts`：跨组件共享的业务状态和异步流程。
- `model/`：不依赖 DOM 的业务计算、转换和规则。
- `composables/`：组合 Vue 响应式状态和生命周期。
- `components/`：只服务于本功能的业务组件。
- `index.ts`：功能对外公开入口。
- `*.test.ts`：与被测试代码就近放置。

### `pages/`

- 文件统一命名为 `XxxPage.vue`。
- 页面负责读取路由、调用功能入口、组合组件和展示加载/错误/空状态。
- 页面内不直接调用 `fetch`、IndexedDB，也不堆积可独立测试的业务计算。
- 页面独有且简单的交互状态可以保留在页面中。
- 页面需要跨功能流程时，只调用 `app/` 明确暴露的应用用例，不直接拼装多个 feature 的内部实现。

### `shared/`

- `shared/api/`：通用请求客户端以及确实被多个功能共用的接口。
- `shared/models/`：被多个功能共同使用的领域类型。
- `shared/composables/`：不包含具体业务含义的组合逻辑。
- `shared/ui/`：不依赖具体业务和路由的基础 UI。

禁止把暂时不知道放哪里的代码丢进 `shared/`。只有至少两个明确调用方、且没有单一业务归属时，才考虑提升到这里。

## 3. 依赖方向

跨目录依赖遵守以下方向：

```text
main
  ↓
app / pages
  ↓
features
  ↓
shared
```

具体规则：

1. `shared/` 不得导入 `features/`、`pages/` 或 `app/`。
2. `features/` 不得导入 `pages/` 或应用根组件、路由。
3. feature 之间确有业务依赖时，只能通过对方的 `index.ts`，并避免循环依赖。
4. 页面和应用层从 feature 的 `index.ts` 导入，不直接访问其 `store.ts`、`api.ts` 等内部文件。
5. 同一 feature 内部使用相对路径引用自己的实现。

正确示例：

```ts
// 页面或应用层
import { useScheduleStore } from '@/features/schedule'

// schedule 功能内部
import type { Course } from '../api'
```

禁止示例：

```ts
import { useScheduleStore } from '@/features/schedule/store'
import { getCourseTable } from '@/features/schedule/api'
```

`index.ts` 只导出外部确实需要的能力，不把整个功能内部全部暴露出去。

## 4. Vue 组件与 composable

1. 使用 `<script setup lang="ts">` 和 Composition API。
2. 路由页面命名为 `XxxPage.vue`，普通组件使用 PascalCase。
3. composable 统一命名为 `useXxx.ts`，在组件 `setup` 阶段调用。
4. props、emits 和公开返回值应有明确类型。
5. 可由已有状态推导的数据使用 `computed`，不要再维护一份容易失同步的 state。
6. `watch` 只处理副作用，不用来替代普通计算。
7. 定时器、订阅和事件监听必须在组件卸载时清理。
8. 单个页面开始混合多种业务职责时，优先抽取 model、composable 或业务组件，不机械拆成大量小文件。
9. DOM、主题色等重复页面副作用应复用已有 composable，例如 `usePageTheme`。

## 5. TypeScript

1. 保持 `strict` 模式，不使用 `any` 绕过类型检查。
2. API 响应类型放在所属 feature 的 `api.ts`；跨功能公共类型放在 `shared/models/`。
3. 外部边界和公开函数优先写清类型，函数内部能可靠推导时不重复标注。
4. 使用 `unknown` 接收未知错误或外部数据，再进行必要缩小。
5. 不使用非空断言掩盖真实的空值分支。
6. 类型导入使用 `import type`。
7. 不复制相同接口类型；先确认它属于单一功能还是公共领域模型。

## 6. 状态管理

状态按范围选择位置：

| 状态范围 | 推荐位置 |
|---|---|
| 单个组件临时交互 | 组件内 `ref` |
| 页面内可推导数据 | 页面或 composable 的 `computed` |
| 同一功能多个组件共享 | feature `store.ts` |
| 多功能登录生命周期 | `app/` 应用用例 + session store |

Pinia store 应：

- 暴露业务动作，不让页面重复拼装请求流程。
- 明确维护 `loading`、可展示错误和必要状态。
- 对 401、断网和普通业务失败做不同处理。
- 避免保存可由其他 state 计算出的重复数据。
- 不直接操作无关功能的数据；跨功能清理由应用层编排。

## 7. API 与错误处理

1. 页面和组件不得直接使用 `fetch`。
2. 通用 HTTP 行为统一经过 `shared/api/client.ts`。
3. 功能接口放在自己的 `api.ts`，函数名表达业务动作。
4. 查询参数使用 `URLSearchParams`，请求体使用明确的对象结构。
5. 不把网络失败误判为登录失效；只有明确的 401 才切换匿名状态。
6. 不用笼统提示隐藏后端已有的安全错误信息。
7. UI 必须覆盖加载、错误、空数据和成功状态，离线功能还需覆盖缓存状态。
8. 不在日志、错误消息或测试快照中输出密码、Cookie、Session、Token、CAS ticket 或完整敏感 URL。

## 8. 样式、移动端与可访问性

具体的颜色、排版、间距、组件、动效和视觉验收规则见 [UI 设计规范](./UI_DESIGN_GUIDELINES.md)。

1. 默认移动端优先，并验证窄屏、高屏、刘海屏安全区。
2. 使用现有页面前缀命名 class，避免无范围的通用名称污染其他页面。
3. 公共颜色、间距或尺寸重复出现后再提取变量，不提前建立庞大 Design Token 系统。
4. 交互元素使用语义化 `button`、`a`、`label`，不能用普通 `div` 模拟按钮。
5. 图标按钮必须提供 `aria-label`；状态变化使用适当的 `role` 或 `aria-live`。
6. 触摸目标尽量保持至少 44×44 CSS 像素。
7. 动画不得影响任务完成，并适配 `prefers-reduced-motion`。
8. 页面主题色和根背景使用 `usePageTheme`，不要重复手写 DOM 恢复逻辑。
9. 当前全局样式仍从 `styles/main.css` 进入；重构样式时按功能逐步迁移，不一次性重写全部 CSS。

## 9. PWA、缓存与安全

1. Service Worker 只预缓存前端静态资源，不缓存 `/api` 登录、鉴权或业务响应。
2. 浏览器不得直接访问 CAS/EAMS，不保存教务密码、CAS ticket 或学校系统 Cookie。
3. 当前只允许保存最近一次成功课表、必要学期与教学周信息、用户明确添加的本机手动课程，以及按学期和校区保存的教室占用快照。
4. 登录新账号、主动退出、确认匿名或收到 401 时必须清除旧用户的课表和教室占用快照。
5. 修改 IndexedDB 数据结构时必须同步版本、校验和迁移/失效策略。
6. PWA 相关修改必须运行生产构建，并确认 Service Worker 和 manifest 正常生成。
7. 不把敏感数据放进 LocalStorage、URL、前端日志或静态构建产物。
8. 已有本机课表时，页面进入只读取缓存；仅首次无缓存、用户主动更新或明确切换到其他学期时查询远端课表。
9. 空教室查询缓存整学期、单校区的教室和占用时间；周次、星期、节次、教学楼、类型与容量筛选必须在本地完成。仅缓存不存在、用户主动更新或切换到未缓存的学期/校区时请求远端。

## 10. 测试规范

1. 业务计算优先写成 model 纯函数，并使用 Vitest 测试。
2. Pinia store 测试覆盖关键状态流转、错误和边界分支。
3. 修复 bug 时添加能够在修改前失败、修改后通过的回归测试。
4. 测试默认不得访问真实学校系统或公网服务。
5. 测试账号、密码、Cookie 和响应样本必须是明显的虚构数据。
6. 测试名称说明业务行为，不只描述函数名。
7. 测试与源码就近放置，命名为 `*.test.ts`。

当前没有引入重量级组件测试框架。只有出现稳定的组件交互测试需求时再增加，不能为了测试简单纯函数而挂载整个页面。

## 11. ESLint、依赖与 CI

提交前必须在 `apps/web` 执行：

```bash
pnpm run check
```

它依次运行：

```text
ESLint → Vitest → vue-tsc → Vite build
```

规则：

1. 不使用 `eslint-disable` 掩盖可正常修复的问题；确需禁用时写清原因并限制到最小范围。
2. `pnpm lint:fix` 只用于当前修改范围，执行后必须检查 diff。
3. 新增依赖前确认 Vue、TypeScript 或现有包无法完成需求。
4. 使用 `pnpm add` / `pnpm add -D` 管理依赖，并提交对应 `pnpm-lock.yaml`。
5. 不手工修改锁文件，不使用非 pnpm 包管理器生成第二份锁文件。
6. GitHub Actions 的 Web CI 必须通过；本地通过不能替代远端 CI 结果。

## 12. 新增功能流程

新增考试等功能时，按以下最小步骤执行：

1. 在 `features/exams/` 创建当前需要的 `api.ts`、model 或 store。
2. 用 `index.ts` 暴露页面需要的最小能力。
3. 在 `pages/ExamsPage.vue` 组装页面。
4. 在 `app/router.ts` 添加懒加载路由。
5. 为纯业务规则和关键状态补测试。
6. 必要时更新 README、API 文档和本规范。
7. 运行 `pnpm run check`。

不要先创建完整的 `api/components/composables/model/store` 空架构，也不要为了一个页面状态建立全局 store。

## 13. 提交前检查清单

- [ ] 代码放在正确的 app、page、feature 或 shared 边界。
- [ ] 外部调用只使用 feature 的 `index.ts`。
- [ ] 页面没有直接请求 API 或操作 IndexedDB。
- [ ] 新业务规则已从页面抽出并有测试。
- [ ] 加载、错误、空数据和离线状态已考虑。
- [ ] 没有敏感信息进入代码、日志、缓存或测试。
- [ ] PWA/缓存修改已验证生产构建。
- [ ] README、API 文档和代码行为保持一致。
- [ ] `pnpm run check` 全部通过。

## 14. Android 原生包

Capacitor Android 工程、GitHub APK 构建、签名密钥和真机验收流程见 [ANDROID.md](./ANDROID.md)。

涉及 Capacitor 配置、原生运行时或 Android 工程的修改，除 `pnpm run check` 外还必须执行：

```bash
VITE_API_BASE_URL=https://api.fanxiaogao05.dpdns.org pnpm run android:sync
```

无法在本机运行 Gradle 时，由 `.github/workflows/android.yml` 完成实际 APK 编译；本地构建成功不能替代 GitHub Actions 和真机验证。
