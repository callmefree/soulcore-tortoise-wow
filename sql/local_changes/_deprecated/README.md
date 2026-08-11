# 废弃 SQL（_deprecated/）

**2026-08-11 用户决策：砍掉宝石、符文、打孔器、合成链、门控五个系统**，
槽位 3/4/5/6 全部让给阶段 2 词缀系统（走引擎原生 IRP 机制）。

本目录文件**禁止重放**，仅保留追溯。已从 `sql/local_changes/` 移出。

| 文件 | 原系统 | 废弃原因 |
|---|---|---|
| 013_phase1_gems.sql | 1-5 四色宝石 + 1-6 合成链 | 宝石/合成链整体砍除 |
| 014_phase1_rune_punch.sql | 1-4 符文 + 1-8 打孔器 | 符文/打孔器整体砍除 |
| 016_phase1_gate.sql | 1-9 符文门控 | 钥匙=符文、奖励=宝石，均砍除 |
| 018_phase1_sockets_ddl.sql | 1-8 打孔记录表 DDL | 打孔器砍除，表不再需要 |

**配套移除**：`server/bin/lua_scripts/arpg/` 下的 gem.lua / rune.lua / socket.lua /
combine.lua / gate.lua（git 历史可恢复）。

**阶段 1 保留**：1-1 新手引导、1-2 随身商贩、1-3 主城喊话、1-7 套装重铸
（guide_npc.lua / travel_vendor.lua / city_crier.lua / reforge.lua）。
