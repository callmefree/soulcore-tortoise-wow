# Eluna 第一阶段移植 — 审计与验证报告

> 审计时间:2026-08-09 ｜ 方式:源码静态审计(本地 clone 双树比对)+ 构建/部署审计 + 运行时启动验证(实测)
> 基线:fork `callmefree/soulcore-tortoise-wow` main@**79bb003**(8/6 双平台编译通过)
> 参照:WYTurtle(`gitee.com/brison/tw171_Eluna` 深度1 clone,`_audit/oyturtle`)+ 上游 `Penqle/tortoise-wow`
> 审计工作区:`_audit/{soulcore,oyturtle,audit_scripts,start_*.ps1}`
> **范围**:仅审计+验证,**未修复任何 P1**(按用户要求);运行时客户端登录实测推迟(用户选定「暂不做登录,出报告」),相应项标「待人工」。

---

## 一、执行摘要

**第一阶段移植的源码正确性得到证实,当前部署可运行;运行时功能项(登录/聊天/gossip)仍待客户端人工验证。**

- ✅ **源码正确性(强证据)**:引擎本体与 WYTurtle **逐字节一致**;43 个 hook 文件与 WYTK 的 **hook 名称+频次集合逐文件一致**;41/41 文件 hook **放置审计全部 PASS**(平行子进程逐 hook 比对:同函数、同次序、原调用保留)。
- ✅ **依赖真实性**:lua-5.2.4 **SHA256 实测与官方值一致**;lualib CMake/lua.hpp 与 WYTK 逐字节一致。
- ✅ **部署一致**:运行二进制 = CI 产物(md5 一致);备份完整可回滚。
- ✅ **运行时启动**:MariaDB + realmd + mangosd 干净启动,无任何 Lua 错误,**审计脚本实测 `WORLD_EVENT_ON_STARTUP(14)` 触发**,同时实证 `ServerEvent(1)` 在启动期未触发 → **确认 welcome.lua 事件 ID P1**。
- ⚠️ **门禁判定:静态/启动域通过;运行时功能域(G2 登录/聊天、G3 游戏回归)为「待人工」**,须客户端登录后方可最终判。
- 📋 原 5 个 P1 + 4 个 P2 复验仍成立;新增 1 个 P3(Spell.cpp `<memory>` include 移除,见 §六)。

---

## 二、审计维度结论

### A. 源码静态审计(只读) — 结论:**通过**

