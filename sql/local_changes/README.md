# sql/local_changes — 本私服本地增量 SQL（版本化管理）

> 这些是本机运行时修复产生的数据库改动，不属于上游 `sql/`（上游 base 是 186 个分片 + database_updates）。
> 必须版本化管理，换机器/重装时按序重放即可恢复（配合根目录 `切换电脑交接清单.md`）。

## 文件清单（按编号顺序执行）

| 文件 | 目标库 | 说明 |
|---|---|---|
| `001_npc_190001.sql` | tw_world | Eluna Test NPC 190001 完整入库（模板 + 实体 + npc_flags 修复） |
| `002_account_rank.sql` | tw_logon | admin rank=4（SEC_ADMINISTRATOR，`.reload eluna` 需要） |
| `003_realmlist.sql` | tw_logon | realmlist 初始化/修正（id=1，127.0.0.1:8090） |
| `010_id_registry.sql` | tw_world | ARPG ID 段登记（锁段，改 ID 前先查本文件） |
| `011_phase0_probes.sql` | tw_world | 阶段0 探针：词缀池 9001→IRP117 + 测试紫装 950001 |
| `012_phase1_guide_vendor.sql` | tw_world | 阶段1 引导：技能书 905001 / 随身商贩 190105 / 艾薇儿 190101 |
| `013_phase1_gems.sql` | tw_world | 阶段1 宝石：四色 901001-901020 + 书页 905002 / 书 905003 |
| `014_phase1_rune_punch.sql` | tw_world | 阶段1 符文 900001-900033 + 打孔器 905010（**v3：固化导出，已验证可重放**） |
| `015_phase1_punch_ddl.sql` | tw_char | 打孔记录表 `soulcore_arpg_sockets`（独立 DDL） |
| `016_phase1_gate.sql` | tw_char + tw_world | 阶段1 符文门控：物品 905004 远古符文卷轴 + 配置表 `soulcore_arpg_gate`（**全限定名，任意默认库可重放**） |

> ⚠️ `_backup_014_before_replay.sql` 是 014 重放前的数据快照（保留作回滚依据，不参与重放序列）。

## 用法

```bash
MYSQL="<mariadb>/bin/mysql.exe"
# 001-003 基建
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 001_npc_190001.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 002_account_rank.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 003_realmlist.sql
# 010+ 阶段1
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 010_id_registry.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 011_phase0_probes.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 012_phase1_guide_vendor.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 013_phase1_gems.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 014_phase1_rune_punch.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_char   < 015_phase1_punch_ddl.sql
# 016 跨库（tw_char + tw_world），用全限定名，任意默认库 source 即可
"$MYSQL" -uroot -p --default-character-set=utf8 -e "source <绝对路径>/016_phase1_gate.sql"
```

## 规范

- 编号递增（`NNN_` 前缀），所有文件**幂等可重放**（INSERT IGNORE / REPLACE / UPDATE 兜底）。
- 文件头注释写明：来源、原因、目标库、用法。
- **重要 DDL 单独成文件**（曾因 014 数据段报错连带 DDL 段未执行 → 表缺失）。
- **全列 INSERT/REPLACE 不要手写**（014 v1/v2 手写 137 列 vs 表 130 列，从未重放成功）——用 `工具/gen_runes.py` 这类生成器产出后 `mysqldump` 固化。
- 新增本地改动时按此格式追加，并在 `切换电脑交接清单.md` 的同步清单中登记。
