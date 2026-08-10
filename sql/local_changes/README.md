# sql/local_changes — 本私服本地增量 SQL（版本化管理）

> 这些是本机运行时修复产生的数据库改动，不属于上游 `sql/`（上游 base 是 186 个分片 + database_updates）。
> 必须版本化管理，换机器/重装时按序重放即可恢复（配合根目录 `切换电脑交接清单.md`）。

## 文件清单（按编号顺序执行）

| 文件 | 目标库 | 说明 |
|---|---|---|
| `001_npc_190001.sql` | tw_world | Eluna Test NPC 190001 完整入库（模板 + 实体 + npc_flags 修复） |
| `002_account_rank.sql` | tw_logon | admin rank=4（SEC_ADMINISTRATOR，`.reload eluna` 需要） |
| `003_realmlist.sql` | tw_logon | realmlist 初始化/修正（id=1，127.0.0.1:8090） |

## 用法

```bash
MYSQL="<mariadb>/bin/mysql.exe"
"$MYSQL" -uroot -p --default-character-set=utf8 tw_world < 001_npc_190001.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 002_account_rank.sql
"$MYSQL" -uroot -p --default-character-set=utf8 tw_logon < 003_realmlist.sql
```

## 规范

- 编号递增（`NNN_` 前缀），所有文件**幂等可重放**（INSERT IGNORE / REPLACE / UPDATE 兜底）。
- 文件头注释写明：来源、原因、目标库、用法。
- 新增本地改动时按此格式追加，并在 `切换电脑交接清单.md` 的同步清单中登记。