| 项 | 结论 | 证据 |
|---|---|---|
| **A1 CMake 集成** | ✅ 通过 | 顶层 `CMakeLists.txt:42 option(USE_LUA ON)`、`:388-390 DEFINITIONS USE_LUA`;`src/game/CMakeLists.txt:523` include、`:564-571` 引擎源+`add_subdirectory(dep/lualib/lua)`、`:626-628 link lualib`;`:569-570 set(LUA_VERSION "lua52")+ set(LUA_STATIC ON)`;`mangosd.conf.dist.in` 含 Eluna.Enabled/ScriptPath(与产物模板一致,均 4 处) |
| **A1 依赖真实性** | ✅ 通过 | 实测下载 `lua-5.2.4.tar.gz` sha256=`b9e2e4aa…69f4b` **= CMake URL_HASH 官方值**;`dep/lualib/lua/{CMakeLists.txt,lua.hpp}` 与 WYTK 逐字节一致 |
| **A2 引擎完整性** | ✅ 通过 | `TurtleLuaEngine.cpp`(25,499 行/793,492 B)与 `TurtleLuaEngine.h` md5 = WYTK **完全一致**(`f6db2b72…` / `c658ccd2…`) |
| **A3 hook 集合** | ✅ 通过 | 43 文件 `grep sTurtleLuaEngine.On*` 集合与 WYTK **逐文件名称+频次全同**;41/41 文件**放置审计 PASS**(子进程逐 hook 比对:同函数/同次序/原调用保留) |
| **A3 原逻辑保留** | ✅ 通过 | 45 处 diff 删除行全部核实:AI 守卫被「wrap+skip」包裹(hook 返回真才跳过,默认不干预=原逻辑执行)、变量/语句提升(同条件同值)、DBC 字段替换(确认无引用)、Player.h 三方法体搬移 cpp(hook 内保留原逻辑)。**无一处原游戏逻辑被丢弃** |
| **A4 已知修复** | ✅ 通过 | Player.h 三方法已外联(Player.cpp:3974/16167/16175);`randomPropertyChance` 全仓无引用;`sItemDisplayInfoStore` 已恢复(DBCStores.h:78/.cpp:60/211) |
| **A5 API 绑定** | ✅ 通过 | 引擎逐字节=WYTK → 绑定集合=参照;抽查包装方法落地(GameObject GetOwnerGroupId/GetSingleAllowedLooterGuid、Player GetTalentResetCost、ObjectMgr AddTaxiNodeEntry、GmTicket GetResponse) |
| **A6 事件枚举** | ✅ 通过(记录) | `PLAYER_EVENT_ON_LOGIN=3/ON_CHAT=18/ON_LEVEL_CHANGE=13` 正确;`SERVER_EVENT_ON_NETWORK_START=1`、`WORLD_EVENT_ON_STARTUP=14`(TurtleLuaEngine.h:106/118)→ **welcome.lua `RegisterServerEvent(1)` 语义错(P1)**,14 才是启动事件;运行时实证见 D2 |
| **A7 异常隔离** | ⚠️ 观察 | 引擎 `lua_pcall` 90 处受保护;**仅 1 处裸 `lua_call`@:1312**(LuaEventWrapper 延迟回调)→ P3(需实测 auditerr 路径验证,见 D5) |
| **A8 USE_LUA 覆盖** | ⚠️ 记录 | 已保护文件核对(Player.cpp 38 对、ScriptMgr.cpp 19 对,含 include);**6 文件无保护**(BattleGround.cpp/GMTicketMgr.cpp/GMTicketHandler.cpp/MapManager.cpp/Object.cpp/TemporarySummon.cpp)→ P2(USE_LUA=OFF 编译会挂,默认 ON 不受影响) |
| **A9 头文件结构** | ✅ 通过 | 被动过头文件无「内联体+外联重定义」残留;三方法纯声明正确 |

### B. 构建 / 产物审计 — 结论:**通过(产物包完整性 P1 记录)**

| 项 | 结论 | 证据 |
|---|---|---|
| B3 二进制一致性 | ✅ | 运行 `server/bin/mangosd.exe` md5 `efdb0818…` = 产物 `dist/bin/mangosd.exe`;realmd `e6a9f487…`、ACE.dll `2b287c45…` 均一致 |
| B4 备份可回滚 | ✅ | `bin_backup_pre_eluna/` 含 mangosd.exe(md5 `cf9f0410…`=旧版)+ realmd/ACE/双 conf/lua_scripts/DLL,清单完整 |
| B2 产物完整性 | ❌ **P1** | `artifact_win_eluna/dist/bin/` **缺 `libmysql.dll`/`libssl-1_1-x64.dll`/`libcrypto-1_1-x64.dll`/`lua_scripts/`** → 产物不可独立部署,必须配套现有 server\bin(未修,进第二阶段 CI packaging 修复) |
| B1 CI 复现 | ◻ 未复跑 | 依据既有 run #31081247956(8/6 双平台通过);复跑 40-60min 可选 |

### C. 部署 / 配置审计 — 结论:**通过(模板一致性 P1 记录)**

