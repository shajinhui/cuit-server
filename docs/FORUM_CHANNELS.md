# 论坛版块与首页展示

## 客户端已实现

- 论坛首页固定显示「全部」「热门」，首次进入默认展示 7 个正式版块。
- 固定频道之后展示用户选择的版块；点击「更多」打开完整版块面板。
- 完整面板支持浏览全部版块、进入版块、编辑首页展示版块（最多 8 个）。
- 支持创建个人版块，创建成功后自动加入首页；版块名称 2–12 字，介绍最多 100 字。
- 版块加载或首页偏好加载失败时，固定频道和帖子流仍可用；相关设置会提示服务端尚未上线。

客户端代码：

- `flutter/lib/features/campus/presentation/forum_channels_sheet.dart`
- `flutter/lib/features/campus/presentation/campus_page.dart`
- `flutter/lib/features/campus/data/{campus_repository.dart,default_campus_repository.dart}`
- `flutter/lib/features/campus/models/campus_models.dart`

## 服务端接口契约

以下接口沿用 `/api/v1/forum` 和现有校园 JWT，新增接口需返回 `Cache-Control: no-store`。

| 方法、路径 | 作用 | 响应 `data` |
| --- | --- | --- |
| `GET /api/v1/forum/categories` | 全部启用版块 | 数组，每项包含 `id,name,description,sort_order,is_official,is_mine` |
| `POST /api/v1/forum/categories` | 创建个人版块；body `{name, description}` | 新 `is_official: false, is_mine: true` 版块 |
| `GET /api/v1/forum/me/home-categories` | 首页展示版块顺序 | `{category_ids: string[]}` |
| `PUT /api/v1/forum/me/home-categories` | 保存首页展示版块；body `{category_ids: string[]}` | `{category_ids: string[]}` |

约束建议：

- 「全部」「热门」是客户端固定频道，不写入版块表，也不写入首页偏好。
- 首页偏好最多 8 个，必须去重、按提交顺序保存，且仅接受启用版块；新用户没有偏好时返回 7 个正式版块的默认顺序。
- 官方版块排在个人版块之前；个人版块按创建顺序追加。
- `is_mine` 根据当前登录用户与版块创建者计算，不返回认证 subject。
- 创建版块应复用现有社区写入限流；名称唯一，避免并发重复创建。
- 版块目录和首页偏好均按账号隔离，切换账号后不得复用上一账号数据。

## 版块、主题与频道的边界

版块表示一个长期存在的内容空间；主题表示帖子在版块里的用途；频道表示跨版块的内容流。三者不能用同一组标签表达。

- 固定频道：`全部`、`热门`。它们不写入版块表；`精华`暂时作为后续的内容流筛选，不预置成版块。
- 主题筛选：`课程讨论`、`经验主题`、`事务整理`、`本校问答`。它们只在筛选面板出现，不创建同名版块。
- 独立模块：`二手`、`点评`、`通知`。二手和点评已经有自己的校园入口，通知由官方公告流承载。
- 正式版块：只保留下面 7 个核心校园场景；低频兴趣主题由用户按需创建。

## 预置常用版块

后端正式种子使用下列稳定 ID 和名称；前端只读取这套正式版块。首页首次进入展示下面 7 个版块，用户可以从「更多」中调整，最多固定 8 个。

| sort_order | id | 名称 | 说明 |
| --- | --- | --- | --- |
| 1 | general | 日常 | 校园生活、见闻和日常闲聊。 |
| 2 | study | 学习 | 课程、考试、资料与学习经验。 |
| 3 | mutual | 互助 | 校内互帮互助和资源交换。 |
| 4 | lost | 失物 | 失物招领与寻物启事。 |
| 5 | partner | 搭子 | 自习、运动、吃饭和出行搭子。 |
| 6 | activity | 社团活动 | 社团、组织、讲座与校园活动。 |
| 7 | treehole | 树洞 | 匿名树洞与心情记录，需配合审核和举报。 |

以下名称不再作为本次正式版块：

- `essence`：改为精华频道。
- `market`：使用校园二手模块。
- `review`：使用评分模块。
- `help`：并入 `mutual`，发帖时选择「求助」主题。
- `organization`：并入 `activity`。
- `notice`：改为官方公告流。
- `pet`、`photo`、`rent`、`groupbuy`：不写入官方种子，用户有需要时自行创建。

需要的表结构：

```sql
ALTER TABLE forum_categories
  ADD COLUMN is_official BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN created_by VARCHAR(80) NULL,
  ADD COLUMN created_at VARCHAR(30) NULL,
  ADD UNIQUE KEY uq_forum_category_name (name),
  ADD CONSTRAINT fk_forum_category_creator
    FOREIGN KEY (created_by) REFERENCES rating_profiles(id);

CREATE TABLE forum_home_preferences (
  user_id VARCHAR(80) NOT NULL,
  category_id VARCHAR(80) NOT NULL,
  position INT NOT NULL,
  PRIMARY KEY (user_id, category_id),
  KEY idx_forum_home_position (user_id, position),
  CONSTRAINT fk_forum_home_user
    FOREIGN KEY (user_id) REFERENCES rating_profiles(id),
  CONSTRAINT fk_forum_home_category
    FOREIGN KEY (category_id) REFERENCES forum_categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

可直接作为 `007_forum_channels.sql` 的种子部分：

```sql
UPDATE forum_categories
SET name = '日常', description = '校园生活、见闻和日常闲聊。', sort_order = 1,
    is_enabled = TRUE, is_official = TRUE
WHERE id = 'general';

UPDATE forum_categories
SET name = '学习', description = '课程、考试、资料与学习经验。', sort_order = 2,
    is_enabled = TRUE, is_official = TRUE
WHERE id = 'study';

INSERT INTO forum_categories
  (id, name, description, sort_order, is_enabled, is_official, created_by, created_at)
VALUES
  ('mutual', '互助', '校内互帮互助和资源交换。', 3, TRUE, TRUE, NULL, NULL),
  ('lost', '失物', '失物招领与寻物启事。', 4, TRUE, TRUE, NULL, NULL),
  ('partner', '搭子', '自习、运动、吃饭和出行搭子。', 5, TRUE, TRUE, NULL, NULL),
  ('activity', '社团活动', '社团、组织、讲座与校园活动。', 6, TRUE, TRUE, NULL, NULL),
  ('treehole', '树洞', '匿名树洞与心情记录。', 7, TRUE, TRUE, NULL, NULL)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  sort_order = VALUES(sort_order),
  is_enabled = TRUE,
  is_official = TRUE;

-- 迁移完成后，/api/v1/forum/categories 只返回正式种子和用户创建的版块。
```
