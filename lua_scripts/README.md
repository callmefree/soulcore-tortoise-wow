# lua_scripts — 自定义 Lua 脚本（版本化管理）

> 2026-08-22 整理：历史散落的 Lua 归位为 core/arpg/enchant 三组。
> 各组对应 `_archive/` 或 `_audit/` 中原始出处；部署目标均为 PB 服 `/opt/soulcore-pb/server/bin/lua_scripts/`。

## core/ — 引擎基础脚本（随源码仓库正式入库，CI 可打包）

| 文件 | 用途 | 出处 |
|---|---|---|
| `welcome.lua` | 登录欢迎（ServerEvent 14） | `_audit/soulcore/lua_scripts/` |
| `test_gossip.lua` | Eluna NPC gossip 测试 | `_audit/soulcore/lua_scripts/` |
| `super_hearthstone.lua` | 超级炉石：右键传送菜单（自定义传送点持久化） | `_audit/soulcore/lua_scripts/` |

## arpg/ — ARPG 阶段1 功能（1-1 引导 / 1-2 商贩 / 1-3 喊话 / 1-7 重铸）

| 文件 | 用途 | 出处 |
|---|---|---|
| `guide_npc.lua` | 1-1 新手引导 NPC（艾薇儿 / 技能书） | `ARPG_归档_2026-08-12/lua_scripts_arpg/` |
| `travel_vendor.lua` | 1-2 随身商贩 | 同上 |
| `city_crier.lua` | 1-3 主城喊话（4 分钟间隔） | 同上 |
| `reforge.lua` | 1-7 套装重铸（混沌重铸石） | 同上 |

> 已砍除的 gem/rune/socket/combine/gate 脚本（配 013-016 废弃 SQL）可在 git 历史与
> `ARPG_归档_2026-08-12` 中找到，无需恢复。

## enchant/ — 附魔/成长衬衣/随机附魔

| 文件 | 用途 | 部署现状 |
|---|---|---|
| `growing_shirt.lua` / `_mvp` / `_v2` | 成长衬衣附魔（三个迭代版本，另见 `docs/reports/` 衬衣文档） | 开发副本 |
| `starter_gift_bag.lua` | 新手礼包 | 开发副本 |
| `random_enchant.lua` | **随机附魔（Orange 试点，已部署，1100 行）** | ✅ PB 服 |
| `random_enchant_new.lua` | 随机附魔 WIP 变体（937 行，未部署） | 开发中 |
| `enchant_data_extract.lua` | 附魔数据提取脚本（工具，非游戏逻辑） | — |

> 随机附魔对应 DBC 与权重池：见 `dbc/random_enchant/`、`sql/local_changes/018-023`。

## 部署

```bash
# 单个脚本推送到 PB 服
python deploy/ssh_soulcore.py --put lua_scripts/core/welcome.lua /opt/soulcore-pb/server/bin/lua_scripts/welcome.lua
# 热重载（GM 命令）
.reload eluna
```
> 详细流程见 `docs/工作流SOP_2026-08-22.md`。