# Eluna 第一阶段移植审查报告

> ⚠️ **本报告已作废（历史参考）**：已被 `Eluna_第一阶段审计与验证报告.md`（2026-08-09）取代。
> 本报告中标「待人工」的运行时功能项（G2 登录/聊天/错误隔离）已于 2026-08-09 客户端实测**全部闭环**
> （详见 `部署与Eluna移植工作记录.md` 第六节）；本报告结论以旧基线（79bb003）为准，不再作为当前状态依据。

> 审查对象：Turtle WoW 私服 Eluna Lua 引擎移植**第一阶段**（P0 编译通过 + P1 本地部署）
> 审查时间：2026-08-06 ｜ 审查方式：纯只读静态审查（本地文件/日志/二进制 + GitHub 公开 API + 数据库只读 SELECT）
> 源码基线：`callmefree/soulcore-tortoise-wow` main @ **79bb003**（2026-08-06 "Fix round-3 build errors"）
> 审查边界：不做运行时功能验证；功能项以「待人工验证清单」交付

---

## 一、执行摘要

**总体结论：第一阶段移植成功，质量良好，可进入第二阶段。** 无 P0 问题。

- ✅ **编译**：双平台 CI 通过（run #31081247956），运行实例 revision=79bb003 与源码一致
- ✅ **部署**：Eluna 版二进制已正确替换，备份完整可回滚，配置已追加，启动 43 秒无任何 Lua 错误
- ✅ **运行时证据**：`Loading Lua engine...` → `[Lua] Loaded 2 Lua scripts from 'lua_scripts'.` → `World server is up and running!`
- ⚠️ **发现 5 个 P1、4 个 P2、若干 P3**：主要集中在**产物包不完整**、**测试脚本存在 bug**（事件 ID 错误 + API 不兼容 + NPC 不存在）、**配置模板不一致**。均不影响当前运行，但影响「重新部署/正式启用脚本」。
- 📋 计划书 P0 有 2 项未勾选（第四轮 CI、双平台通过），实际已完成 —— 文档维护滞后（P3）。

---

## 二、验收对照表（计划书 vs 实际）

| 计划书项 | 级别 | 结论 | 证据 |
|---|---|---|---|
| CMake 集成 `USE_LUA`（默认 ON）+ DEFINITIONS | P0 | ✅ 通过 | 顶层 CMakeLists:42 `option(USE_LUA ... ON)`；:388-393 `set(DEFINITIONS ... USE_LUA)` |
| TurtleLuaEngine 移植（2.5 万行引擎） | P0 | ✅ 通过 | `src/game/LuaEngine/TurtleLuaEngine.cpp` 793,492 B（~2.5 万行）+ .h 29,536 B |
| dep/lualib 引入 Lua 5.2.4 静态链接 | P0 | ✅ 通过 | `dep/lualib/lua/CMakeLists.txt` FetchContent lua-5.2.4.tar.gz（SHA256 b9e2e4aa…官方值）；LUA_STATIC ON；无 lua DLL 分发 |
| src/game/CMakeLists 集成 | P0 | ✅ 通过 | :564-572 `if(USE_LUA)` 加引擎源文件 + add_subdirectory；:626-630 link lualib |
| 216 hook / 41 文件 patch | P0 | ✅ 通过（抽查） | ScriptMgr.cpp 18 处 `sTurtleLuaEngine.OnXXX`、Player.cpp 15 处、hook 枚举覆盖 Player(36)/Unit(19)/ScriptMgr(19)/ChatHandler(16) 等 |
| 双平台 CI 编译通过 | P0 | ✅ 通过（**文档未勾选**） | commit 79bb003 消息「双平台编译通过（run #31081247956）」；uptime 表 revision='79bb0034c38df624cb12' |
| 备份 server/bin | P1 | ✅ 通过 | `server/bin_backup_pre_eluna/` 完整（旧版 mangosd.exe 10,048,512 B，md5 cf9f0410… + DLL/conf） |
| 替换二进制 | P1 | ✅ 通过 | 运行 mangosd.exe = 产物（10,771,456 B，md5 efdb0818… 一致） |
| conf 追加 Eluna 配置 | P1 | ✅ 通过 | `server/bin/mangosd.conf`:2138 `Eluna.Enabled = 1`、:2142 `Eluna.ScriptPath = "lua_scripts"` |
| 启动验证 | P1 | ✅ 通过 | 日志:3895-3896 Lua engine 加载 + 2 脚本；:3948 World server up（43s） |
| **玩家登录验证**（登录欢迎/elunatest/gossip） | P1 | ⬜ **未验证（待人工）** | 需客户端登录实测 |

---

## 三、各域审查结论

