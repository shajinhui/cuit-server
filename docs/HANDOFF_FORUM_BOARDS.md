# 交接：用户自建版块与版主（P0 已完成，待提交与部署）

更新：2026-11-09 · 交接对象：接手本任务的智能体

## 0. 一句话现状

用户自建版块 + 版主功能的 P0 已在服务端和 Flutter 两端实现并通过本地验证，**两个仓库都还没有提交**；未部署，未上生产。P1（公开申请、多版主、通知与申诉、深链）未做。

## 1. 仓库与工作区

| 仓库 | 路径 | HEAD | 本轮改动 |
| --- | --- | --- | --- |
| 客户端 + 文档 | `/Users/shajinhui/Documents/codeAbout/go/cuit-server` | `f97aa86` | 未提交，见 §2 |
| 服务端 | `/Users/shajinhui/Documents/codeAbout/go/cuit-ratings-api` | `c4e9ff0` | 未提交，见 §2 |

注意：客户端工作区里还有**不属于本任务**的改动，提交时必须排除：`flutter/lib/features/session/presentation/profile_page.dart`、`flutter/ios/Runner.xcodeproj/project.pbxproj`、`apps/web/nav-struct.*`、`.workbuddy/`、`flutter/ios/Runner/Debug.entitlements`、iOS SwiftPM 目录、两份 docx。不要 revert 它们，只挑本任务文件提交。

## 2. 已完成的改动

### 服务端

- 新增迁移 `migrations/011_forum_user_boards.sql`：版块可见性/状态/规则/版本、版主表、成员表、管理日志表、`created_by` 改 `SET NULL`、成员与版主随账号级联、`rating_reports` 增加 `forum_category`。
- `src/forum/forum.service.ts`：目录过滤、详情、创建配额与保留名、改名冷却、加入/退出、成员管理、置顶（≤3）/锁定/隐藏/恢复、管理日志、管理员公开/下线/归档/恢复/指定 owner/撤销版主、版块举报。
- `src/forum/forum.controller.ts`：对应路由，管理端在 `/api/v1/forum/admin/...`（现有 NGINX `/api/v1/forum/` 已覆盖）。
- `src/community/community.service.ts`：版块被下线后，收藏与消息也不再可见。
- 测试：`forum.service.spec.ts`（72 项）、`forum.mysql.spec.ts`（19 项真实 MySQL）；`src/database/database.service.ts` 注册 011。
- 文档：服务端 `README.md` 新增「用户自建版块与版主」章节。

### 客户端

- 模型：`ForumCategory` 增加 `visibility/status/rules/memberCount/version/capabilities/isMember/isModerator/moderators`，新增成员与日志模型。
- 仓库：详情、更新简介规则、加入/退出、成员、置顶/锁定、隐藏/恢复、日志、版块举报、我管理的版块。
- 新增 `forum_category_page.dart`（详情/加入/管理/版块号/成员/日志）、`forum_moderation_dialog.dart`（理由弹窗与动作文案）。
- `forum_channels_sheet.dart`：我管理的/官方/我加入的/校园版块分组，未公开标识，创建时填规则，输入版块号。
- `forum_thread_page.dart`：版主菜单（置顶/锁定/隐藏），隐藏后返回并刷新列表。
- `forum_editor_page.dart`：只列出 `canPost` 的版块。
- 路由与返回刷新：`app.dart`、`campus_page.dart`。
- 测试：`test/forum_board_management_test.dart`（3 项组件测试）、`forum_channels_repository_test.dart`（新增接口测试）、`test/fakes/campus_preview_repository.dart` 补齐实现。
- 文档：`docs/FORUM_USER_BOARDS.md`（v0.3，本文档之外的唯一设计依据）、`FORUM_CHANNELS.md`、`COMMUNITY_DEVELOPMENT_PLAN.md`。

## 3. 必须保持的契约与不变量

