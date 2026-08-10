# Eluna 移植完整计划书（Soulcore Turtle WoW 私服）

> 更新：2026-08-09 16:15 ｜ 状态：**✅ 编译通过 + 部署通过 + 阶段二批次 1-3 运行时验证全部闭环（.reload eluna / 登录欢迎 / 炉石 / NPC gossip 全链路实测）**
> 参考文档：`部署与Eluna移植工作记录.md`（部署链路）；本文件为 Eluna 移植的正式计划与进度追踪。

---

## 一、目标

在 tortoise-wow（Penqle 上游，MaNGOS 系 1.12 Turtle WoW 服务端）上集成 Eluna Lua 引擎，使服务端支持 Lua 脚本（自定义 NPC/任务/事件/GM 命令/热重载），不改 C++ 即可加内容。

## 二、方案决策（已定）

| 决策点 | 结论 | 理由 |
|---|---|---|
| 移植基线 | **WYTurtle（gitee brison/tw171_Eluna）的 TurtleLuaEngine** | 同上游 tortoise 的现成移植，2.5 万行 Eluna 兼容层，Player/Creature 方法覆盖 missing=0，含大量 Turtle 1.12 适配；比官方 Eluna（ElunaLuaEngine/Eluna）少大量适配工作 |
| Lua 版本 | **Lua 5.2.4**（Rochet2 lualib CMake，FetchContent 下载，LUA_STATIC=ON） | 引擎为 5.2 编写；静态链接避免 DLL 分发问题 |
| 编译链路 | GitHub Actions CI（本地无 VS） | 复用现有 weekly-build.yml，Linux 加 libreadline-dev |
| 还原原则 | 所有移植只做"新增"，不改 tortoise 现有逻辑 | 避免引入 WYTurtle 旧版行为 |
| 迭代方式 | 纯 CI 迭代（用户已确认） | 每轮 40-60 分钟 |

## 三、已完成（commit 历史）

| Commit | 内容 | 状态 |
|---|---|---|
| b0455bf | 引擎源码 + dep/lualib + CMake(USE_LUA) + 配置项 + 216 个事件 hook（41 文件）+ 误删修复 + ScriptMgr.h Item 版声明 | ✅ 推送（首轮编译失败，暴露下述缺失） |
| a32cb51 | CMake 补 LuaEngine include 路径；移植核心类方法：Creature.h(11 方法+3 成员)、GameObject.h(2)、Channel.h/cpp(7 public Lua 包装)、Player.h(GetTalentResetCost 包装)、GmTicket(GetResponse)、DBCStore.h(SetEntry)、ObjectMgr(AddTaxiNodeEntry)、恢复 sItemDisplayInfoStore(4 文件) | ✅ 推送（编译推进到 PCH 阶段，仅剩 ScriptMgr.h ItemPrototype 错误） |
| c7b8f58 | ScriptMgr.h 补 OnItemExpire/OnItemRemove 声明 | ✅ 推送 |
| f506c4e | ScriptMgr.h 补 `struct ItemPrototype;` 前置声明 | ✅ 推送（第三轮编译中，子进程分析发现 4 个新错误） |
| 6bd35e1 | **子进程分析发现的 4 个必挂错误**：Player.h 三方法（ModifyMoney/SetMoney/SetFreeTalentPoints）内联体→纯声明（cpp 外联实现含 Lua hook 已存在，修 C2084 重定义）；ScriptMgr.h 补 OnEffectDummy(Item*) 声明（实现已在 ScriptMgr.cpp:2215） | ✅ 推送 |
| 79bb003 | **第三轮 Windows 完整日志 24 错误**：补 9 处 hook 依赖的 WYTurtle 局部变量声明（Group oldLeaderGuid/AHHandler pItem/GO wasInWorld+spawned/Pet wasInWorld/QuestHandler quest/Unit pPetKillOwner+wasInCombat）+ AsyncMailSendRequest mailboxGuid 成员 + Map 基类 public GetObjectLock/GetObjectStore | ✅ **双平台编译通过（run #31081247956）** |
| 35e439d | **阶段二批次 2**：`.reload eluna` 命令、施法动画修复（SpellHandler:174 补 SPELL_FAILED_INTERRUPTED）、`Eluna.TopLevelScriptPath`、6 文件 USE_LUA 保护、Spell.cpp `<memory>`、lua_scripts 入库 | ✅ **CI #19 双平台通过 + 已部署（mangosd 29bfdec6）** |
| b10cbbb | **阶段二批次 3 运行时修复**：test_gossip.lua 两处 bug（GossipHello 开头补 `GossipClearMenu()` 防菜单叠加；`GossipMenuAddItem` 改用 **sender=0 + action=编号** 约定，原 1/2 误放 sender 导致选项无响应） | ✅ 已推送 |

### 事件 hook 覆盖（~200 处）
Player(36)/Unit(19)/ScriptMgr(19)/ChatHandler(16)/Creature(10)/Map(10)/GuildBank(10)/Group(9)/Guild(8)/SpellEffects(8)/Spell(7)/GameObject(7)/World(7)/BattleGround(5)/CharacterHandler(5)…及 Handlers/Movement/Weather/Reputation 等。

## 四、待办（按优先级）