### A. 文档对齐
- 计划书状态行「✅ 编译通过 + 本地部署验证通过」与实际一致；但 **P0 清单 2 项未勾选**（第四轮 CI、双平台通过），实际已由 79bb003 完成 → **P3 文档滞后**
- 工作记录（14:00 版）未记录 79bb003 部署完成，与计划书（17:05 版）存在时间差 → P3

### B. 源码集成（GitHub API 核验，全部通过）
- `#ifdef USE_LUA` 保护**实际已覆盖**（与计划书 P2 预判不同）：Player.cpp 38 对、ScriptMgr.cpp 19 对且 include 也在保护内 → **USE_LUA=OFF 编译风险大幅降低**，P2 项降级
- commit 79bb003 diff 质量合理（21 处变更全部为 hook 所需局部变量声明/成员补全，无逻辑改动）

### C. 产物与部署
- 运行 exe 与 CI 产物一致 ✅；备份完整可回滚 ✅
- **❌ P1：产物包不可独立部署**：`artifact_win_eluna/dist/bin/` 缺 `libmysql.dll`、`libssl-1_1-x64.dll`、`libcrypto-1_1-x64.dll`、`lua_scripts/` 目录——解压后无法直接运行，必须与现有 server\bin 配套

### D. 运行时证据
- 启动完整无 Lua 错误 ✅；部署切换干净（13-44 日志无 Eluna → 17-01 有 Eluna）✅
- `ERROR:[Anticheat] Could not find configuration file anticheat.conf` 在部署前（13-44）与部署后（17-01）日志**都存在** → **非 Eluna 引入，属既有配置缺失**（P3，与本移植无关）

### E. 配置
- 运行配置正确（Enabled=1 + ScriptPath）；上游 `.in` 与产物模板一致 ✅
- **❌ P1：本地模板不一致**：`server/etc/mangosd.conf.dist` 是旧模板（**无** Eluna 配置段），产物 `dist/etc/mangosd.conf.dist` 有（4 处匹配）→ 若按本地模板重新部署会丢失 Eluna 配置
- 缺 `Eluna.TopLevelScriptPath` → P2 增强项（单层脚本目录当前够用）

### F. 脚本质量（重点：发现 2 个脚本 bug）
| 脚本 | 问题 | 级别 |
|---|---|---|
| welcome.lua | `RegisterServerEvent(1, OnStartup)` **事件 ID 错误**：引擎枚举中 1=`SERVER_EVENT_ON_NETWORK_START`（网络启动），真正的启动事件是 `WORLD_EVENT_ON_STARTUP = 14`。当前注册语义错误（仅影响启动 print 时机，不影响登录/聊天功能）。脚本内注释「需确认 server event id」已自我标记 | **P1** |
| welcome.lua | `OnChat` 无聊天类型过滤：任意频道（含悄悄话）说 `elunatest` 均触发；无限发炉石（6948 无次数限制）→ 测试功能残留，正式运营前必须删除或加 GM 校验 | **P2** |
| test_gossip.lua | `player:GossipMenu(1, creature, 0)` **API 不存在**：引擎 Player 绑定仅有 `GossipMenuAddItem`/`GossipComplete`/`SendGossipMenu`（=`PlayerGossipSendMenu`），**无 `GossipMenu` 方法**（官方 Eluna 标准有，WYTurtle 引擎无）→ 运行到该行将抛 Lua 错误（pcall 捕获），菜单不会正确关闭。修正：改 `player:SendGossipMenu(1, creature)` | **P1** |
| test_gossip.lua | **entry 190001 数据库中不存在**（creature_template 无此记录，creature 实例 0 条）→ gossip 事件永不触发。需先添加 NPC 或改用已有 entry | **P1** |
| 两个脚本 | API 绑定抽查均存在（AddItem 7 处 / SendBroadcastMessage 3 处 / GossipMenuAddItem 2 处 / GossipComplete 3 处）✅；`AddItem(6948)` 炉石在 item_template 中存在 ✅ | ✅ |

### G. 安全与稳定性
- 脚本异常隔离：`lua_pcall != LUA_OK` 检查 20+ 处 ✅；唯一例外是延迟事件包装器 `LuaEventWrapper` 内裸 `lua_call`（TurtleLuaEngine.cpp:1312，已先查 `lua_isfunction`）→ **P3 观察点**（延迟回调抛错可能向上传播）
- Anticheat 告警非 Eluna 引入（见 D）✅；warden 正常加载（92 scans）✅

---

## 四、问题清单（分级）