1. 管理权只看 `forum_category_moderators`，不要用 `created_by` 或 `is_mine` 推断。
2. 官方版块只有管理员能管理；版主不能封禁账号、不能跨版操作。
3. 新建用户版块默认 `unlisted`；只有管理员 `publish` 后才进公共目录。**未列出不是私密**：任何登录用户拿到 ID 都能读，但不出现在全站列表、搜索、热门和首页默认。
4. 用户版块发帖/回复需要有效成员身份；官方版块登录即可。
5. `is_enabled`（平台下线）、`visibility`（是否进目录）、`status`（active/archived）是三个独立维度，不要合并。
6. 下线版块要在帖子列表/详情、收藏、消息、图片访问等所有入口同时不可见；现有实现已覆盖论坛与社区两处。
7. `member_count` 读取时用有效成员实时统计（`live_member_count`）；列值只是写入时维护，不能作为正确性依据。
8. 管理操作必须写 `forum_moderation_logs`，不记录正文；日志无账号外键，账号注销后保留。
9. 同一版块只能有一个有效 owner（生成列 `owner_guard` + 唯一索引）。
10. 改名 7 天冷却；名称全站唯一并过滤官方名/固定频道名/管理称谓。

## 4. 验证方式与基线

服务端（没有 MySQL 端口时 25 项数据库测试会静默跳过）：

```bash
cd /Users/shajinhui/Documents/codeAbout/go/cuit-ratings-api
FORUM_TEST_MYSQL_PORT=33306 COMMUNITY_TEST_MYSQL_PORT=33306 \
  ANNOUNCEMENTS_TEST_MYSQL_PORT=33306 pnpm check
```

基线：218 项测试通过（31 项真实 MySQL），typecheck、build 通过。

客户端（Flutter 不在 PATH）：

```bash
cd /Users/shajinhui/Documents/codeAbout/go/cuit-server/flutter
/Users/shajinhui/.local/share/cuit-flutter-sdk/bin/flutter analyze
/Users/shajinhui/.local/share/cuit-flutter-sdk/bin/flutter test
```

基线：analyze 无问题，393 项测试通过。

临时 MySQL（本机已装 MySQL 9.3，用完清理）：

```bash
BASE=/usr/local/mysql-9.3.0-macos15-arm64
DIR=$(mktemp -d /tmp/cuit-mysql.XXXXXX)
$BASE/bin/mysqld --initialize-insecure --datadir="$DIR" --basedir="$BASE"
$BASE/bin/mysqld --datadir="$DIR" --basedir="$BASE" --port=33306 \
  --bind-address=127.0.0.1 --socket="$DIR/mysql.sock" --mysqlx=0 &
# 结束：$BASE/bin/mysqladmin -h127.0.0.1 -P33306 -uroot shutdown && rm -rf "$DIR"
```

迁移额外演练过：先应用 001–010，插入一个旧个人版块，再应用 011，确认 visibility/owner/成员回填正确；删除账号后 `created_by` 变 NULL、版主/成员级联清除、版块保留。这个演练没有固化成自动化测试，建议补成 MySQL 用例。

## 5. 待办（按优先级）

### A. 整理并提交（先做）

- 分别审阅两个仓库的 diff，把本任务文件与无关改动分开。
- 客户端提交前先 `git checkout -- flutter/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`：每次跑 Flutter 命令都会删掉这个跟踪文件。
- 服务端提交包含 011 迁移；客户端提交包含 `docs/FORUM_USER_BOARDS.md`。
- 验收：两个仓库各自可独立构建、测试；没有把 profile_page、pbxproj、nav-struct、docx 混进提交。

### B. 生产迁移演练与发布

- 备份生产库；在与生产一致的 MySQL 8 上演练 011，记录 DDL 耗时、锁表影响与恢复方式。重点验证：`DROP FOREIGN KEY` + 重建、生成列 + 唯一索引、`DROP CHECK` 重建。
- 发布顺序：服务端 + 迁移 → 客户端。应用启动时自动执行未应用迁移，部署包必须带 `migrations/`。
- 回退只回退应用版本，不回滚数据库；`is_enabled=false` 是可用的功能级开关。
- 验收：健康检查提交号正确；真机完成建版/加入/发帖/置顶/隐藏；管理员下线后帖子、收藏、消息都不可见；旧客户端仍能正常使用官方版块。
- 注意：011 会把**已存在的** enabled 版块设为 `public`（保留旧行为），新板块才是 unlisted。不要直接改成全量 unlisted，先核对线上是否已有用户版块。