### P0 编译通过（✅ 已完成 2026-08-09，双平台闭环）
- [x] 第一轮错误修复（CMake include + 27 个 C2039）
- [x] ScriptMgr.h ItemPrototype 前置声明
- [x] 子进程（general-purpose 分析）发现的 4 个错误：Player.h 三方法重定义 + ScriptMgr OnEffectDummy(Item*) 声明（6bd35e1）
- [x] 第四轮 CI 结果（6bd35e1）——后经 79bb003 双平台编译通过，本项已随其后所有轮次关闭
- [x] 双平台（Linux/Windows）编译通过 + 产物下载（79bb003 → 35e439d CI #19，均已部署验证）

### P1 本地部署验证（✅ 已完成，G2 运行时门禁 2026-08-09 通过）
- [x] 备份 `server/bin` → `server/bin_backup_pre_eluna`
- [x] 替换 bin（mangosd/realmd/ACE.dll 来自 79bb003 产物；libmysql/libssl/libcrypto 沿用）
- [x] mangosd.conf 追加 `Eluna.Enabled = 1`、`Eluna.ScriptPath = "lua_scripts"`
- [x] 启动验证：realmd(3724) + mangosd(8090) 监听；日志 **"Loading Lua engine..."** + **"[Lua] Loaded 3 Lua scripts from 'lua_scripts'."** + "World server is up and running!"（43s）
- [x] **玩家登录验证**（2026-08-09，free 角色实测）：登录欢迎 ✅、`elunatest` 聊天命令 + 炉石 6948 入包 ✅、auditerr 错误隔离不崩 ✅、.level 触发 OnLevelChange ✅、登出再登稳定性 ✅（详见工作记录）
- [x] **超级炉石脚本**（2026-08-09）：`super_hearthstone.lua` 已部署，右键炉石弹传送菜单；修复本引擎布尔语义反向导致的施法未阻止 bug（item use handler 需 `return false`）

### 第二阶段批次 1-3（✅ 已全部完成，运行时验证闭环 2026-08-09 16:04）
- [x] 批次1 本地修复：welcome 事件 1→14、gossip API 修复、**NPC 190001 入库**（暴风城）、conf 模板统一（Eluna 0→4）、清理 _audit_engine.lua
- [x] 批次2 C++：**`.reload eluna` 命令**、**施法动画修复**（SPELL_FAILED_INTERRUPTED）、**`Eluna.TopLevelScriptPath`**、6 文件 USE_LUA 保护、Spell.cpp `<memory>`、lua_scripts 入库
- [x] 批次3 部署：CI #19 双平台通过 → 新二进制部署（mangosd 29bfdec6）+ 备份 bin_backup_pre_phase2 + etc 模板更新
- [x] **重启后验证（15:31 新二进制启动 + 客户端实测，全部通过）**：`.reload eluna` ✅ / 炉石无施法事实 ✅ / Eluna Test NPC gossip（打开+防叠加+选项分发）✅ / 登录欢迎 ✅ / 启动事件14 `[Eluna] Server started` ✅
- [x] **运行时修复 3 项（均无需重编译）**：① admin rank 3→4（SEC_ADMINISTRATOR，否则 `.reload eluna` 报"无法使用此命令"）；② NPC 190001 `npc_flags` 0→1（复制模板丢 GOSSIP 位，否则客户端右键不发 gossip）；③ test_gossip.lua 两处脚本 bug（GossipClearMenu 防叠加 + sender/action 参数约定），commit `b10cbbb` 已推
- [x] ~~workflow 产物补全推送~~（**已关闭**：用户 2026-08-09 决定不再推送，lua_scripts 打包 + copy_runtime_dlls.ps1 改动**仅保留本地**；CI 产物不含 lua_scripts/DLL，本地部署手动补是常态流程，根目录 `weekly-build.yml` 为含补全的最新副本）

### P2 增强（可选）
- [x] **reload eluna 命令**（已实现：Chat.cpp 命令表 + sTurtleLuaEngine.Reload()）
- [x] 6 文件 `#ifdef USE_LUA` 保护（USE_LUA=OFF 兼容）
- [ ] 测试更多事件（任务完成、拾取、击杀）与 Eluna 标准 API 兼容性

## 五、风险与已知问题

| 风险 | 等级 | 说明/对策 |
|---|---|---|
| TurtleLuaEngine.cpp 深层 API 签名不匹配 | P1 | 每轮 CI 暴露一批，已修复两批；子进程全面分析（Explore agent）核对中 |
| Lua 5.2.4 FetchContent 下载（lua.org） | P2 | 前两轮均成功下载；若失效可 vendor 源码 |
| Anticheat 对 Lua 操作告警 | P2 | 可接受，观察日志 |
| PCH + 大文件编译 | P2 | USE_PCH=ON 已通过两轮 |
| 引擎单文件 2.5 万行维护性 | P3 | 未来可拆分，不影响功能 |

## 六、验证标准（完成定义）

1. ✅ Linux + Windows 双平台 CI 编译通过（#19, 35e439d）
2. ✅ 本机服务端启动无 Lua 相关错误
3. ✅ welcome.lua 登录欢迎 + 启动事件14 生效（2026-08-09 实测）
4. ✅ NPC gossip 菜单生效（打开 / 防叠加 / "查看我的信息"与"给我一个炉石"选项分发，2026-08-09 实测）
5. ✅ `.reload eluna` 热重载（实测通过，不重复注册事件；需 rank4）
6. ✅ 超级炉石传送菜单生效（施法事实已阻止；抬手为客户端本地动画，可接受）
7. ⏸ G3 核心游戏回归（用户暂缓，上线后测）

---

_维护：每次 CI 轮次、每次部署操作后更新本节进度。_
