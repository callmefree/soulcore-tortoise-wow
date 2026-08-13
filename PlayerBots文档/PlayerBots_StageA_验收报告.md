# PlayerBots 分支移植 · 阶段 A 验收报告

> 日期：2026-08-12 ｜ 仓库：`E:\11111\soulcore-playerbots`（callmefree/soulcore-tortoise-wow 克隆）
> 对照计划书：`PlayerBots分支移植计划书.md`（2026-08-10）
> 结论：**阶段 A 门禁通过 ✅**

---

## 〇、执行摘要

计划书预估"32 文件 / ~200 冲突块"，实际 3-way merge 干跑结果：**仅 3 文件、3 个冲突块**，且全部为"同函数/同类内相邻不重叠追加"，可两全保留。合并工作量比预估低一个数量级，阶段 B 风险显著下降。

---

## 一、A1 克隆（✅ 完成）

- 源：`https://github.com/callmefree/soulcore-tortoise-wow.git`
- 目标：`E:\11111\soulcore-playerbots`
- 结果：10388 对象 / 269.24 MiB / 3371 文件，clone 成功
- 当前分支：`main`（HEAD `d428056`）

## 二、A2 双 remote（✅ 完成）

| remote | URL | 已 fetch 分支 | ref |
|---|---|---|---|
| `origin` | callmefree/soulcore-tortoise-wow | main 等 | `d428056` |
| `shyalya` | https://github.com/Shyalya/tortoise-wow | `playerbots-integration-gh` | `172ee94` |
| `upstream` | https://github.com/Penqle/tortoise-wow | `main` | `937d664` |

> 注：初次 `git fetch` 两次均遇 Windows schannel TLS 握手失败（瞬时抖动），重试后成功。后续 fetch 正常。

## 三、A3 同步上游 main（✅ 无需操作，已最新）

计划称"落后上游 23 commits"，实测相反：

- `main` 领先 `upstream/main`：**21 commits**（Eluna 工作）
- `main` 落后 `upstream/main`：**0 commits**
- `merge-base(main, upstream/main) = 937d664 = upstream/main` → upstream 已完全并入 main
- `git merge-tree --write-tree main upstream/main`：产出单一 tree，零冲突标记

**结论**：主线早已领先上游 23+（实际 21）个 Eluna 提交，无需再建 `chore/sync-upstream`（建了也等于 main，徒增历史噪音），直接以 main 为基进阶段 B。

## 四、A4 分叉 feature/playerbots（✅ 完成）

- 从 `main`（`d428056`）分出 `feature/playerbots`
- 当前分支：`feature/playerbots`，HEAD `d428056`
- 符合硬隔离红线：独立分支，未动 main

## 五、A5 merge-tree 干跑（✅ 完成，核心证据）

方法：`git merge --no-ff --no-commit shyalya/playerbots-integration-gh` → 统计 `<<<<<<<` 标记 → `git merge --abort` 回滚（纯干跑，未落提交）。

- 三方共同基 `merge-base = 937d664`（= upstream/main）——证明我方 Eluna fork 与 Shyalya bot 分支**同源**，Eluna 改动即相对该基的 70 文件 diff
- 我方侧相对 base 改动：**70 文件**（Eluna 工作）
- Shyalya 侧相对 base 改动：**1167 文件**（bot 集成，含 `src/modules/PlayerBots/` 约 1017 新文件 + 宿主 ~150 文件）
- 自动合并消化了其余所有文件，**仅 3 文件留文本冲突，共 3 个冲突块**

### 5.1 冲突文件清单（实测）

| # | 文件 | 冲突块 | 性质 | 预估计划位置 |
|---|---|---|---|---|
| 1 | `src/game/GuildBank/GuildBank.cpp` | 1 | 相邻不重叠：我方 Eluna 钩子 vs Shyalya 溢出保护 | 在 32 清单内 |
| 2 | `src/game/Handlers/CharacterHandler.cpp` | 1 | 相邻不重叠：我方 `OnPlayerLogin` vs Shyalya 首登装备刷新 | 在 32 清单内 |
| 3 | `src/game/Objects/Creature.h` | 1 | 相邻不重叠：我方 Lua 方法 vs Shyalya cmangos 兼容 shim | 在 32 清单内 |

### 5.2 三处冲突定性（均可"保留双方"解决）

1. **GuildBank.cpp** — 我方 `#ifdef USE_LUA` 包裹的 `sTurtleLuaEngine.OnGuildMoneyDeposit(...)`；Shyalya 加 `if (money > max - b_money)` 溢出保护。两者互不覆盖，合并后逻辑：先 Eluna 钩子、再溢出校验。
2. **CharacterHandler.cpp** — 我方 `sTurtleLuaEngine.OnPlayerLogin(pCurrChar)`；Shyalya 加 `RefreshVisiblePlayersEvent`（仅首登播片时刷新附近 bot 装备，防裸模闪烁）。两者独立，并存。
3. **Creature.h** — 我方加 `GetLuaLootMode/SetLuaUnitFlagsTwo` 等 Lua 访问器；Shyalya 加 `IsCritter/GetDbGuid/ReduceCorpseDecayTimer/isTrainer/GetInteractionPauseTimer/isGossip/GetCombatManager` 等 cmangos 兼容 shim（含 `CombatManagerStub`）。两组为类内不同成员，无符号冲突。

---

## 六、与计划预估偏差说明

| 维度 | 计划预估（2026-08-10） | 实测（2026-08-12） | 偏差原因 |
|---|---|---|---|
| 上游落后 | 23 commits | 0（已领先 21） | 期间主线已并入上游 |
| 文本冲突文件 | 32 | 3 | 3-way merge 自动消化 29 个非重叠文件 |
| 文本冲突块 | ~200 | 3 | 同上 |

> ⚠️ **注意**：文本冲突仅 3 块 ≠ 阶段 B 无工作量。Shyalya 侧 1167 文件与我方 70 文件在 32 个文件级有交集，其中 29 个被 git 自动合并——这些"自动合并"可能存在**语义冲突**（编译错误或运行时逻辑错，计划风险 #2）。阶段 B 仍需逐文件对照双方 diff 复核，尤其 10 个深度文件（ScriptMgr.h / Player.cpp/.h / World.cpp / Unit.cpp / ObjectMgr / Spell.cpp / Chat.cpp / WorldSession.cpp / Map.cpp/.h）。

---

## 七、阶段 A 门禁结论

| 验收项 | 结果 |
|---|---|
| `feature/playerbots` 分支清晰、基于同步后 main | ✅ |
| 双 remote 可 fetch（shyalya + upstream） | ✅ |
| merge-tree dry-run 冲突报告已出 | ✅（3 文件 / 3 块，远低于预估） |

**判定：阶段 A 通过，可进入阶段 B（代码合并）。**

---

## 八、阶段 B 建议起点

1. 在 `feature/playerbots` 上正式 `git merge shyalya/playerbots-integration-gh`（产生 merge commit，非 fast-forward），按本报告 5.2 三处保留双方；
2. 模块层 `src/modules/PlayerBots/` 1017 文件随合并自动落入，验证存在性；
3. 按"先易后难"复核 29 个自动合并文件，重点 10 个深度文件对照 diff；
4. 直接采用 `E:\11111\Twow1181Bots\server\PlayerbotAIConfig.cpp` 修补版（fopen 判空）；
5. 处理 petbot 骨架删除（Shyalya 整体方案）。

---

_生成方式：真合并 --no-commit 统计后 --abort，未向任何分支写入合并结果。_
