# SoulCore Tortoise WoW 项目导航

> 主目录整理于 2026-08-19（所有历史资产归档至 `_archive/`）。
> 服务端运行在 Ubuntu（soulcore.asia:56789），本地仅保留开发文档、脚本与客户端。

## 根目录保留项

| 项 | 说明 |
|---|---|
| `客户端/` | 游戏客户端（10.5GB，含 Data/patch-A.mpq，需手动更新补丁） |
| `_archive/` | 全部归档资产（见下） |
| `weekly-build.yml` | GitHub Actions 周构建工作流 |
| `.git/` `.gitignore` `.workbuddy/` | 版本库 / 记忆技能 |

## _archive/ 归档索引

| 归档 | 内容 | 常用入口 |
|---|---|---|
| `_audit/` | ⭐ **源码树**：soulcore（主服务端，带 .git）+ oyturtle/WYTurtle（Windows+Eluna 兼容层，带 .git） | 编译/改代码 |
| `random_enchant_migration_20260819/` | 随机附魔移植工作目录：SIE_merged.dbc、refine_db_grounded.py、deploy_final.py、random_enchant.lua、**SOP** | 橙装附魔 |
| `工具/` | 运维部署脚本：deploy_*.py、ssh_soulcore.py、tunnel_3306.py、3 个 systemd service | 部署/SSH/隧道 |
| `pb-register-web/` | 注册网页（Next.js，:3000，写 tw_pb_logon.account） | 注册站 |
| `3.35lua_参考/` | 3.3.5 Eluna 脚本参考素材 | 移植对照 |
| `PlayerBots文档/` | PB 官方文档 5 篇 | PB 开发 |
| `tools_dbc/` | DBC 工具（SIE 构建相关） | DBC 操作 |
| `warrior_probe/` | 战士职业探测脚本 | 职业数据 |
| `项目文档与脚本_2026-08-19/` | 原根目录散落资产：`md/`（部署记录、衬衣系列、PlayerBots 评估等 16 份）、`py/`、`lua/`、`sql/` | **主文档都在 md/** |
| `文档归档_2026-08-19/` | Shyalya 分析 txt ×3 | 历史分析 |
| `一次性脚本与报告_2026-08-19/` | 原 _tmp：132 项探针脚本 + 17 份审查报告 | 历史报告 |
| `记忆技能与专家备份_2026-08-19/` | 记忆/技能/专家团备份（+zip），含迁移检查单 | 换机迁移 |
| `MangosBot面板命令核查与修复包_2026-08-18/` | 面板终审交付物（报告+客户端面板+源码快照） | 面板维护 |
| `ARPG_归档_2026-08-12/` `py_遗留归档_2026-08-16/` | 早期归档 | — |

## 核心文档速查（归档于 项目文档与脚本_2026-08-19/md/）

- `部署与Eluna移植工作记录.md` — 主工作日志（权威，含状态基线/Eluna铁律/DBC规则）
- `成长衬衣_附魔工作流完整记录.md` + `成长衬衣_v2_开发计划.md` — 衬衣附魔
- `随机附魔移植工作流SOP.md`（在 random_enchant_migration_20260819/）— 橙装附魔 SOP
- `切换电脑交接清单.md` — 换机指南
- `天赋附魔方案_可行性审计结论.md`、`战士三系天赋附魔_规格与审计结论.md` — 天赋附魔
- `SOULCORE_知识库总览.md`、`三方进度对比_Shyalya_上游_我们.md` — 总览与对比

## 工作流提醒

- 新开发：在 `_archive/工具/` 或对应工作目录放脚本，完成后产物归档到 `_archive/` 对应位置
- 记忆中的历史路径引用（2026-08-19 前）多数已失效，统一前缀改为 `_archive/项目文档与脚本_2026-08-19/` 等
- 服务器凭据/敏感信息在记忆备份中，禁止入库、禁止上传公共仓库