### C. P1 公开申请与审核

- 新增 `forum_category_publish_requests`（DDL 见 `docs/FORUM_USER_BOARDS.md` §6），实现申请、审核队列、通过/驳回。
- 通过条件：单一 pending、owner 发起、≥5 条非本人帖子、管理员填写审核意见。
- 客户端：版块页「申请公开」、状态展示；管理端入口放在现有 `/admin/ratings` 还是新页面需先确认。
- 验收：重复申请被拒；通过后进入目录并写 `published_at`；驳回理由可见；下线/归档状态联动。

### D. P1 多版主与转让

- 目前只有管理员 `PUT /admin/categories/:id/owner` 和撤销，**没有 owner 自己任命版主的接口**。
- 需要：owner 任命/撤销 moderator（≤3 人、必须是成员）、owner 转让、全部写日志；客户端管理页补齐。
- 验收：撤销 owner 必须先指定继任者；moderator 不能管理官方版块；越权返回 403。

### E. 通知与申诉

- 移除成员、被隐藏帖子目前只有日志，没有站内通知。现有 `community_notifications` 的 `kind` 检查与 `thread_id/reply_id NOT NULL` 外键不适合直接复用，需要先改表。
- 设计时注意：不通知自己、目标删除/隐藏后不泄露摘要、下线版块的消息不可见。
- 验收：双账号完成移除/隐藏 → 收件箱提示 → 跳转正确；重复操作不重复通知。

### F. 深链与分享

- 路由已经存在：`/campus/forum/categories/:categoryId`（`app.dart`）。
- 当前分享是「复制版块号 → 更多版块 → 输入版块号」。深链需要 Android/iOS 关联域、Web 落地页和分享卡片；客户端的版块号输入校验是 `^[A-Za-z0-9_-]{8,80}$`，官方短 ID 有意不支持。

## 6. 已知坑

1. **Flutter 命令会删 `Package.resolved`**（见 §5A）。
2. 服务端 MySQL 测试只在显式传端口时运行，漏传会显示"全绿"但实际跳过。
3. 客户端当前每打开一篇帖子会额外请求一次版块详情来判断 `canManage`；量上来后再考虑服务端在帖子 DTO 里返回能力位或做缓存。
4. 版块举报写入 `rating_reports.target_type='forum_category'`，但评分后台的内容审核接口不认识这个类型；处理举报要配合论坛管理端，或扩展管理接口。
5. `forum_home_preferences` 对账号还有外键，账号注销流程仍会被它阻塞——这是既有问题，本轮只解除了版块 `created_by` 这一处。
6. `adminRevokeModerator` 只有单元测试，真实 SQL 未覆盖；建议补 MySQL 用例。
7. 管理日志分页游标按 `created_at + id`，目前只测了少量数据；超过 20 条的分页没有覆盖。
8. 客户端 `forum_editor_page.dart` 只列 `canPost` 版块，若用户退出某个版块，历史帖子仍可见但不能编辑到该版块，这是预期行为。
9. `member_count` 有冗余列，但读取用实时子查询；不要为了"性能"改回只读列。
10. 客户端工作区存在并行改动；动手前先 `git status`，不要擅自 checkout 别人的文件。

## 7. 参考资料

- 设计、权限矩阵、接口与实现状态：[`docs/FORUM_USER_BOARDS.md`](docs/FORUM_USER_BOARDS.md)
- 版块目录与频道边界：[`docs/FORUM_CHANNELS.md`](docs/FORUM_CHANNELS.md)
- 社区整体计划：[`docs/COMMUNITY_DEVELOPMENT_PLAN.md`](docs/COMMUNITY_DEVELOPMENT_PLAN.md)
- 服务端接口与迁移说明：`cuit-ratings-api/README.md` 的「用户自建版块与版主」章节
