# dbc/random_enchant — 随机附魔 DBC 资产（版本化管理）

> 2026-08-22 整理：PB 服随机附魔（Orange 试点）相关 DBC 从此前 `outputs/` 归位。
> 与 `sql/local_changes/018-023`、`lua_scripts/enchant/random_enchant.lua` 配套。

## 文件清单

| 文件 | 用途 | 备注 |
|---|---|---|
| `SpellItemEnchantment.pb.dbc` | PB 服**当前部署**的 SpellItemEnchantment（橙装随机附魔 SIE，4603 行级） | 4.7MB，已上线 |
| `ItemRandomProperties.pb.dbc` | PB 服**当前部署**的 ItemRandomProperties（词缀容器，ench→IRP 段） | 133KB，已上线 |
| `ItemRandomProperties.baseline_20260821.dbc` | **P2 前** IRP 基线快照（2026-08-21 14:28 抓取） | 1.7MB，P2 改动回滚参考 |

## 关联关系（随机附魔机制）

```
item_enchantment_template.entry=52001 (权重池, 16716 条)
        └─ ench = ItemRandomProperties(IRP) 段 52001..69247
                └─ IRP.enchant_id[0] → SpellItemEnchantment(SIE) id (EQUIP_SPELL → Orange 法术)
                        └─ lua 层 random_enchant.lua 用 item:SetEnchantment(sie_id, 0)
```
- 权重池与赋池 = `sql/local_changes/018-023`
- 触发脚本 = `lua_scripts/enchant/random_enchant.lua`

## 未入库的配套（保留在 `_archive/random_enchant_migration_20260819/`，git 忽略）

- **生成工具链**：`gen_new_sie.py` / `gen_orange_sie.py` / `gen_final_clone_fixed.py` / `rebuild_sie_v2.py` / `deploy_*.py`
- **中间 DBC 变体**：`SIE_merged*.dbc`、`SpellItemEnchantment.live.dbc`
- **SOP**：`随机附魔移植工作流SOP.md`
- 这些是可再生成的中间产物；如需整体版本化工具链，可整体将该目录迁入 `dbc/random_enchant/toolchain/`（后续迭代）。

## 客户端侧

客户端 DBC 通过 `patch-A.mpq` 承载（10.5GB 客户端 `Data/` 内，不入库）。
客户端修改 DBC 后须删除 `WTF/`、`WDB/` 缓存；`/reload` 不更新 DBC。

## 校验

```bash
# 二进制完整性（若本机有 DBC 工具）
python dbc/random_enchant/tools 的读取器，或比对 `random_enchant_migration/deploy_final.py` 中部署 md5
```
> 服务器同步脚本 `deploy/sync_server_baseline.py` 可拉取活服 DBC 并与本目录 diff（待 python/SSH 环境）。