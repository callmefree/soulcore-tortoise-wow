# Orange 全量 IRP 导入 — 实施方案草案（原生 DBC 链路）

> 决策：抛弃 `random_enchant.lua` 旧 PERM 叠加体系，全面切原生 `ItemRandomProperties + item_enchantment_template`。  
> 口径：精炼池 `trial_orange_enchants_refined.csv` 18674 条（sie 90011-114075，实际服务端已含 23316 条 90001-114075，故 SIE 无需新增），全量导入指把这 18674 条按品质映射为 IRP 池，赋给绿/蓝/紫装。  
> 状态：旧 Lua 已确认无活跃文件（`random_enchant.lua` 不存在，仅剩 `.disabled/.bak`），`pbmangosd active`，P1 测试池 `50001→51001-51003` 已可用。

---

## 1. 现状盘点（为什么全量比你想象的省事）

| 层 | 数量 | 结论 |
|---|---|---|
| 服务端 SIE | rc 21182（本机 live 24915，含 Orange 23316） | ✅ 18674 精炼 SIE 已在 DBC，无需追加 SIE |
| 服务端 IRP | rc 2016（2013 + 5100x 3） | 需追加新 IRP 池 |
| 权重表 | entry 50001 已改为 51001-51003 三选一 | 需重建为 52001/53001/54001 |
| 客户端 patch-A | 2.31 MB，双 DBC 同源 | 推送后需同步重压 |
| 旧 Lua | 无活跃 `random_enchant.lua` | ✅ 已隔离，后续无需 `.reload eluna` |

> 启发：既然 SIE 已在，你猜这次“全量导入”最重的活是什么？—— 不是 SIE，而是 **如何把 18674 条 SIE 合理分进 IRP 池**（池粒度决定随机体验与表行数）。

---

## 2. 方案分型（你选哪个分法，我就按哪个落 DBC）

### 方案 A — 极简 3 池（推荐 P2 验证）

- 52001 = 绿装池
- 53001 = 蓝装池
- 54001 = 紫装池
- 每池内等权，18674 ÷3 ≈ 6224 条 `item_enchantment_template` 行/池
- 优点：实现最快、回滚一行 `DELETE WHERE entry IN (52001,53001,54001)`、验证链路最纯粹

### 方案 B — 6 池（绿/蓝/紫 × 武器/护甲）

- 52001 绿武器、52002 绿护甲、53001 蓝武器… 共 6 池，每池 ~3112 行
- 优点：武器触发 vs 护甲被动可分开调（复用你之前的 WEAPON/ARMOR 分池思想），更贴近 Orange 原意

### 方案 C — 抽样 3 池（每池 100-200 条代表）

- 每池随机抽 100 条精炼 SIE，权重表仅 300 行
- 优点：表最小、验证最快，后续再全量扩

> 三个方案在 DBC 侧都只需追加 IRP（3 或 6 条记录），区别只在权重表行数。你倾向哪种“先跑通再扩量”的节奏？

---

## 3. 四步实施（复用你已跑通的工具链）

1. **追加 IRP**：`dbc_append.py` 向 `ItemRandomProperties.dbc` 追加 3（或 6）条 IRP，每条 `ench[0]=SIE` 单后缀（之耐力/之熊/之充实 占位，后续批量改名）
   - ID 段：52001 绿 / 53001 蓝 / 54001 紫（空档，服务端 IRP 当前 max 2164，50001 段已用，52001 起安全）
   - string 字段 `[1,7..14]`，`7=en 11=zh`，其余语言空
2. **重建权重**：`DELETE+INSERT item_enchantment_template`，每池等权 `chance=100/N`，`SUM≈100`
3. **赋池**：`UPDATE item_template SET random_property=52001 WHERE quality=2 AND class IN (2,4) ...`（绿）；53001 蓝；54001 紫。先小批量 100-200 件验证，再全量
4. **双重启**：`systemctl restart pbmangosd` + 重压 `patch-A.mpq`（双 DBC 同源）+ 客户端重开

---

## 4. 需要你拍板的 5 个点（直接选即可）

1. **池粒度**：A 3池 / B 6池 / C 抽样？（你已选 绿/蓝/紫，我默认 A 3池，若要 B 武器/护甲分开请说）
2. **SIE 分配**：18674 全分（每池 6224）还是每池抽 100 代表先验证？（全分最全但权重表 18k 行）
3. **后缀命名**：继续用“之耐力/之熊/之充实”占位并复用 en_name，还是批量取 `en_name/zh_name` 自动生成（如“之庇护”“之充实”）？
4. **赋池范围**：`quality 2→52001, 3→53001, 4→54001` 且 `class 2/4` 是否准确？是否按 `required_level` 再分层（如 1-30/31-60）？
5. **P1 测试池 50001**：保留作回归对照，还是 `DELETE WHERE entry=50001` 清理并把 25/35/85 改回 52001？

> 选完我立即生成：`p2_irp_52001_54001.json` + `p2_weight_52001_54001.sql` + `p2_assign.sql`，走 `dry-run → 推送 → 重启 → 重压`，全程同 P1 流程。

---

## 5. 回滚与风险

- **回滚**：`DELETE FROM item_enchantment_template WHERE entry IN (52001,53001,54001); UPDATE item_template SET random_property=0 WHERE random_property IN (52001,53001,54001);` + 还原 `*.bak.20260821*` + `restart` + 还原 `patch-A.bak`
- **风险**：权重表 18k 行对 MaNGOS 无压力（基线已有 5k+），但首次赋池全量 `UPDATE` 建议分批 `LIMIT 500` 避免长事务
- **验证**：每品质刷 20 件，统计后缀分布与 `randomPropertyId` 落库（`item_instance`），确认无白板

---

## 6. 下一步

你拍板 5 点后，我 10 分钟内完成推送并给出刷装验证清单。
