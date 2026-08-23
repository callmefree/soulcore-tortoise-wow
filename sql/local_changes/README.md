# sql/local_changes — 私有增量 SQL 迁移链（版本化真源）

> **用途**：本目录是唯一真源，按序（001→017）重放即可复现主服内容终态。
> 2026-08-23 整理：随机附魔/IRP 迁移（018-023）已归档至 `_archive/random_enchant_irp_cleanup_20260823/`。
> 上游 `sql/`（原 186 分片 base + database_updates）与本链**不同**，本链只含本私服二次开发增量。

## 活动链（按顺序执行）

| 编号 | 文件 | 目标库 | 说明 | 状态 |
|---|---|---|---|---|
| 001 | `001_npc_190001.sql` | tw_world | Eluna Test NPC 190001 入库（模板+实体+npc_flags） | ✅ |
| 002 | `002_account_rank.sql` | tw_logon | admin rank=4（SEC_ADMINISTRATOR，`.reload eluna` 可用） | ✅ |
| 003 | `003_realmlist.sql` | tw_logon | realmlist id=1 → 127.0.0.1:8090 | ✅ |
| — | *(004–009 从未编入，历史跳跃)* | | | |
| 010 | `010_id_registry.sql` | tw_world | ARPG ID 段登记（锁段） | ✅ |
| 011 | `011_phase0_probes.sql` | tw_world | 阶段0 探针：词缀池 9001→IRP117 + 测试紫装 | ✅ |
| 012 | `012_phase1_guide_vendor.sql` | tw_world | 905001 技能书 / 190105 随身商贩 / 190101 艾薇儿 | ✅ |
| 017 | `017_phase1_reforge.sql` | tw_world | 1-7 套装重铸：904003 混沌重铸石 | ✅ |

## 归档记录（禁止重放）

**2026-08-23 决策：随机附魔/IRP 相关全部归档**
018-023（IRP 迁移链）连同 `lua_scripts/enchant/random_enchant*.lua`、`dbc/random_enchant/` 已归档至
`_archive/random_enchant_irp_cleanup_20260823/`，不在 git 中追踪。

归档内容仅保留追溯，不可重放（历史服务状态由 `docs/server_baseline_expected.json` 记录；回滚需参照 `docs/reports/P2_修复_完成报告_2026-08-22.md`）。

## 废弃（`_deprecated/`，禁止重放）

**2026-08-11 用户决策：砍掉 宝石/符文/打孔器/合成链/门控 五个系统**，槽位让给阶段 2 词缀。
`_deprecated/` 文件仅保留追溯；旧编号 013/014/015/016 与活动链无关。

| 文件 | 原系统 | 废弃原因 |
|---|---|---|
| `013_phase1_gems.sql` | 宝石 + 合成链 | 整体砍除 |
| `014_phase1_rune_punch.sql` | 符文 + 打孔器 | 整体砍除 |
| `015_phase1_punch_ddl.sql` | 打孔记录表 DDL（自 014 拆出） | 打孔器砍除（2026-08-22 从 git 历史 b34ef19 恢复） |
| `016_phase1_gate.sql` | 符文门控 | 钥匙/奖励均砍除 |
| `_backup_014_before_replay.sql` | 014 重放前备份 | 历史快照 |

## 用法

```bash
# 主服（001-017，库按表列）
MYSQL="<mariadb>/bin/mysql.exe"   # 或服务器端 mysql -uroot
"$MYSQL" -uroot -p tw_world < sql/local_changes/017_phase1_reforge.sql

# PB 实例迁移（018-023 已归档，此处为历史参考，不再执行）
# "$MYSQL" -uroot -p < sql/local_changes/023_irp_p2_dead_link_purge.sql  # 已归档，勿重放
```

生产应用用 `deploy/ssh_soulcore.py --mysql-all <file> [db]`（见 `docs/工作流SOP_2026-08-22.md`）。

## 部署路由（目标库自动解析）

- `--mysql-all <file>` 自动解析目标库：**文件内 `USE <db>;` → 文件头「目标库:」→ 默认 tw_world**（010 类纯登记文件会走默认并告警）。
- 「目标库」惯例：`001/010-017` 为**主服库族**名（tw_world / tw_logon）；PB 库族（tw_pb_world）迁移已归档。
- **禁止**把 `_deprecated/`（标注禁止重放）等废弃文件或已归档的 IRP 迁移灌入任何实例——按**完整文件名 + 文件头**定位，勿只看 `NNN_` 前缀。

## 执行顺序与可重复性（幂等语义）

- **唯真源承诺**：完整主服终态 = 按序重放 `001-017`；`018-023` 已归档（不可重放）。
- 建议在**测试库**先整链重放验证再上活。可用 `deploy/sync_server_baseline.py --check` 在活服**只读**校验终态是否与期望基线一致；`--store-expected` 在迁移落地后刷新期望值。

## 版本基线标签

- `master` 首个"已知良好"锚点：`v-baseline-2026-08-22`（扣住 001-017 + 现状文档；018-023 归档后于 2026-08-23 补充说明）。
- 以后每完成一个阶段打 `v-phaseN-YYYYMMDD`；日常追加迁移不污染标签。

## 规范

- 编号递增（`NNN_` 前缀），所有文件**幂等可重放**（DELETE+INSERT / ON DUPLICATE KEY UPDATE / UPDATE 兜底；详见上节）。
- 文件头注释写明：来源、原因、目标库、前置、状态。
- **新改动只追加、不回改旧迁移**；本地开发每次改动 = 一个新编号文件 → git 提交 → 应用到服务器。
