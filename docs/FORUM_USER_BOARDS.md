# 用户自建版块与版主

版本：v0.3 · 服务端与 Flutter P0 均已实现并验证，**尚未部署**。

交接与剩余任务见[交接文档](./HANDOFF_FORUM_BOARDS.md)。本文接续[论坛版块与首页展示](./FORUM_CHANNELS.md)和[校园社区发展计划](./COMMUNITY_DEVELOPMENT_PLAN.md)。版块、主题、频道的边界沿用前者，本文只回答一件事：用户能不能自己开一个版块，并成为它的管理者。

## 1. 结论

方向可行，已有的客户端和接口契约让成本很低。但「创建即公开、即版主、即拥有删帖权」这个组合不建议一次到位，原因不是技术，而是治理成本会先于产品价值到来：

- 版块数量一旦放开，公共目录会被低质量版块占据，发现性反而下降。
- 版主的删除/锁帖权直接触及他人表达，滥权、报复和申诉必须同时存在。
- 平台对用户发布内容的责任不会因为设立版主而转移。

因此本文给出的是**两段式**方案：

1. **P0 用户版块**：默认「未列出」，不进公共目录；创建者获得本版基础管理权（置顶、锁定、隐藏帖子、移除成员），全量留痕，平台可随时下线。
2. **P1 公开化**：版块申请并通过人工审核后进入公共目录，创建者成为公开版块的版主；再补多版主、转让与申诉。

## 2. 现状

| 已有 | 位置 | 说明 |
| --- | --- | --- |
| 创建版块入口 | `flutter/lib/features/campus/presentation/forum_channels_sheet.dart` | 已有表单、提交、创建后加入首页 |
| 创建接口契约 | `docs/FORUM_CHANNELS.md` | `POST /api/v1/forum/categories`，返回 `is_official:false, is_mine:true` |
| 版块字段 | `007_forum_channels.sql`（规划） | `is_official`、`created_by`、名称唯一、排序 |
| 帖子管理标记 | `ForumThread.isPinned / isLocked / canDelete` | 展示层已能渲染「置顶」「已锁定」 |
| 举报与隐藏 | 现有管理机制 | 复用举报受理与内容下线 |

缺口有三个：服务端未实现版块创建；`created_by` 只是创建者，不是可撤销、可转让的角色；客户端没有任何版块管理界面。

## 3. 产品形态

### 3.1 版块类型

| 类型 | 来源 | 可见性 | 谁能发帖 | 谁能管理 |
| --- | --- | --- | --- | --- |
| 官方版块 | 平台种子数据 | 公开 | 已登录用户 | 平台管理员 |
| 公开用户版块 | 用户创建且通过审核 | 公开，进公共目录 | 已加入的成员 | 版主 + 平台管理员 |
| 未列出用户版块 | 用户创建，默认状态 | 不进目录，有入口才能进 | 已加入的成员 | 版主 + 平台管理员 |

「未列出」不等于私密：内容对持有入口的已登录用户可读，但不进入公共目录、首页默认、热门和搜索。这样既能让班级、社团、兴趣小组立刻用起来，又不会在第一天就把目录撑爆。

### 3.2 生命周期

```text
创建 ──▶ unlisted(active) ──申请公开（P1）──▶ 审核 ──通过──▶ public(active)
                │                                          │
                ├── 90 天无新帖 + 提醒 30 天 ──▶ archived   │
                └── 平台下线 ──▶ is_enabled = FALSE  ◀──────┘
```

- **active**：正常收发内容。
- **archived**：只读，保留历史；可由管理员恢复。
- **is_enabled = FALSE**：平台硬下线，版块与内容对所有人不可见；与 `status` 分开，避免把「平台处罚」和「版块自然衰老」混成一个字段。

### 3.3 配额与命名

- 每人最多创建 **3** 个版块（含归档，不含被平台下线）。
- 全站公开用户版块上限 **50**，达到上限后暂停审核通过，未列出版块不受影响。
- 名称 2–12 字，全站唯一；保留词包括官方版块名、「全部」「热门」「精华」、管理类称谓和敏感词。
- 创建后 **7 天**内不可改名；同一用户 **30 天**内不可重建同名版块。
- 归档满 **90 天**且名称无争议时，可由管理员释放名称。

## 4. 角色与权限

### 4.1 角色

