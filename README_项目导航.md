# SoulCore Tortoise WoW 项目导航

> 主目录整理于 2026-08-19；**2026-08-22 建内容版本控制基线**（迁移链/Lua/DBC/deploy 入库）。
> 服务端运行在 Ubuntu（soulcore.asia:56789），本地保留开发文档、脚本、客户端与版本化内容基线。

## 根目录保留项

| 项 | 说明 |
|---|---|
| `客户端/` | 游戏客户端（10.5GB，含 Data/patch-A.mpq，需手动更新补丁）— **不入库** |
| `_archive/` | 全部历史归档资产（只读来源，**不入库**，见下） |
| `outputs/` | 一次性工作区（P1/P2 探针与中间产物，**不入库**） |
| `weekly-build.yml` | GitHub Actions 周构建工作流 |
| `sql/local_changes/` | ⭐ **SQL 迁移链 001-017**（唯一真源，可复现内容终态） |
| `lua_scripts/` | ⭐ **自定义 Lua**（core / arpg / enchant 三组） |
| `deploy/` | ⭐ **部署运维脚本**（已脱敏，凭据走 env） |
| `docs/` | ⭐ **现状 / 工作流SOP / 报告归档** |

## ⭐ 版本化内容目录（2026-08-22 新基线）

| 目录 | 内容 | 入口 |
|---|---|---|
| `docs/服务器现状_2026-08-22.md` | 权威现状（拓扑/库/终态/备份/归属） | 服务器状态速查 |
| `docs/工作流SOP_2026-08-22.md` | **以后开发流程**（改动→提交→应用→记录） | 开发前必读 |
| `sql/local_changes/README.md` | 迁移链索引（编号/目标库/状态） | 数据库改动 |
| `lua_scripts/README.md` | 三组脚本用途与部署现状 | Lua 开发 |
| `deploy/README.md` | 脚本清单 + 环境变量说明 | 远程运维 |
| `docs/reports/` | 随机附魔 P0/P1/P2 报告、衬衣/可行性等 | 工作记录 |

## _archive/ 归档索引（历史只读）

| 归档 | 内容 | 常用入口 |
|---|---|---|
| `_audit/` | ⭐ **源码树**：soulcore（主服务端，带 .git）+ oyturtle/WYTurtle（带 .git） | 编译/改代码 |
| `random_enchant_migration_20260819/` | 随机附魔移植工作目录（SIE_merged*.dbc、gen/deploy 脚本、**SOP**） | 随机附魔工具链 |
| `工具/` | **已迁至 `deploy/`（脱敏）**，仅剩 log/tar.gz 残留 | — |
| `pb-register-web/` | 注册网页（Next.js，:3000） | 注册站 |
| `3.35lua_参考/` | 3.3.5 Eluna 参考素材 | 移植对照 |
| `PlayerBots文档/` | PB 官方文档 5 篇 | PB 开发 |
| `tools_dbc/` | DBC 工具（SIE 构建相关） | DBC 操作 |
| `warrior_probe/` | 战士职业探测脚本 | 职业数据 |
| `项目文档与脚本_2026-08-19/` | 原根目录散落资产：`md/`（部署记录、衬衣、PlayerBots 评估等 16 份）、`py/`、`lua/`、`sql/` | 历史文档 |
| `MangosBot面板命令核查与修复包_2026-08-18/` | 面板终审交付物 | 面板维护 |
| `ARPG_归档_2026-08-12/` 等 | 早期归档 + 一次性脚本与报告 + 记忆备份等 | — |

## 核心文档速查

- `docs/服务器现状_2026-08-22.md` — **权威现状**（2026-08-22 基线）
- `docs/工作流SOP_2026-08-22.md` — **开发工作流**（必读）
- `sql/local_changes/README.md` — 迁移链总目
- `_archive/项目文档与脚本_2026-08-19/md/部署与Eluna移植工作记录.md` — 主工作日志（权威，含 Eluna 铁律/DBC 规则）
- `_archive/random_enchant_migration_20260819/随机附魔移植工作流SOP.md` — 橙装附魔 SOP
- `docs/reports/` — P0/P1/P2 随机附魔报告、冷备恢复指南
- `切换电脑交接清单.md`（在 `项目文档与脚本_.../md/`）— 换机指南

## 工作流提醒

- **新开发**：按 `docs/工作流SOP_2026-08-22.md` —— 新编号 SQL 迁移 → 提交 → 应用 → 记录。
- **服务器真身同步**：`deploy/sync_server_baseline.py`（需 python+SSH）生成 `docs/服务器现状_快照_*`。
- **口令**：一律走环境变量 `SOULCORE_SSH_PASS` 等（值在用户记忆），禁止明文入库。
- 历史归档引用（2026-08-19 前路径）多数已失效，统一前缀 `_archive/…`。