| 级别 | 问题 | 影响 | 建议处置 |
|---|---|---|---|
| **P1** | 产物包缺 3 个 DLL + lua_scripts，不可独立部署 | 换机/重部署失败 | 补全产物包；或部署时固定沿用 server\bin 配套 DLL |
| **P1** | welcome.lua `RegisterServerEvent(1)` 事件 ID 语义错误 | 启动 print 不触发/时机错 | 改 `RegisterServerEvent(14, OnStartup)`（WORLD_EVENT_ON_STARTUP） |
| **P1** | test_gossip.lua 用 `player:GossipMenu` 引擎无此 API | 运行到该行抛 Lua 错误 | 改 `player:SendGossipMenu(1, creature)` |
| **P1** | test_gossip.lua entry 190001 数据库不存在 | gossip 永不触发 | 添加 creature_template 190001 或改用现有 NPC |
| **P1** | `server/etc/mangosd.conf.dist` 旧模板无 Eluna 配置 | 按模板重部署丢配置 | 用产物 `dist/etc` 模板覆盖本地模板 |
| **P2** | 缺 `.reload eluna` 命令（热重载） | 改脚本需重启 | 第二阶段实现（Chat.cpp 命令表注册，引擎已有 OnConfigLoad reload 逻辑） |
| **P2** | 缺 `Eluna.TopLevelScriptPath` | 无法子目录组织脚本 | 第二阶段补配置项 |
| **P2** | welcome.lua 测试功能残留（任意玩家 `elunatest` 领炉石、无 type 过滤） | 测试期可用，运营风险 | 正式运营前删除/加校验 |
| **P2** | 计划书 P0 勾选滞后（第四轮 CI、双平台通过未勾） | 文档误导 | 更新计划书勾选 |
| **P3** | LuaEventWrapper 裸 `lua_call` 无 pcall | 延迟回调异常传播 | 观察；或补 pcall 包裹 |
| **P3** | Anticheat `anticheat.conf` 缺失告警 | 反作弊功能未配置 | 与本移植无关，单独跟进 |

---

## 五、待人工验证清单（运行时功能，需客户端登录）

> 服务端当前正在运行（realmd 3724 + mangosd 8090），可直接用客户端测试：

1. **登录欢迎**：GM 账号 admin 登录 → 应收到 `[Eluna] 欢迎来到 Soulcore 私服！` 广播（验证 OnLogin，PlayerEvent 3）
2. **聊天命令**：游戏内说 `elunatest` → 应收到 `[Eluna] Eluna 引擎响应正常！` 且获得炉石 6948（验证 OnChat，PlayerEvent 18）
3. **NPC gossip**（需先处置 F 域 P1 项）：添加 NPC 190001 后交互 → 菜单「查看我的信息 / 给我一个炉石」（验证 RegisterCreatureGossipEvent）
4. **启动 print**（修复后）：下次重启日志应见 `[Eluna] Server started...`（验证 ServerEvent 14）
5. **Anticheat 告警归属**：确认 `anticheat.conf` 缺失是否为已知既有问题（与 Eluna 无关，13-44 日志同款）

验证时若脚本报错，检查 `server/logs/server_*.log` 中 `[Lua]` 错误行。

---

## 六、第二阶段建议（P2 增强）

1. **实现 `.reload eluna` 热重载命令**：Chat.cpp 命令表注册 → 调 `TurtleLuaEngine` reload 逻辑（引擎 `OnConfigLoad` 已支持；参考 uiwow 帖子方法）
2. **补 `Eluna.TopLevelScriptPath` 配置项** + 支持脚本子目录
3. **修复 F 域 3 个脚本问题**后，扩充测试：任务完成、拾取、击杀、物品事件
4. **完善 CI 产物包**：Windows job 打包时纳入 libmysql/libssl/libcrypto DLL 与 lua_scripts 目录
5. **统一配置模板**：以含 Eluna 段的产物模板为基准，同步本地 server/etc
6. 引擎单文件 2.5 万行维护性（P3）：后续可考虑按 Eluna 官方结构拆分 LuaFunctions/ElunaEventMgr

---

## 附：审查证据索引

- 日志证据：`server/logs/server_2026-08-06_17-01-50.log` 行 3895-3896、3948、3869-3894（anticheat）
- 配置证据：`server/bin/mangosd.conf` 行 2136-2142
- 二进制证据：`server/bin/mangosd.exe` md5 `efdb0818…` = 产物一致；备份 `bin_backup_pre_eluna/mangosd.exe` md5 `cf9f0410…`
- 源码证据：GitHub `callmefree/soulcore-tortoise-wow` main@79bb003（CMakeLists:42/388、src/game/CMakeLists:564/626、TurtleLuaEngine.h 事件枚举、TurtleLuaEngine.cpp:8344/8367/18478-18482 绑定、ScriptMgr.cpp:30/1784+）
- 数据库证据：`tw_world.creature_template` 无 entry 190001；`item_template` 6948 Hearthstone 存在