| 角色 | 产生方式 | 范围 |
| --- | --- | --- |
| 成员 | 主动加入用户版块 | 可读、可发帖、可回复 |
| 版主（owner） | 创建者；同一版块唯一 | 本版内容与成员管理 |
| 版主（moderator） | owner 任命（P1），上限 3 | 同 owner，但不能转让、不能撤销 owner |
| 平台管理员 | 现有后台 | 全站 |

`created_by` 只表示「谁创建」，权限一律以 `forum_category_moderators` 为准。不要用 `is_mine` 判断管理权：它描述归属，不描述授权，账号注销、版块转让之后就会失真。

### 4.2 权限矩阵

官方版块：任何已登录用户可读可发。用户版块：已登录用户可读（未列出版块需有入口），加入后成为成员才能发帖。

| 操作 | 作者本人 | 版主 | 平台管理员 |
| --- | --- | --- | --- |
| 编辑/删除自己的帖子 | 是 | 是（仅自己的） | 是 |
| 置顶本版帖子（最多 3 条） | 否 | 是 | 是 |
| 锁定/解锁本版帖子 | 否 | 是 | 是 |
| 隐藏本版他人帖子（需理由） | 否 | 是 | 是 |
| 恢复被隐藏帖子 | 否 | 7 天内可撤销自己的操作 | 随时 |
| 移动帖子到其他版块 | 否 | 否（P1 再议） | 是 |
| 改版块简介与规则 | 否 | 是 | 是 |
| 改版块名称 | 否 | 是，7 天冷却 + 词库校验 | 是 |
| 移除成员（7 天内不可重新加入） | 否 | 是 | 是 |
| 任命/撤销版主 | 否 | 否（P1 由 owner 任命） | 是 |
| 封禁账号 | 否 | **否** | 是 |
| 下线版块 | 否 | 否 | 是 |
| 查看操作日志 | 否 | 本版 | 全站 |
| 处理举报 | 否，不得处理针对自己的 | 本版，涉及自己须回避 | 全站 |
| 查看匿名内容作者 | — | **否** | 是 |

三条硬规则：

1. **版主没有账号级处罚权**。封禁、永久禁言、清空历史内容只能由管理员执行。
2. **回避**。涉及版主本人或其帖子的举报，服务端返回 `moderation_self_conflict`，只能由管理员处理。任何人都不得处理针对自己的举报。
3. **可撤销**。所有版主操作都写日志；被隐藏帖子、被移除成员有申诉入口。

## 5. 治理与合规

- 版块规则必须包含：禁止违法与侵权内容、禁止人肉与泄露个人信息、禁止诈骗与收费引流、禁止广告与拉群。
- 版块页展示版主公开昵称，并注明「版主为社区志愿者，不代表平台」。
- 用户版块**不支持匿名发帖**；树洞等匿名场景只保留在官方版块。
- 举报同时进入版主与管理员队列；版主 24 小时未处理自动升级。
- 同一版块 30 天内有效举报累计 5 次，自动转人工复核，复核期间可临时限制发帖。
- 隐藏内容软删除保留 30 天，可恢复；操作日志保留 180 天，不记录正文和个人敏感信息。
- 版主 90 天无管理操作且版块 90 天无新帖：先提醒，30 天后自动归档；归档后成员只读。
- 版主注销或长期失联：优先转让给其他版主，30 天无人接管则归档，不删除历史内容。
- 平台保留随时下线版块、撤换版主、清理违规内容的权利，不因「版主自治」而免责。

## 6. 数据模型

迁移文件为 `011_forum_user_boards.sql`，在 010 推送设备之后执行。以下 SQL 与 `cuit-ratings-api` 中已执行的迁移一致。