| 项 | 运行 bin/mangosd.conf | 本地 etc 模板 | 产物 dist/etc |
|---|---|---|---|
| Eluna 配置段(行数) | **4**(Enabled=1:2138;ScriptPath:2142) | **0** ← P1 | **4** |
- **C1**:三向不一致——按本地 `server/etc/mangosd.conf.dist` 重新部署会**丢失 Eluna 配置**(P1,未修)。
- **C2**:运行必需 DLL 全部在 server/bin:ACE.dll / libmysql.dll / libssl-1_1-x64.dll / libcrypto-1_1-x64.dll ✅。
- **C3**:`Eluna.TopLevelScriptPath` 运行与产物模板均缺(P2,记录)。
- **C4**:部署状态与既有记录一致(备份→覆盖→追加配置→启动;本日启动沿用)。

### D. 运行时验证 — 结论:**启动域通过;登录/聊天/错误隔离域「待人工」**

| 项 | 结果 | 证据(server/logs/server_2026-08-09_11-06-34.log) |
|---|---|---|
| D0 环境 | ✅ | MariaDB 起(3306,pid 11676);realmd(3724,pid 11456)+ mangosd(8090,pid 12440);客户端 realmlist 已指 127.0.0.1:3724 |
| D1 干净启动 | ✅ | `Loading Lua engine…`(3900)+ `[Lua] Loaded 3 Lua scripts`(3901)+ `World server is up and running!`(3954,加载 1m18s);**全程无 Lua 错误** |
| D2 审计脚本(事件14) | ✅ **实证** | 部署临时 `_audit_engine.lua`(审计专用,与 P1 测试脚本隔离);`[AUDIT] WORLD_EVENT_ON_STARTUP(14) fired`(3902)——**启动事件 14 实测触发**;同时 welcome.lua 的 `[Eluna] Server started` **全程未出现** → **事件 1 未触发,确认 P1** |
| D3 登录/聊天 | ⏸ **待人工** | 需客户端 admin 登录触发 OnLogin(3)/OnChat(18)/OnLevelChange(13);审计脚本已就位,登录即可捕获 |
| D5 错误隔离 | ⏸ **待人工** | 聊天 `auditerr` 触发故意 `error()`,验证 pcall 后服务不崩(引擎 90 处 pcall + 1 裸 lua_call@1312 的 P3 实测) |
| D6 Anticheat | ✅ 观察 | `ERROR:[Anticheat] Could not find configuration file anticheat.conf.`(3875)——**既有问题,非 Eluna 引入**(审查报告已对照部署前后日志);Warden 92 scans + 11 scripted(3897-3899)正常 |

> 待人工清单(登录后即测):① 登录收到「[Eluna] 欢迎来到 Soulcore 私服!」;② 说 `elunatest` 收到响应并获炉石 6948;③ 说 `auditerr` 观察 Lua 错误日志且服务不崩;④ 核心游戏回归(移动/战斗/拾取/交易/组队/邮件/技能/坐骑/GM 命令);⑤ 登出再登事件稳定性。

---

## 三、门禁(Gate)判定

| 门禁 | 定义 | 本次结论 |
|---|---|---|
| **G1 源码** | Eluna 改动全部「新增」+ 原逻辑保留 | ✅ **通过**(hook 放置 41/41 PASS;45 删除行全部核实无逻辑丢失;wrap+skip 语义=参照设计,默认惰性) |
| **G2 运行时** | 无 Lua 崩溃;登录/聊天事件实测触发 | ⚠️ **部分**:无 Lua 崩溃 ✅;登录/聊天事件 **未实测(待人工)** |
| **G3 回归** | 基础游戏操作集无新增异常 | ⚠️ **部分**:启动/数据加载(zone/transport/loot)正常 ✅;游戏内操作集**未实测(待人工)** |

**结论**:第一阶段**静态与部署正确性成立、可运行**;最终「进入第二阶段」判定**待 G2/G3 人工登录补齐后关闭**。当前不阻塞但建议先补。

---

## 四、问题清单(复验 + 新增)

