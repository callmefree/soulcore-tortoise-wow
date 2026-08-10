# sql/local_changes — 本私服本地增量 SQL（版本化管理）

> 这些是本机运行时修复产生的数据库改动，不属于上游 `sql/`（上游 base 是 186 个分片 + database_updates）。
> 必须版本化管理，换机器/重装时按序重放即可恢复（配合根目录 `切换电脑交接清单.md`）。

## 文件清单（按编号顺序执行）

| 文件 | 目标库 | 说明 |
|---|---|---|
| `001_npc_190001.sql` | tw_world | Eluna Test NPC 190001 完整入库（模板 + 实体 + npc_flags 修复） |
| `002_account_rank.sql` | tw_logon | admin rank=4（SEC_ADMINISTRATOR，`.reload eluna` 需要） |
| `003_realmlist.sql` | tw_logon | realmlist 初始化/修正（id=1，127.0.0.1:8090） |
| `010_id_registry.sql` | tw_world | ARPG ID 段登记（锁段：符文/宝石/通货/红装等） |
| `011_phase0_probes.sql` | tw_world | 阶段0 探针：词缀池 9001→IRP117 + 测试紫装 950001（保留） |
| `012_phase1_guide_vendor.sql` | tw_world | 905001 技能书 / 190105 随身商贩 / 190101 艾薇儿 |
| `013_phase1_gems.sql` | tw_world | 四色宝石 901001-901020 + 书页 905002 / 书 905003 |
| `014_phase1_rune_punch.sql` | tw_world | 符文 900001-900033 + 905010 打孔器（gen_runes.py 固化，幂等可重放） |
| `016_phase1_gate.sql` | tw_char+tw_world | 1-9 符文门控：905004 远古符文卷轴 + soulcore_arpg_gate 配置表 |
| `017_phase1_reforge.sql` | tw_world | 1-7 套装重铸：904003 混沌重铸石 |

## 用法

```bash
MYSQL="<mariadb>/bin/mysql.exe"
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 001_npc_190001.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 002_account_rank.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 003_realmlist.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 010_id_registry.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 011_phase0_probes.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 012_phase1_guide_vendor.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 013_phase1_gems.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 014_phase1_rune_punch.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 016_phase1_gate.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 017_phase1_reforge.sql
```

> 注：016 内用跨库全限定名（tw_char.soulcore_arpg_gate），默认库任意均可；016/017 均双重放验证幂等。

## 规范

- 编号递增（`NNN_` 前缀），所有文件**幂等可重放**（INSERT IGNORE / REPLACE / UPDATE 兜底）。
- 文件头注释写明：来源、原因、目标库、用法。
- 新增本地改动时按此格式追加，并在 `切换电脑交接清单.md` 的同步清单中登记。