```sql
-- 版块可见性与生命周期
ALTER TABLE forum_categories
  ADD COLUMN visibility ENUM('unlisted','public') NOT NULL DEFAULT 'unlisted',
  ADD COLUMN status ENUM('active','archived') NOT NULL DEFAULT 'active',
  ADD COLUMN rules VARCHAR(1000) NULL,
  ADD COLUMN published_at VARCHAR(30) NULL,
  ADD COLUMN archived_at VARCHAR(30) NULL,
  ADD COLUMN renamed_at VARCHAR(30) NULL,
  ADD COLUMN member_count INT NOT NULL DEFAULT 0,
  ADD COLUMN version INT NOT NULL DEFAULT 1,
  ADD COLUMN updated_at VARCHAR(30) NULL,
  ADD KEY idx_forum_category_directory (is_enabled, visibility, status, is_official, sort_order);

-- 官方种子保持公开；迁移前已存在的个人版块由运营确认后逐条放开
UPDATE forum_categories SET visibility = 'public' WHERE is_official = TRUE;

-- 创建者注销不应阻塞账号流程，也不应连带删除版块
ALTER TABLE forum_categories DROP FOREIGN KEY fk_forum_category_creator;
ALTER TABLE forum_categories
  ADD CONSTRAINT fk_forum_category_creator
  FOREIGN KEY (created_by) REFERENCES rating_profiles(id) ON DELETE SET NULL;

-- 版主关系表：一人一版一条，可撤销；owner 全局唯一
CREATE TABLE forum_category_moderators (
  category_id VARCHAR(80) NOT NULL,
  user_id VARCHAR(80) NOT NULL,
  role ENUM('owner','moderator') NOT NULL DEFAULT 'moderator',
  granted_by VARCHAR(80) NULL,
  granted_at VARCHAR(30) NOT NULL,
  revoked_at VARCHAR(30) NULL,
  owner_guard VARCHAR(80) GENERATED ALWAYS AS (
    CASE WHEN role = 'owner' AND revoked_at IS NULL
         THEN CAST(category_id AS CHAR(80)) END
  ) STORED,
  PRIMARY KEY (category_id, user_id),
  UNIQUE KEY uq_forum_category_owner (owner_guard),
  KEY idx_forum_moderator_user (user_id, revoked_at),
  CONSTRAINT fk_forum_moderator_category FOREIGN KEY (category_id)
    REFERENCES forum_categories(id) ON DELETE CASCADE,
  CONSTRAINT fk_forum_moderator_user FOREIGN KEY (user_id)
    REFERENCES rating_profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_forum_moderator_grantor FOREIGN KEY (granted_by)
    REFERENCES rating_profiles(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 成员关系：用户版块发帖的前置条件
CREATE TABLE forum_category_members (
  category_id VARCHAR(80) NOT NULL,
  user_id VARCHAR(80) NOT NULL,
  joined_at VARCHAR(30) NOT NULL,
  state ENUM('active','removed') NOT NULL DEFAULT 'active',
  removed_at VARCHAR(30) NULL,
  PRIMARY KEY (category_id, user_id),
  KEY idx_forum_member_user (user_id, state),
  CONSTRAINT fk_forum_member_category FOREIGN KEY (category_id)
    REFERENCES forum_categories(id) ON DELETE CASCADE,
  CONSTRAINT fk_forum_member_user FOREIGN KEY (user_id)
    REFERENCES rating_profiles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 迁移会把既有正式版块和个人版块设为 public，并为旧个人版块补 owner、成员和日志。

-- 管理操作留痕；版块只归档不物理删除，日志随版块保留
CREATE TABLE forum_moderation_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id VARCHAR(80) NOT NULL,
  actor_id VARCHAR(80) NOT NULL,
  action ENUM(
    'pin','unpin','lock','unlock','hide_thread','restore_thread',
    'remove_member','update_rules','rename',
    'grant_moderator','revoke_moderator','archive','publish','unpublish'
  ) NOT NULL,
  target_type ENUM('thread','reply','member','category') NOT NULL,
  target_id VARCHAR(80) NULL,
  reason VARCHAR(200) NULL,
  created_at VARCHAR(30) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_forum_moderation_category (category_id, id),
  KEY idx_forum_moderation_actor (actor_id, id),
  CONSTRAINT fk_forum_moderation_category FOREIGN KEY (category_id)
    REFERENCES forum_categories(id),
  CONSTRAINT fk_forum_moderation_actor FOREIGN KEY (actor_id)
    REFERENCES rating_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

P1 增加：

```sql
CREATE TABLE forum_category_publish_requests (
  id VARCHAR(80) NOT NULL,
  category_id VARCHAR(80) NOT NULL,
  requester_id VARCHAR(80) NOT NULL,
  statement VARCHAR(500) NULL,
  status ENUM('pending','approved','rejected','withdrawn') NOT NULL DEFAULT 'pending',
  reviewer_id VARCHAR(80) NULL,
  review_note VARCHAR(200) NULL,
  created_at VARCHAR(30) NOT NULL,
  reviewed_at VARCHAR(30) NULL,
  PRIMARY KEY (id),
  KEY idx_forum_publish_status (status, created_at),
  CONSTRAINT fk_forum_publish_category FOREIGN KEY (category_id)
    REFERENCES forum_categories(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

约定：

- 创建版块时在**同一事务**内写入 `forum_categories`、owner 关系、owner 成员关系和日志，任一失败全部回滚。
- 同一版块同一时间最多一条 `pending` 申请，用事务 + 状态条件更新保证。
- `member_count` 由有效成员实时统计后返回；列值在写入时同步维护，账号级联删除后读取仍以实时统计为准。
- 名称唯一索引沿用 `uq_forum_category_name`；保留词与词库在服务端校验，不能只靠客户端。
- 现有举报表需要扩展 `category` 目标类型，才能受理针对版块名称、简介和规则的举报；扩展时保持旧目标类型可读。
- 版块不提供物理删除接口，下线与归档都保留数据和日志。

## 7. 接口契约

沿用 `/api/v1/forum` 与现有校园 JWT。所有写接口返回 `Cache-Control: no-store`，错误格式沿用现有规范，`code` 为稳定字符串。

| 方法、路径 | 作用 | 关键约束 |
| --- | --- | --- |
| `GET /api/v1/forum/categories` | 官方版块 + 公开用户版块 + 我加入/我管理的未列出版块 | 每项增加 `visibility,status,rules,member_count,capabilities` |
| `POST /api/v1/forum/categories` | 创建用户版块，body `{name,description,rules}` | 配额 3；名称唯一；默认 `unlisted/active`；同事务写入 owner 与成员关系 |
| `GET /api/v1/forum/categories/:id` | 版块详情：规则、版主公开资料、成员数、我的能力 | 未列出版块登录可读，不要求先加入 |
| `PATCH /api/v1/forum/categories/:id` | 版主修改简介、规则、名称 | 改名 7 天冷却；名称过词库；`expected_version` 防覆盖 |
| `POST /api/v1/forum/categories/:id/join` | 加入用户版块 | 幂等；`removed` 状态 7 天内拒绝 |
| `DELETE /api/v1/forum/categories/:id/join` | 退出 | 幂等；owner 不能退出 |
| `GET /api/v1/forum/categories/:id/members` | 成员列表 | 版主/管理员；游标分页；不返回学籍字段 |
| `DELETE /api/v1/forum/categories/:id/members/:userId` | 移除成员，body `{reason}` | 版主；写日志；被移除者 7 天内不可重新加入 |
| `POST /api/v1/forum/categories/:id/threads/:threadId/pin` | 置顶 | 每版最多 3 条；返回新的 `is_pinned` |
| `DELETE /api/v1/forum/categories/:id/threads/:threadId/pin` | 取消置顶 | 幂等 |
| `POST /api/v1/forum/categories/:id/threads/:threadId/lock` | 锁定 | 幂等；锁定后普通用户不能回复 |
| `DELETE /api/v1/forum/categories/:id/threads/:threadId/lock` | 解锁 | 幂等 |
| `POST /api/v1/forum/threads/:id/hide` | 版主隐藏他人帖子，body `{reason,expected_version}` | 服务端从帖子反查版块鉴权；不能跨版隐藏 |
| `POST /api/v1/forum/threads/:id/restore` | 恢复被隐藏帖子 | 版主 7 天内撤销自己的操作；管理员不限 |
| `POST /api/v1/forum/categories/:id/report` | 举报版块名称/简介/规则 | 复用现有举报受理 |
| `GET /api/v1/forum/categories/:id/moderation-log` | 操作日志 | 版主看本版，管理员看全站；游标分页 |
| `GET /api/v1/forum/me/moderated-categories` | 我管理的版块 | 供「我的」页入口 |
| `POST /api/v1/forum/admin/categories/:id/publish` | 管理员公开版块，body 可带 `{reason}` | 写 `published_at`，进入目录 |
| `POST /api/v1/forum/admin/categories/:id/disable` | 管理员下线，body `{reason}` | `is_enabled=false`，帖子、收藏和消息一并不可见 |
| `POST /api/v1/forum/admin/categories/:id/archive`、`…/restore` | 归档（只读）／恢复 | 归档后禁止发帖，可恢复 |
| `PUT /api/v1/forum/admin/categories/:id/owner` | 指定 owner，body `{user_id}` | 必须是有效成员；用于转让或账号注销后接管 |
| `PUT /api/v1/forum/admin/categories/:id/moderators/:userId/revoke` | 撤销版主 | 写日志；撤销 owner 需传 `replacement_id` |
| `POST /api/v1/forum/categories/:id/publish-request` | 申请公开（P1，未实现） | 单一 pending；版块需有 ≥5 条非本人发帖 |
| `GET /api/v1/forum/admin/categories?status=pending`、`…/reject` | 审核队列与驳回（P1，未实现） | `review_note` 必填 |

`capabilities` 由服务端按当前身份计算，客户端只渲染，不自行推断：

```json
{
  "can_manage": true,
  "can_post": true,
  "can_join": false,
  "can_report": true,
  "can_review_reports": false
}
```

补充约定：

- `PUT /api/v1/forum/me/home-categories` 只接受当前用户可见的版块；版块被下线或归档后，偏好读取时跳过而不是报错。
- 旧客户端依赖的 `is_official`、`is_mine` 继续返回，语义不变；新客户端读 `capabilities`。
- 未列出版块不得进入热门、搜索与首页默认列表；本人主动固定的除外。
- 帖子列表、帖子详情、回复、收藏和消息跳转都要复用同一套版块可见性判断；未列出版块的内容不能从「全部」「热门」或全文搜索漏出，版块下线后旧链接也不得继续展示正文。
- 版块可见性变化（下线、归档、转为公开）后，需要让相关列表与详情缓存失效，不能只靠客户端重新拉取。

错误沿用论坛现有数值码：`40000` 参数、`40301` 权限、`40401` 不存在、`40904` 冲突、`42901` 限流。消息为中文提示，客户端按 HTTP 状态和提示处理，不依赖固定文案。

| HTTP | 场景 |
| --- | --- |
| 400 | 名称、介绍、规则、理由或 `expected_version` 无效 |
| 403 | 非版主调用管理接口；非成员在用户版块发帖；归档版块写操作；处理涉及自己的操作 |
| 404 | 版块、帖子不可见或已被下线 |
| 409 | 名称冲突、超过 3 个版块、置顶超过 3 条、成员冷却中、版本已变化、重复举报 |
| 429 | 创建、发帖、回复等写入超过限流 |

## 8. 客户端改动（已实现）

Flutter 已完成 P0 界面；Web/PWA 仍没有论坛，接口保持向后兼容，旧客户端照常使用官方版块。

| 文件 | 改动 |
| --- | --- |
| `models/campus_models.dart` | `ForumCategory` 增加可见性、规则、成员数、能力与版主；新增成员与日志模型 |
| `data/campus_repository.dart`、`default_campus_repository.dart` | 详情、更新简介与规则、加入退出、成员、置顶锁定、隐藏恢复、日志、举报 |
| `presentation/forum_category_page.dart` | 新增版块详情：规则、版主、成员数、加入/退出、版块号、成员管理与日志 |
| `presentation/forum_channels_sheet.dart` | 按「我管理的／官方／我加入的」分组；未公开标识；创建时填写规则；输入版块号打开 |
| `presentation/forum_thread_page.dart` | 版主菜单：置顶、锁定、隐藏（必须填理由） |
| `presentation/forum_moderation_dialog.dart` | 管理理由输入与管理动作文案 |
| `presentation/forum_editor_page.dart` | 只列出当前账号可发帖的版块，避免选到未加入的用户版块 |
| `presentation/campus_page.dart`、`app/app.dart` | 版块详情路由与返回后刷新目录 |

分享未列出版块暂时采用「复制版块号 → 对方在更多版块输入」的流程，不依赖深链。真正的 `/forum/c/:id` 深链和外部分享卡片留到 P1；当前流程已能让同学进入未公开版块并申请加入。

## 9. 分阶段

### P0：用户版块与基础管理

- [x] 服务端：创建版块（配额、命名、保留词、默认未列出）、owner 与成员关系落库。
- [x] 服务端：加入/退出、成员发帖权限、版块详情与规则。
- [x] 服务端：版主置顶、锁定、隐藏帖子、移除成员；全量日志。
- [x] 服务端：管理员公开、下线、归档、恢复、撤销版主、指定 owner。
- [x] Flutter：版块详情、成员、管理菜单、版块号入口。
- [ ] 部署：生产 MySQL 8 演练与灰度开放。

验收：双账号完成「建版 → 加入 → 发帖 → 置顶/锁定/隐藏 → 管理员恢复」；越权、并发建版、同名抢注、配额、归档只读、下线后列表/详情/收藏/消息跳转均不可见。服务端已覆盖，客户端待接入。

### P1：公开化与多人治理

- 公开申请与审核队列、目录分组、公开用户版块排序。
- 多版主、owner 转让、版主离职自动提醒。
- 举报升级与 24 小时 SLA、版块级限流。
- 申诉工单、版主操作月度抽查。

### P2：运营与发现

- 目录搜索、标签、活跃度排序。
- 版主数据看板（发帖、回复、举报处理时长）。
- 与「我的」页打通：我管理的版块、我加入的版块、管理提醒。

## 10. 与现有文档的差异

1. **默认可见性**：[FORUM_CHANNELS.md](./FORUM_CHANNELS.md) 说个人版块直接进入公共列表并排在官方之后；本文改为默认 `unlisted`，审核通过才进目录。理由是防版块通胀与抢注。若产品坚持原方案，至少要保留配额、抽检和一键下线。
2. **管理权来源**：从 `created_by`/`is_mine` 改为 `forum_category_moderators` 关系表，账号注销和版块转让不会再产生悬空权限。
3. **`created_by` 外键**：由 `RESTRICT` 改为 `ON DELETE SET NULL`，避免注销流程被版块卡住。
4. **首页偏好**：用户版块默认不占首页 8 个固定位，只有本人加入后才可固定。

## 11. 待确认

以下多数已在 P0 实现中按「建议」执行；仍属开放问题、留到 P1 的会单独注明。

- 未列出版块是否要求登录后才能浏览（建议：是）。
- 加入是否即时生效（建议：是；P1 可提供「需版主批准」开关）。
- 用户版块是否允许匿名发帖（建议：否）。
- 版主能否移动帖子到其他版块（建议：P1 再议，先只做隐藏）。
- 版块名称是否允许纯英文、数字和符号（建议：允许，但保留词与连续符号过滤）。
- 用户注销后版块默认归档还是强制转让（建议：有版主则转让，无则归档）。
- 「我管理的版块」入口放在「我的」页还是论坛面板（建议：我的页，论坛面板只做快捷跳转）。

## 12. 实现状态（2026-11-09）

服务端位于相邻私有仓库 `cuit-ratings-api`，本轮完成 P0：

| 内容 | 位置 |
| --- | --- |
| 迁移 | `migrations/011_forum_user_boards.sql` |
| 版块、成员、版主、日志、管理操作 | `src/forum/forum.service.ts` |
| 路由 | `src/forum/forum.controller.ts` |
| 下线版块对收藏与消息的可见性 | `src/community/community.service.ts` |
| 单元测试 | `src/forum/forum.service.spec.ts`（72 项） |
| 真实 SQL／HTTP 测试 | `src/forum/forum.mysql.spec.ts`（19 项） |

已实现并验证：

- 版块目录按可见性过滤；未列出版块可凭 ID 阅读，但不进全站列表、搜索和首页默认。
- 创建走配额 3、保留名、唯一名、同事务写 owner／成员／日志；并发创建由账号行锁串行化。
- 加入／退出、移除成员与 7 天冷却、成员数实时统计。
- 版主置顶（≤3）、锁定、隐藏（理由 + 版本）、恢复（仅撤销自己 7 天内操作）、操作日志分页。
- 管理员公开、下线、归档、恢复、撤销版主、指定 owner；下线后帖子、收藏、消息同时不可见。
- 版块举报写入现有 `rating_reports`，目标类型为 `forum_category`。
- 改名 7 天冷却；归档版块只读；`created_by` 外键改为 `SET NULL`，版块本身不再阻塞账号注销（首页偏好、帖子等既有外键仍由注销流程处理）。

验证：`pnpm typecheck`、`pnpm build` 通过；全部 218 项测试通过，其中 31 项在隔离 MySQL 9.3.0 上真实执行（含迁移、JWT、HTTP、并发与越权）。Flutter 侧 `flutter analyze` 无问题，393 项测试通过，新增版块详情、加入、编辑与帖子管理菜单用例。测试命令：

```bash
FORUM_TEST_MYSQL_PORT=<隔离端口> COMMUNITY_TEST_MYSQL_PORT=<隔离端口> \
  ANNOUNCEMENTS_TEST_MYSQL_PORT=<隔离端口> pnpm test
```

尚未完成：

- 公开申请与审核队列（P1）、多版主任命与自动降级（P1）。
- 移除成员、被隐藏帖子的站内申诉通知；当前只有日志和管理员处理入口。
- 深链分享与外部分享卡片；当前用版块号手动分享。
- 生产部署：迁移未在生产 MySQL 8 执行，`/api/v1/forum/` 代理已覆盖新路由，不需要改 NGINX。