| 级别 | 问题 | 处置 |
|---|---|---|
| **P1** | 产物包缺 3 DLL + lua_scripts,不可独立部署(复验) | 第二阶段 CI packaging 补全 |
| **P1** | welcome.lua `RegisterServerEvent(1)` 事件 ID 语义错(复验+实证:启动期未触发;14 实测触发) | 改 `RegisterServerEvent(14)` |
| **P1** | test_gossip.lua `player:GossipMenu` API 不存在(引擎无此方法) | 改 `player:SendGossipMenu(1, creature)` |
| **P1** | NPC entry 190001 数据库不存在,gossip 永不触发(复验) | 添加 190001 或改用现有 entry |
| **P1** | `server/etc/mangosd.conf.dist` 旧模板无 Eluna 段,重部署丢配置(复验) | 用产物模板覆盖本地模板 |
| **P2** | 6 文件无 `#ifdef USE_LUA`(BattleGround/GMTicketMgr/GMTicketHandler/MapManager/Object/TemporarySummon) | USE_LUA=OFF 兼容时补保护 |
| **P2** | 缺 `.reload eluna` 热重载命令 | 第二阶段实现 |
| **P2** | 缺 `Eluna.TopLevelScriptPath` | 第二阶段补配置项 |
| **P2** | welcome.lua 测试残留(任意玩家 `elunatest` 领炉石无 type 过滤) | 运营前删除/加 GM 校验 |
| **P3** | LuaEventWrapper 裸 `lua_call`(:1312)无 pcall(复验) | 观察;auditerr 实测后定是否包 pcall |
| **P3** | **新增**:`Spell.cpp` 原 `#include <memory>` 被 hook 补丁移除(WYTK 同款),现依赖间接包含 | 低危(已编译通过);建议显式保留 `<memory>` |

---

## 五、证据索引

- **源码**:`_audit/soulcore`(main@79bb003);`_audit/oyturtle`(WYTK)
  - CMake:顶层 `CMakeLists.txt:42,388-390`;`src/game/CMakeLists.txt:523,564-571,626-628`;`dep/lualib/lua/CMakeLists.txt`
  - 引擎:`src/game/LuaEngine/TurtleLuaEngine.{h,cpp}` md5 `c658ccd2…`/`f6db2b72…` = WYTK
  - 事件枚举:`TurtleLuaEngine.h:106,118`;PlayerEvent:42-81
  - hook 文件 43 个集合一致;放置审计 41/41 PASS(workflow wf_838cb660-e3c,journal 见本会话)
- **日志**:`server/logs/server_2026-08-09_11-06-34.log` 行 3874-3902、3954
- **二进制**:mangosd `efdb0818…`(运行=产物)/ `cf9f0410…`(备份旧版)
- **数据库**:tw_logon.account id=4 admin rank=3;realmcharacters(1,4,0);characters 空(尚无角色)
- **SHA256**:lua-5.2.4 实测 = `b9e2e4aa…69f4b`

---

## 六、交付物与工具

- 本报告(工作区根)。
- 审计工作区 `_audit/`:源码 clone(可删)、WYTK 参考 clone(可删)、`audit_scripts/_audit_engine.lua`(审计脚本)、`start_db.ps1` / `start_servers.ps1`(启动辅助)。
- **当前服务在运行**(DB 3306 / realmd 3724 / mangosd 8090),审计脚本 `server/bin/lua_scripts/_audit_engine.lua` **已部署**(登录即可捕获事件)。
- **清理时**:删 `server/bin/lua_scripts/_audit_engine.lua` 后重启 mangosd 即恢复「2 脚本」;停服用 `taskkill` 对应 PID 或重启电脑。

## 七、下一步建议

1. **补运行时人工验证**(G2/G3):客户端 admin 登录 → 建角色 → 登录欢迎 / `elunatest` / `auditerr` / 核心回归 —— 完成即关闭门禁。
2. 之后进入**第二阶段**:`.reload eluna` + `TopLevelScriptPath` + CI 产物包补全 + 配置模板统一 + 脚本修复(P1×4)。
3. 可选:补 Spell.cpp `<memory>` include(消 P3);USE_LUA=OFF 兼容(消 P2)。
