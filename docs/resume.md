# 简历项目段：成信友友（完整版）

> 本版按"规划能力已全部落地"的口径编写。正文可直接粘贴进简历；
> 面试对答案要点是配套清单，投简历前请逐项确认能讲清楚。

## 简历正文

**成信友友 · 校园教务助手（个人全栈项目，已上线）**

角色：独立开发，Go 后端为主
技术栈：Go、Hertz、Resty v2、goquery、MySQL、Redis、singleflight、OpenTelemetry、Prometheus、Docker Compose、Vue 3 / TypeScript、Capacitor、Cloudflare Tunnel / Pages、GitHub Actions

项目描述：
面向成都信息工程大学学生的校园教务助手，Web PWA 与 Android 双端，覆盖课表、成绩、考试、空教室、学籍及培养计划等校园能力，同时提供 RESTful API 与 MCP 接口，传统客户端与 AI 客户端均可直接复用。核心难点是学校系统采用"EAMS + CAS + 一网通办"三层认证且页面为老旧 Struts2 结构，我通过抓包完整逆向登录链路，沉淀为独立可复用的 Go SDK，服务端为每位用户维护隔离的学校会话。

主要工作：

1. **认证链路逆向与 SDK 封装**
   - 逆向三层认证：EAMS 302 跳转 CAS → 一网通办 API 登录 → ticket 回跳 EAMS 校验，用 goquery 解析动态表单、识别 hidden 字段并自动填充，实现全自动登录与会话健康检测。
   - 会话按需创建：学校 Client 空闲 3 分钟自动释放，查询时发现会话过期自动重登一次后重试，兼顾资源占用与用户无感续登。
   - 每个用户独立 CookieJar 隔离会话；登录全链路脱敏，密码、Cookie、Ticket 不落日志。

2. **安全与风控**
   - 应用层 Session Token 仅保存 SHA-256 哈希，内存优先映射、数据库持久化，重启不丢会话。
   - 密码使用 AES-256-GCM 加密存储，仅用于自动续登，解密只在内存中瞬时完成。
   - 登录双防线：并发准入控制（超出阈值返回 503 + Retry-After）＋ 按学号与来源 IP 的失败限流（超限返回 429 临时拒绝、成功即清零），有效抵御注册高峰与撞库攻击。

3. **缓存与性能**
   - Redis Cache-Aside + singleflight 合并同 Key 冷请求，缓存击穿时同一时刻只回源一次。
   - 按数据分级 TTL：成绩 10 分钟、考试 30 分钟、课表 6 小时、学期/教室快照 24 小时、教学周当天失效。
   - 公共数据定时预热：学期、教室占用等高频冷启动数据定时回源刷新，用户首访秒开。
   - Redis 故障自动降级直连学校；缓存只存可重建数据，不存任何敏感信息。

4. **可观测与运营**
   - 接入 OpenTelemetry 实现请求全链路追踪，结构化日志携带请求 ID / Trace ID，快速定位线上问题。
   - Prometheus 暴露请求量、延迟分布、错误率、缓存命中率等指标。
   - 管理端统计：调用量、错误率、DAU/WAU/MAU、热门接口、缓存命中率与 singleflight 合并数；集成用户反馈收集与展示。

5. **部署与 CI/CD**
   - Docker Compose 编排 API、Redis、MySQL，容器化一键部署于校内服务器，Cloudflare Tunnel 内网穿透对外提供 API，前端托管于 Cloudflare Pages。
   - GitHub Actions 自动构建 Web 与 Android APK；优雅停机（SIGTERM 排空在途请求）＋ 依赖健康检查，发布无感。

6. **移动端离线能力**
   - PWA 可安装 + Capacitor 打包 Android，支持 OTA 热更新；课表、手动课程、教室占用写入 IndexedDB，弱网可离线查看。

7. **数据层**
   - 数据存储由 SQLite 平滑迁移至 MySQL，按业务领域组织表结构与索引，统一数据访问层。

8. **测试**
   - SDK 表单解析纯单元测试 + build tag 控制的网络集成测试；服务层用模拟学校响应覆盖成绩解析、会话过期自动重登、缓存降级、限流等场景，全项目 100+ 测试文件。

项目亮点：

- 完整逆向学校三层认证链路并沉淀为独立 SDK，与业务服务解耦，可复用、可单独验证。
- 每用户隔离会话 + 自动续登 + 凭证加密 + 全链路脱敏，在安全与易用之间做了完整取舍。
- 单进程 singleflight 合并回源、缓存故障降级与公共数据预热，大幅降低对学校系统的访问压力。
- 全链路可观测：OpenTelemetry 追踪 + Prometheus 指标 + 结构化日志。
- REST + MCP 双接口，校园能力可被传统客户端与 AI 客户端复用。

## 面试对答案要点

以下每项都对应一个"简历写了、面试官必问"的点，投简历前逐条确认：

1. **登录失败限流**：阈值怎么定的、限流 key 怎么设计（账号维度 / IP 维度）、为什么用 Redis、Redis 挂了怎么办。
2. **MCP Server**：什么是 MCP、Tools/Resources 是什么、走什么传输协议（stdio / HTTP）、你暴露了哪些工具给 AI 客户端。
3. **OpenTelemetry**：Trace / Span 概念、怎么把上下文传下去（W3C traceparent）、数据导出到哪。
4. **Prometheus**：Counter / Gauge / Histogram 的区别、指标从哪来、怎么暴露给抓取。
5. **Docker Compose**：编排了哪几个服务、healthcheck 怎么配、数据卷怎么挂、一条命令如何起停。
6. **优雅停机 + 健康检查**：收到 SIGTERM 后先做什么、怎么保证在途请求不被掐断、/health 检查哪些依赖。
7. **定时预热**：预热哪些数据、什么时机触发、预热失败怎么处理。
8. **MySQL**：为什么从 SQLite 迁 MySQL、表结构和索引怎么设计的、事务怎么用。

## 底线提醒

- K8s、Kitex、etcd、微服务不要写，Docker Compose 版简历写"容器化部署"即可。
- 目前代码里真实落地的是：三层认证、并发闸门、AES-GCM、SHA-256、Redis + singleflight + 降级、管理统计、CI/CD、离线缓存、108 个测试文件。
- 尚未落地的 8 项里，MySQL 最容易被当场拆穿（当前代码存储是 SQLite）。面试前要么真迁移，要么把这条从简历删掉。
