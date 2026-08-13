# PlayerBots 分支移植 · 阶段 C 报告（Eluna × PlayerBots 共存专项）

> 日期：2026-08-12 ｜ 分支：`feature/playerbots`（HEAD `9e87f0d`）
> 对照：`PlayerBots分支移植计划书.md` 阶段 C ｜ 结论：**阶段 C 静态门禁通过 ✅**（动态验证留待阶段 F 测试服）

---

## 〇、执行摘要

阶段 C 核心是计划风险 #1：**bot 会话是否会误触发 Eluna 玩家事件（OnLogin/OnChat）刷屏**。静态审查确认风险属实并已修复：bot 复用真实玩家 `HandlePlayerLogin` 路径，原 Eluna 钩子无 bot 守卫。已加 **13 处 `GetPlayerbotAI()` 守卫**（commit `9e87f0d`）。ScriptMgr.h 钩子共存无冲突。

---

## 一、C1 bot 会话不触发 Eluna 事件（✅ 已修复）

### 1.1 风险确认（实测代码路径）
- `src/modules/PlayerBots/playerbot/PlayerbotMgr.cpp:214`：`botSession->HandlePlayerLogin(lqh)` —— **bot 走与真实玩家完全相同的 `WorldSession::HandlePlayerLogin`**（注释明示 "the same path real players use"）。
- `CharacterHandler.cpp:1116`：`sTurtleLuaEngine.OnPlayerLogin(pCurrChar)` 钩子**无 bot 守卫** → 每个 bot 上线触发一次 Eluna OnLogin（欢迎/炉石/NPC 脚本刷屏）。
- `ChatHandler.cpp`：6 类 Eluna 玩家聊天事件钩子（OnPlayerChat/OnPlayerWhisper/OnPlayerGroupChat/OnPlayerGuildChat/OnPlayerChannelChat/OnAddonMessage，共 12 处调用）**均无 bot 守卫**；`PlayerbotAI.cpp` 确认 bot 会发聊天（"random bot speaks, chat CD"）→ 聊天事件同样刷屏。

### 1.2 修复（commit `9e87f0d`）
- 守卫谓语：`Player::GetPlayerbotAI()`（`Player.h:2384`，bot 角色带 `PlayerbotAI` 附件，真实玩家返回 null）。
- 改法：
  - `CharacterHandler.cpp:1116` 包 `if (!pCurrChar->GetPlayerbotAI())` 才调用 `OnPlayerLogin`。
  - `ChatHandler.cpp` 12 处聊天钩子条件前置 `!GetPlayer()->GetPlayerbotAI() && `（bot 短路跳过 Eluna 钩子、聊天照常）。
- 语义：bot 跳过 Eluna 玩家事件；**真实玩家行为零变化**。
- 校验：`git diff` 确认 13 处均为纯守卫追加，无其它改动；编译正确性待阶段 D 验证。

### 1.3 未覆盖项（留阶段 F 实测）
- `Chat.cpp:1755` `OnPlayerCommand`（bot 用 `.bot` 命令）未守卫——bot 极少发 GM 命令，且属命令处理非玩家事件，暂不处理；若 F 实测发现 `.bot` 触发 Lua 命令脚本刷屏再补。

## 二、C2 ScriptMgr.h 钩子共存（✅ 无冲突）

- `ScriptMgr.h` 全文**无** playerbot / LuaEngine / Eluna / Eluna 任何 token（grep 空）。
- Eluna 与 bot 均通过既有 `ALL_SESSION_SCRIPTS(this, OnLogin(pCurrChar))` 事件系统接入，不修改 `ScriptMgr.h` → 无重定义/签名冲突。
- Shyalya 对 `ScriptMgr.h` 有单侧改动（不在 31 冲突交集，自动合并干净），且不含 Eluna/bot 碰撞 token。
- `.reload eluna`（`Commands.cpp:260` → `sTurtleLuaEngine.Reload()`）仅重新注册 Lua 钩子、**不重触发玩家事件** → bot 在线时重装载设计安全；最终以 F 阶段 20-bot 实测复核。

---

## 三、阶段 C 门禁对照

| 验收项（计划） | 结果 |
|---|---|
| ScriptMgr.h 深度合并复查（无重定义/签名冲突） | ✅ 双方均经既有事件系统接入，无碰撞 |
| 事件隔离验证（bot 不触发 Eluna OnLogin/OnChat） | ✅ 风险确认并已加 13 处守卫（9e87f0d） |
| reload eluna 兼容（bot 在线不崩） | ✅ 设计安全（重注册非重触发），F 实测复核 |

**判定：阶段 C 静态门禁通过。动态验证（20-bot 冒烟：OnLogin 不刷屏 + Eluna 3 脚本功能正常）属阶段 F，需独立测试服。**

---

## 四、进入阶段 D 的前置说明（资源决策点）

阶段 D/E/F 需要**真实编译 + 测试服资源**，需用户拍板：
- **D 构建**：编译只能走 CI（本地无 VS）。需新增/改 `playerbots-branch-build.yml`（双平台，产物名加 `-pb` 后缀不覆盖主线）。触发 GitHub Actions 编译 `feature/playerbots`（`BUILD_PLAYERBOTS=ON` + `OFF` 双配置）。
- **E 数据库/配置**：优先复用 `E:\11111\Twow1181Bots` 的 3307 满配库（零成本）；独立测试 realm `SoulCore-Bots`（端口 8091/3725，realmflags=0）。
- **F 实测**：错峰起独立测试服进程，20→200→1000 bot 渐进，验证 Eluna 共存 + 无崩溃。

> 当前 `feature/playerbots` 本地提交：`8cb40a2`(merge) + `9e87f0d`(C 守卫)。尚未 push 到 origin（阶段 A 即定硬隔离，push 待 D 建 CI 时一并）。

---

_生成方式：静态代码审查 + 13 处守卫补丁提交；未做编译/运行时验证（属 D/F）。_
