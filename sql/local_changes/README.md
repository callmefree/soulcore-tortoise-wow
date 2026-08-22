# sql/local_changes — 私有增量 SQL 迁移链（版本化真源）

> **用途**：本目录是唯一真源，按序（001→023）重放即可复现活服务器内容终态。
> 2026-08-22 整理：历史资产从 `_archive/` 归位，P1/P2 随机附魔 SQL 从 `outputs/` 编入 018-023。
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
| 018 | `018_irp_p1_pool_50001.sql` | tw_pb_world | P1-A 绿装随机词缀池 entry=50001（30001/754/115000 三选一） | ✅ 2026-08-21 |
| 019 | `019_irp_p2_pool_assign_52001.sql` | tw_pb_world | P2 橙装池 52001 克隆(17249) + 绿装赋池 | ✅ 2026-08-21 |
| 020 | `020_irp_p2_aura_container_fix.sql` | tw_pb_world | learn 词缀 光环化 1261 + 容器化 1162 + proc_event | ✅ 08-21/22 |
| 021 | `021_irp_p2_rc_trigger_fix.sql` | tw_pb_world | [RC] trigger DUMMY→X 609 条（对 517 条无效，见 023） | ⚠️ 已应用 |
| 022 | `022_irp_p2_weight_rebuild.sql` | tw_pb_world | 权重表重建 17249→17233（剔 X 缺失 16） | ✅ 08-22 |
| 023 | `023_irp_p2_dead_link_purge.sql` | tw_pb_world | 死链剔除 517 条 + 归一化 → 16716 终态 | ✅ 08-22 |

> **终态校验**（`docs/服务器现状_2026-08-22.md` 引用 P2 完成报告）：
> 52001 池 16716 条全有效、权重 SUM=99.999999、learn 残留 16（池内无引用）、spell_proc_event 15793、启动日志 IRP/SIE 错误 0。

## 废弃（`_deprecated/`，禁止重放）

**2026-08-11 用户决策：砍掉 宝石/符文/打孔器/合成链/门控 五个系统**，槽位让给阶段 2 词缀。
`_deprecated/` 文件仅保留追溯；旧编号 013/014/015/016/018 与活动链无关。

| 文件 | 原系统 | 废弃原因 |
|---|---|---|
| `013_phase1_gems.sql` | 宝石 + 合成链 | 整体砍除 |
| `014_phase1_rune_punch.sql` | 符文 + 打孔器 | 整体砍除 |
| `015_phase1_punch_ddl.sql` | 打孔记录表 DDL（自 014 拆出） | 打孔器砍除（2026-08-22 从 git 历史 b34ef19 恢复） |
| `016_phase1_gate.sql` | 符文门控 | 钥匙/奖励均砍除 |
| `018_phase1_sockets_ddl.sql` | sockets 表 DDL | 打孔器砍除 |
| `_backup_014_before_replay.sql` | 014 重放前备份 | 历史快照 |

## 用法

```bash
# 原实例（001-017，库按表列）
MYSQL="<mariadb>/bin/mysql.exe"   # 或服务器端 mysql -uroot
"$MYSQL" -uroot -p tw_world < sql/local_changes/017_phase1_reforge.sql

# PB 实例（018-023：文件内含 USE tw_pb_world;，默认库任意）
"$MYSQL" -uroot -p < sql/local_changes/023_irp_p2_dead_link_purge.sql
```

生产应用用 `deploy/ssh_soulcore.py --mysql-all <file> [db]`（见 `docs/工作流SOP_2026-08-22.md`）。

## 部署路由（目标库自动解析）

- `--mysql-all <file>` 自动解析目标库：**文件内 `USE <db>;` → 文件头「目标库:」→ 默认 tw_world**（010 类纯登记文件会走默认并告警）。
- 「目标库」惯例：`001/010-017` 为**主服库族**名（tw_world / tw_logon，历史应用对象）；`018-023` 为 **PB 库族**（tw_pb_world）。**部署到 PB 实例时，非 PB 头的文件需显式传库**：`--mysql-all 017_phase1_reforge.sql tw_pb_world`。
- **禁止**把 `_deprecated/`（标注禁止重放）或 `018_phase1_sockets_ddl.sql` 等废弃文件灌入任何实例——按**完整文件名 + 文件头**定位，勿只看 `NNN_` 前缀。

## 执行顺序与可重复性（幂等语义）

- **唯真源承诺**：完整终态 = 按序重放 `001-023`；**pre-P2 回滚** = 只重放 `001-017`（不建 IRP 池）。
- 幂等说明：`018/019/022` = DELETE+INSERT 重建（重放结果恒定）；`020/021` = UPDATE / ON DUPLICATE KEY 值覆盖（重放同值）；`023` = DELETE 指定 ench 段 + UPDATE chance（对已删行无害、同值）。**但** 022/023 建立在 019 建池之上——中途跳过会产生中间状态，务必按序整链重放。
- 建议在**测试库**先整链重放验证再上活（尤其 022/023 含 DDL/DELETE）。可用 `deploy/sync_server_baseline.py --check` 在活服**只读**校验终态是否与期望基线一致；`--store-expected` 在迁移落地后刷新期望值。

## 版本基线标签

- `master` 首个"已知良好"锚点：`v-baseline-2026-08-22`（扣住上述 001-023 与现状文档）。
- 以后每完成一个阶段打 `v-phaseN-YYYYMMDD`；日常追加迁移不污染标签。

## 规范

- 编号递增（`NNN_` 前缀），所有文件**幂等可重放**（DELETE+INSERT / ON DUPLICATE KEY UPDATE / UPDATE 兜底；详见上节）。
- 文件头注释写明：来源、原因、目标库、前置、状态。
- **新改动只追加、不回改旧迁移**；本地开发每次改动 = 一个新编号文件 → git 提交 → 应用到服务器。