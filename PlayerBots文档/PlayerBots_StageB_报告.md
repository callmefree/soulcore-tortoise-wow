# PlayerBots 分支移植 · 阶段 B 报告（代码合并）

> 日期：2026-08-12 ｜ 分支：`feature/playerbots`（HEAD `8cb40a2`，基于 main `d428056`）
> 对照：`PlayerBots分支移植计划书.md` 阶段 B ｜ 上游源 Shyalya `playerbots-integration-gh` (`172ee94`)
> 结论：**阶段 B 门禁通过 ✅**（代码合并完成，Eluna 保全，无合并遗留半成品）

---

## 〇、执行摘要

在 `feature/playerbots` 上正式 `git merge --no-ff shyalya/playerbots-integration-gh`，3 处文本冲突（GuildBank.cpp / CharacterHandler.cpp / Creature.h）全部按"保留双方"解决并提交。合并后相对 main 共 **1167 文件改动 / +848376 / -1818**（Shyalya 集成 + Penqle petbot stub 删除）。

逐文件复核"我方与 Shyalya 都改过"的 **31 文件交集**，确认 Eluna 引擎完整保留、无语义破绽、petbot 旧骨架彻底清除、BUILD_PLAYERBOTS=OFF 双配置编译路径已具备（阶段 D 去风险）。

---

## 一、B1 正式合并 + 解冲突（✅）

- 合并提交：`8cb40a2` Merge Shyalya/tortoise-wow playerbots-integration-gh
- 3 处冲突解法（awk 去标记、保留 ours+theirs 两段追加）：
  1. **GuildBank.cpp** — 我方 `sTurtleLuaEngine.OnGuildMoneyDeposit` (USE_LUA 包裹) + Shyalya `if (money > max - b_money)` 溢出保护 → 两全
  2. **CharacterHandler.cpp** — 我方 `OnPlayerLogin(pCurrChar)` Eluna 钩子 + Shyalya `RefreshVisiblePlayersEvent` 首登装备刷新 → 两全
  3. **Creature.h** — 我方 Lua 访问器 (`GetLuaLootMode` 等) + Shyalya cmangos 兼容 shim (`IsCritter`/`GetDbGuid`/`GetCombatManager` stub 等) → 两全
- 校验：全仓 `<<<<<<<` 残留 = 0；3 文件双方关键 token 均在；`git commit --no-edit` 成功

## 二、B2 模块层完整性（✅）

- `src/modules/PlayerBots/` = **1017 文件**（计划预估 ~1017，精确吻合）
- 结构：CMakeLists / README / ahbot / botpch.cpp/.h / cmangos-compat-shim.h / cmangos-compat-stubs / playerbot / sql
- 源码：457 .cpp + 528 .h；SQL 资产 20 文件（world/characters/other）
- 根 `CMakeLists.txt:54` `option(BUILD_PLAYERBOTS ... OFF)`；`:631-632` 条件挂载模块
- 相对 main 总改动 1167 文件（= 干跑 Shyalya 侧改动数，一致）

## 三、B3 逐文件复核（✅）

- **审查集**：`comm -12` 取 base→main 与 base→Shyalya 的交集 = **31 文件**（计划估 32，差 1 因 ScriptMgr.h 实际仅单侧改动、不在交集）
  - 其中 3 个文本冲突（已解），28 个 git 自动合并（需查语义）
- **Eluna 保全校验**：
  - `sTurtleLuaEngine` 全仓 44 文件 / 598 行；关键钩子 `OnGuildMoneyDeposit`(GuildBank.cpp)、`OnPlayerLogin`(CharacterHandler.cpp) 均存活于合并后宿主文件
  - 3-way merge 非重叠追加必保留 → Eluna 改动无一条被吞
- **BUILD_PLAYERBOTS 守卫（阶段 D 去风险）**：
  - `src/game/CMakeLists.txt:613-617`：`BUILD_PLAYERBOTS=OFF` 自动追加 `PlayerbotStubs.cpp` 占位；ON 接 `playerbots.lib` 真实现（计划"开关可逆不破构建"已落地）
  - 宿主引用 `sPlayerbotMgr` 文件数 = 0 → bot 调用未硬编码进宿主，OFF 版不会链接失败
  - 5 个宿主文件含 `BUILD_PLAYERBOTS` 守卫（CMakeLists/MovementHandler/Player.cpp/.h/PlayerbotStubs.cpp）
- **petbot 残留**：旧骨架 `PlayerBotAI.*`/`PlayerBotMgr.*`（大写 B）全仓 0 文件、0 活代码引用（仅 8 处注释描述"Penqle stub binned"）

## 四、B4 参照端修复（✅ 已自带，无需改）

- 计划称要采用 `Twow1181Bots/PlayerbotAIConfig.cpp` 的 `OpenLogFile` fopen 判空补丁
- 实测：Shyalya 代码 `PlayerbotAIConfig.cpp:1113-1122` **已含 `if(!file)` 判空**，且比参照端更完善（额外 `sLog.outError(... strerror(errno))` 报错 + 注释说明"启动期首 bot 事件空指针崩溃"）
- 结论：Shyalya 在 1000-bot 实测已踩坑自修，本步跳过

## 五、B5 清理与保全（✅）

- petbot 旧骨架文件残留 = 0（彻底清除）
- Eluna 钩子最终确认：`OnGuildMoneyDeposit`/`OnPlayerLogin` 均在
- 合并遗留半成品扫描：
  - TODO/FIXME：命中均为**上游既有合法注释**（"TODO this can be done when poolsystem works" 等），非合并引入
  - `#if 0`：Player.cpp 有 2 处，但 `main` 基线本就存在 → 上游既有禁用块，非合并遗留
- 工作树干净：`git status --short` = 0 行

---

## 六、阶段 B 门禁对照

| 验收项（计划） | 结果 |
|---|---|
| 全量 diff --stat 与 Shyalya 基线一致（模块层无遗漏） | ✅ 1017 文件 / +848376 / -1818 |
| Eluna 侧改动全部保留（diff 对照） | ✅ 44 文件/598 行，关键钩子存活 |
| 不允许未决 TODO/注释掉的代码 | ✅ 无合并引入项（既有 TODO/#if0 属上游） |

**判定：阶段 B 通过，可进入阶段 C（Eluna × PlayerBots 共存专项）。**

---

## 七、进入阶段 C 的前置说明

阶段 C/D/F 的**完整验证需要真实编译 + 测试服**：
- 编译只能走 CI（本地无 VS）→ 需触发 `playerbots-branch-build.yml`（阶段 D，双平台，产物加 `-pb` 后缀）
- 运行时验证需独立测试服（端口 8091/3725、库 3307 满配参照库）→ 阶段 E/F，需与主线错峰

阶段 C 的**静态部分可现在做**（读 PlayerbotAI 会话代码确认 bot 会话不触发 Eluna OnLogin/OnChat；ScriptMgr.h 钩子共存复查；reload eluna 兼容），无需编译。

---

_生成方式：正式 merge 提交 + 结构校验（grep/diff/comm），未做编译与运行时验证（属 D/F）。_
