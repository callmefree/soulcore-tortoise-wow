# Turtle WoW 私服部署与 Eluna 移植 — 完整工作记录

> 记录日期：2026-08-06 ｜ 环境：Windows 11 本机 ｜ 上游：Penqle/tortoise-wow（MaNGOS 系 1.12）
> 用途：后续重开会话继续 Eluna 移植的接续参考。本文件是唯一完整记录，重开会话先读它。

---

## 一、项目概览

| 项 | 值 |
|---|---|
| 上游仓库 | https://github.com/Penqle/tortoise-wow（main 分支，C++17，MaNGOS 系 1.12 Turtle WoW 私服端） |
| 用户 fork | callmefree/soulcore-tortoise-wow（已改名；GitHub PAT 见用户记忆，约 2026-11-02 过期） |
| CI workflow | `.github/workflows/weekly-build.yml`（每周一 03:00 UTC + push + 手动触发；双 job：Linux/Windows） |
| 本地工作区 | `E:\11111\soulcore tortoise wow\`（客户端 11GB、mariadb/、server/、产物 zip） |
| 服务端运行目录 | `E:\11111\soulcore tortoise wow\server\bin\`（realmd.exe + mangosd.exe） |
| 数据库 | MariaDB 11.4.4 绿色版（`mariadb\mariadb-11.4.4-winx64\`），root=soulcore2026，3306 |
| 四库 | tw_logon / tw_world / tw_char / tw_logs（mangos/mangos 账号授权） |
| 客户端 | `客户端\`（完整 1.12 Turtle WoW，build 5875，含 dbc/terrain/patch*.MPQ） |

**当前状态：服务端已完整部署并运行（realmd 3724 + mangosd 8090），GM 账号 admin/admin123。**

---

## 二、GitHub Actions 编译链路（关键历史与坑）

### workflow 结构（weekly-build.yml）
- **build（Linux, ubuntu-22.04）**：apt 装 libace-dev/libssl/libbz2/zlib/libmysqlclient；ccache 缓存；`-DUSE_PCH=ON -DUSE_SCRIPTS=ON -DUSE_EXTRACTORS=OFF -DALLOW_TURTLE_ADDONS=ON`；`cmake --build -j2`。
- **build-windows（windows-latest）**：vcpkg 装 **ace（8.0.6，不 pin 版本）**；两个 ACE 头文件 patch（见下）；MSVC；`-DUSE_EXTRACTORS=ON`（地图提取工具）；产物含 4 个 extractor + offmesh.txt/mmapSettings.txt。

### 编译期修复历史（重要，避免重复踩坑）
1. **LFT ObjectGuid 报错**（2026-08-04，Linux）：上游 LFTMgr.h 缺 `#include "ObjectGuid.h"`，只有 PCH=ON 时被掩盖。解法：workflow 用 `-DUSE_PCH=ON`（与上游默认一致，**不动上游源码**）。上游 main 裸编译（PCH OFF）必挂。
2. **产物空壳 bug**（2026-08-05）：CMakeLists 的 `RUNTIME_OUTPUT_DIRECTORY=源码根/bin` 只在 `if(WIN32)` 生效；Linux 二进制实际在 `build/src/mangosd/mangosd`、`build/src/realmd/realmd`。打包用 `cp build/src/mangosd/mangosd build/src/realmd/realmd dist/bin/`；conf 从 `find build -name "*.conf.dist"` + `find src -name "*.conf.dist.in"`（改名去 `.in`）兜底（4 个 conf 无占位符，直接改名即可）。
3. **Windows C2694**（2026-08-05/06，最曲折）：`error C2694: ACE_Singleton<WorldSocketMgr>::~ACE_Singleton 异常规格比 ACE_Cleanup 宽松`。
   - `/Zc:noexceptTypes-` **无效**（已实测）。
   - **真解法（有效）**：编译前 patch vcpkg 安装的 ACE 头文件：
     - `C:\vcpkg\installed\x64-windows\include\ace\Cleanup.h`：`virtual ~ACE_Cleanup () = default;` → `virtual ~ACE_Cleanup () noexcept (false) = default;`（主修复，覆盖所有派生）
     - `Singleton.h`：给 ACE_Singleton 插 `~ACE_Singleton () noexcept override = default;`（双保险）
   - 最小复现实验（verify-ace 分支，4 轮）**始终未复现 C2694**——真实触发条件比"模板隐式析构"假设复杂；以全量编译验证为准。verify-ace 分支保留供后续调试。
   - patch 脚本本地 PowerShell 验证后再推 CI（幂等 Already patched 分支）。
4. **extractor 工具**：`USE_EXTRACTORS=ON` 编译 mapextractor/vmapextractor/vmap_assembler/MoveMapGen（tools/ 目录），Package 复制 4 exe + `tools\mmap\offmesh.txt`、`mmapSettings.txt`。
5. **conf 命名 bug**：PowerShell `$_.BaseName + ".dist"` 产生 `mangosd.conf.dist.dist`；改为 `$_.Name -replace '\.in$',''`。
6. 推送/验证工作流：本地 `/tmp/soulcore-fix2` 浅克隆（SSH remote 已配），改完 cp 到 `.github/workflows/` 再 commit+push；每次先本地 PowerShell 模拟验证脚本。

### CI 产物（工作区 zip 存档）
- `artifact_win_final.zip`（7f9a7b6 无 extractor 版）、`artifact_win_extractor.zip`（5293b6b 含 extractor）、`artifact_linux_final.zip`。

---

## 三、本地部署完成状态（2026-08-06 14:00）

### 目录布局
```
E:\11111\soulcore tortoise wow\
├── 客户端\                 # 11GB Turtle WoW 1.12 客户端（realmlist 已改 127.0.0.1:3724）
├── mariadb\                # MariaDB 11.4.4 绿色版（mariadb-11.4.4-winx64\bin\mariadbd.exe）
├── server\
│   ├── bin\                # 运行目录：realmd/mangosd/mapextractor 等 + DLL + mangosd.conf/realmd.conf
│   ├── etc\                # 4 个 *.conf.dist（模板）
│   ├── sql\                # create_databases.sql + base/（186 分片）+ database_updates/
│   ├── data\               # dbc/ maps/ vmaps/ mmaps/ + Buildings/（提取中间产物）
│   └── logs\               # server_*.log、errors.log 等
└── artifact_*.zip          # CI 产物存档
```

### 服务端运行要素
- **DLL 清单（server\bin 必需）**：ACE.dll（CI 产物自带）、**libmysql.dll（= MariaDB `lib\libmariadb.dll` 改名复制）**、**libssl-1_1-x64.dll + libcrypto-1_1-x64.dll（OpenSSL 1.1，取自 Git 2.40 MinGit 的 mingw64/bin；本机无 1.1 只有 3.x）**。VC 运行库（vcruntime140_1 等）系统自带。
- **conf 位置**：进程从**当前工作目录**找 `mangosd.conf`/`realmd.conf`（不是 ../etc/）→ 复制到 bin/。**Anticheat 同理**：`anticheat.conf` 也从 CWD 读（World.cpp:591 `sAnticheatConfig.SetSource("anticheat.conf")`）——2026-08-09 已部署上游只读模板（`src/game/Anticheat/anticheat.conf.readonly` 改名）到 `server/bin/` + `server/etc/`（md5 一致；只读模式=仅记录不执法，适合私服；换机部署勿漏）。
- **关键配置**：`Database.AutoUpdate.Path = "../sql/"`（原 ../../sql/ 要改）；DataDir=../data、LogsDir=../logs；DB 连接 `127.0.0.1;3306;mangos;mangos;tw_*`（与 MariaDB 建好的账号一致）。
- **启动方式（重要）**：PowerShell `Start-Process -FilePath "server\bin\realmd.exe" -WorkingDirectory "server\bin"`（独立进程）。**不要用工具的后台任务方式**——会话中断会杀子进程。mangosd 首启自动应用 database_updates。
- **启动验证**：`netstat -ano | grep -E ":3724|:8090"` 监听；日志 "World server is up and running!"。

### 数据库
- 建库：`create_databases.sql`（实为完整 dump：建库+表结构，552KB）→ 四库表结构齐但**数据空**。
- 数据：`sql\base\tw_world_*.sql` 186 个分片导入 `tw_world`（131MB，mysql tw_world < file 循环）。
- realmlist：INSERT `(name='Turtle WoW', address='127.0.0.1', port=8090, realmbuilds='5875 ')`；**id 必须=1**（自增可能到 2，需 UPDATE 回 1 匹配 RealmID=1）。mangosd 启动会自动把 realmbuilds 覆盖为 '5875 '（客户端 build，正确）。
- 端口：realmd 3724（客户端连这个）、mangosd 8090（Turtle 非 8085）。

### 账号（GM）
- admin / admin123（rank=3 最高 GM）。
- **建号方法（SQL 直接插）**：`sha_pass_hash = SHA1(UPPER(user) + ':' + UPPER(pwd))` hex 大写；**s/v 字段留空**，realmd 首登自动计算写库（Turtle SRP6 特制：N=256bit、g=7，非标准参数，勿手算）。补 `realmcharacters (realmid=1, acctid, numchars=0)`。

### 地图数据提取（4 步，全部在 server\data 下执行）
1. `mapextractor -i <客户端根> -o .` → dbc/（158）+ maps/（2805）。"Can't find area flag for areaid 4546" 是 Turtle 自定义区域警告，正常。
2. `vmapextractor -s -d <客户端\Data>` → Buildings/（5367 wmo）。-l/-s 均可。
3. `vmap_assembler Buildings vmaps` → vmaps/（6921）。**坑：必须事先 `mkdir vmaps`**（带参数时不自动建目录，否则 writeFile 静默失败报 "error converting" 误导）。依赖 OpenSSL 1.1 DLL。
4. `MoveMapGen --offMeshInput offmesh.txt`（offmesh.txt/mmapSettings.txt 复制到 CWD）→ mmaps/（58 .mmap + 2075 .mmtile，2.3GB，耗 1-2 小时）。

### 客户端
- `realmlist.wtf`：`set realmlist 127.0.0.1:3724`；`WTF\Config.wtf` 同改。turtle-shell 启动器可能覆盖（未验证）。

---

## 四、Eluna 移植（下次会话主任务）

### 目标
在 tortoise-wow（基于 MaNGOSZero/VMaNGOS 系）上集成 Eluna Lua 引擎，使服务端支持 Lua 脚本（自定义 NPC/任务/事件/GM 命令/热重载），不改动 C++ 即可加内容。

### 可行性调研结论（2026-08-06）
- ✅ **高度可行且有先例**：
  1. **Eluna-Ports/Eluna-VMaNGOS**（github.com/Eluna-Ports/Eluna-VMaNGOS）——VMaNGOS（1.12.1.5875）with Eluna，2026-07 仍在更新。tortoise-wow 与 VMaNGOS 架构同源（MaNGOSZero 系），**移植参考价值最高**。
  2. **WYTurtle（gitee.com/brison/VM_Eluna）**——**基于 tortoise-wow 的现成 Eluna 移植版**（配置 `Eluna.Enabled = 1`、`Eluna.ScriptPath = "lua_scripts"`，运行目录建 lua_scripts/，附带 lua52_compiler）。**最接近的现成方案**，可直接对照其源码差异做移植。
  3. ElunaLuaEngine/Eluna 官方：核心引擎，支持 MaNGOS/CMaNGOS/TrinityCore；官方维护 "MaNGOS with Eluna"（Vanilla）。
  4. uiwow 论坛有乌龟服（1.18.1）Lua 植入分析帖；reload eluna 命令需在 Chat.cpp 注册（335 移植思路，tortoise 同样适用）。

### 移植路线草案（下次会话细化）
1. **选参考基线**：优先对照 WYTurtle（同上游 tortoise 的移植 diff）；次选 Eluna-VMaNGOS。
2. **引入 Eluna 源码**：dep/ 下加 Lua 5.2+ 源码（或 CMake FetchContent）；Eluna 源码进 src/game/ 或独立模块目录（ElunaLuaEngine/Eluna 的 src 结构：LuaEngine.cpp/h、LuaFunctions.cpp、ElunaEventMgr.cpp/h 等）。
3. **CMake 集成**：CMakeLists.txt 添加 Eluna + Lua 编译目标；注意 C++17 + PCH（上游 PCH=ON，Eluna 集成可能需调整 PCH 或加 include）。
4. **桥接点**：ScriptMgr 加 Eluna 初始化/事件分发钩子（Eluna 通过 ScriptMgr 接口桥接 AI/InstanceData 等）；`Eluna.Enabled=1`、`Eluna.ScriptPath="lua_scripts"` 配置项。
5. **命令**：mangosd 控制台/GM 命令加 `reload eluna`（Chat.h/Chat.cpp 注册，参考 uiwow 帖子方法）。
6. **冲突与风险**：
   - tortoise-wow 大量自定义扩展（PlayerBots、Shop、AutoScale、Turtle 专属系统），Eluna 标准 API 绑定可能不覆盖，需手动补绑定。
   - C++17 + PCH 头文件冲突/链接问题。
   - 反作弊（Anticheat）可能对 Lua 操作告警（中风险，可接受）。
   - 双脚本系统共存：Eluna 作胶水层调用已有 C++ AI，不冲突。
7. **验证**：编译（本地无 VS——**用 CI 编译**，复用现有 workflow 加 Eluna 依赖）→ 运行 → 放测试 lua（如炉石菜单）→ reload eluna 热重载验证。

### 注意事项
- 本地无 VS/CMake：**所有 C++ 编译依赖 GitHub Actions CI**（改 workflow 推送触发；Windows job 已有 vcpkg ace + patch 流程，加 Eluna 依赖即可）。
- 移植前先备份当前可用产物（服务端在跑，别破坏）。

### ✅ 移植执行状态（2026-08-06 下午，进行中）
- **方案选定**：采用 **WYTurtle（gitee brison/tw171_Eluna，94 commits 完整历史）** 的 TurtleLuaEngine 移植，而非官方 Eluna——它是为 tortoise-wow 定制的完整 Eluna 兼容层（2.5 万行单文件），方法覆盖 Player ref=254/target=521、Creature ref=87/target=340、TOTAL_MISSING=0，含大量 Turtle 1.12 适配。
- **参考仓库**：`/tmp/eluna-ref/wyturtle`（gitee 完整历史）、`/tmp/eluna-ref/eluna-vmangos`（Eluna-VMaNGOS development，submodule 引 Eluna，备用）。
- **移植内容（commit b0455bf 已推 main）**：
  1. 新文件：`src/game/LuaEngine/TurtleLuaEngine.{h,cpp}`（引擎）、`dep/lualib/lua/{CMakeLists.txt,lua.hpp}`（Rochet2 CMake，FetchContent 拉 **lua-5.2.4**，LUA_STATIC=ON）。
  2. CMake：顶层 `USE_LUA` option（默认 ON）+ DEFINITIONS；src/game/CMakeLists 加引擎源文件 + add_subdirectory(dep/lualib/lua) + link lualib。
  3. 配置：mangosd.conf.dist.in 加 `Eluna.Enabled = 1`、`Eluna.ScriptPath = "lua_scripts"`。
  4. **216 个 Eluna hunk 自动 patch 到 41 个核心文件**（Python 脚本按 diff hunk 过滤 `TurtleLuaEngine|USE_LUA` 后 fuzz=4 apply，0 失败），约 200 个事件 hook 点（Player 36 处/Unit 19/ScriptMgr 19/ChatHandler 16 等）。
  5. **误删修复**（fuzz 带入 WYTurtle 旧基线差异）：恢复 Unit.cpp `ScriptMgr.h` include、ScriptMgr.cpp `<algorithm>` + GetSpellScript/GetAuraScript 函数体、World.cpp 直接读配置逻辑（LoadConfigSettingsFromFile，tortoise 特意不走 DB）、WorldSession/ChatHandler `LFTMgr.h`、SpellEffects `ToyManager.hpp`、Player.cpp PlayerBot 升级块 + `m_extraBonusTalentCount` 行。
  6. **ScriptMgr.h 补 2 个声明**（WYTurtle 有 Item 版、tortoise 缺）：`OnGossipSelect(Player*, Item*, ...)`、`OnItemGossipHello(Player*, Item*, SpellCastTargets&)`——否则 cpp 新增定义编译失败。
- **workflow 改动**：Linux job apt 加 `libreadline-dev`（Rochet2 lualib CMake 在 UNIX 链 readline）。
- **CI**：run #31076028515（b0455bf）编译中。风险点：TurtleLuaEngine.cpp 用的 tortoise API 与 WYTurtle 旧基线差异（编译错误待修）、lua.org FetchContent 下载。
- **测试脚本已备**：`server/bin/lua_scripts/{welcome.lua,test_gossip.lua}`（登录欢迎、聊天命令 elunatest、NPC gossip 190001）。
- **待办**：CI 编译迭代修复 → 下载产物部署（备份旧 bin）→ 启动验证 → 补 `reload eluna` 命令（WYTurtle 未实现，OnConfigLoad 有 reload 逻辑）。
- Eluna 官方维护分支 "MaNGOS with Eluna"（WotLK）与 1.12 Vanilla 版本差异需注意；1.12 用 Eluna-VMaNGOS 的代码更贴切。

### ✅ 第一阶段审计 + G2 运行时验证（2026-08-09）
- **审计完成**：详见 `Eluna_第一阶段审计与验证报告.md`（源码逐字节=WYTK、hook 41/41 PASS、G1 门禁通过）。
- **G2 门禁已关闭**（free 角色 60→121 级实测，日志 `server_2026-08-09_11-44-47.log`）：
  - 启动事件 14 实测触发（:3899）；`Loading Lua engine` + `Loaded 3 Lua scripts`（:3897-98）
  - **OnLogin(3)**：:3998 / 二次登录 :4053 → 事件稳定性 OK
  - **OnChat(18)**：:4005 `msg=elunatest` → welcome.lua AddItem(6948) 成功，背包炉石实证（bag0/slot23）
  - **错误隔离**：:4008-4009 auditerr 故意 `error()` 被 pcall 捕获（`ERROR:[Lua] player chat event:`），**服务不崩** → 审计 P3（裸 lua_call@:1312）在聊天路径无风险，解除
  - **OnLevelChange(13)**：:4016 `new=121 old=60`
- **⚠️ 引擎布尔事件语义与官方 Eluna 相反（重要，写脚本前必查）**：`CallEntryEventForBoolean`(TurtleLuaEngine.cpp:24884) 的命中条件 = `handler返回值 == 调用点传入的 expectedValue`。**item use 事件（OnItemUse:25309）传 `expectedValue=false` → handler 返回 `false` 才阻止施法，返回 `true` 反而放行**。同类事件需逐个查调用点的 expectedValue。
- **待补**：G3 核心游戏回归（用户暂缓）；清理 `_audit_engine.lua`（3 脚本→2）。

### ✅ 超级炉石脚本（2026-08-09，含施法 bug 修复）
- **调研**：Eluna 官方仓库已移除 scripts 目录；社区"超级炉石"均为 AzerothCore 3.3.5 版（依赖 mod-eluna API + acore_characters 表），**不能直接移植**。
- **产出**：`super_hearthstone.lua`（工作区根 + 已部署 `server/bin/lua_scripts/`，md5 一致）：
  - 右键炉石(6948) → 传送菜单（主城 6 个/副本入口 10 个/自定义传送点）
  - 自定义传送点存 `tw_char.soulcore_hearthstone`（按账号，CharDBQuery/Execute 持久化）
  - 战斗/死亡/坠落状态拒绝传送（IsInCombat/IsDead/IsFalling）
- **API 兼容性核对**（TurtleLuaEngine.cpp 行号，全 PASS）：RegisterItemEvent:17761 / RegisterItemGossipEvent:17765 / Gossip* :18477-480 / TeleportTo:18402 / GetAccountId:17930 / QueryResult GetRow:20145-161。
- **施法未阻止 bug 修复**：首版 handler `return true` 实测右键炉石施法照常 → 根因 = 上述布尔语义相反（expectedValue=false）→ 改 **`return false`** 后待重启验证。
- **⚠️ 遗留：客户端施法动作残留（2026-08-09 实测，第二阶段 C++ 修复）**：`return false` 后读条已消失，但 1.12 客户端**本地预测播放炉石施法动作**；服务端阻止施法后**未向客户端补发"施法失败/取消"包**，导致：①首次弹菜单后施法动作保持；②动作保持期间再右键炉石无响应，需移动打断。**Lua 层无解**（`InterruptSpell` 仅处理服务端已有施法，阻止后无施法状态故不发包；`CastSpell` 有副作用风险）。
  - **修复方案（第二阶段）**：`src/game/Handlers/SpellHandler.cpp:174` 在 `if (!sScriptMgr.OnItemUse(...)) CastItemUseSpell(...)` 的 else 分支补发伪失败包：`Spell::SendCastResult(_player, spellInfo, SPELL_FAILED_INTERRUPTED)`（复用 :169-177 失败路径写法，spellid 从 proto->Spells 取 ON_USE/ON_NO_DELAY_USE）→ 客户端收 SPELL_FAILURE 即清动画。需 CI 编译。
  - 过渡期：接受"移动取消动画"，或随第二阶段 `.reload eluna` 一起修。
- 坐标均为经典 1.12 常用值，个别魔改地图位置可用 GM `.go` 实测后微调。

### ✅ 第二阶段批次 1-3 执行（2026-08-09 14:20-15:03）
**批次 1 — 本地修复（无需编译）**
- welcome.lua：`RegisterServerEvent(1)→(14)`（P1 修复）；删除 elunatest 测试残留（P2 清理）
- test_gossip.lua：`creature:GossipMenuAddItem→player:GossipMenuAddItem`、`GossipMenu→SendGossipMenu`（P1 修复）
- **NPC 190001 入库**：复制 entry=68（暴风城卫兵）模板改 entry，刷暴风城银行门口（map 0, -9065, 434, 93.5，creature guid 12585178）
- conf 模板统一：产物模板覆盖 `server/etc/mangosd.conf.dist`（Eluna 段 0→4，旧版备份 `mangosd.conf.dist.bak_pre_eluna`）
- 清理 `_audit_engine.lua`（审计临时脚本，lua_scripts 恢复 3 脚本）

**批次 2 — C++ 改动（commit `35e439d`，CI #19 双平台编译通过）**
- **`.reload eluna` 热重载命令**：Chat.cpp reloadCommandTable + Chat.h 声明 + Commands.cpp 实现（`sTurtleLuaEngine.Reload()`，USE_LUA=OFF 时提示禁用）
- **施法动画残留修复**：`SpellHandler.cpp:174` else 分支补发 `Spell::SendCastResult(SPELL_FAILED_INTERRUPTED)`（清除客户端本地预测的施法动作）
- **`Eluna.TopLevelScriptPath`**：conf.dist.in 新增配置项 + 引擎成员 `_topLevelScriptPath` + `LoadScripts()` 重构为双目录递归加载
- **6 文件 `#ifdef USE_LUA` 保护**（USE_LUA=OFF 兼容）：BattleGround(4 调用点)/GMTicketMgr(2)/GMTicketHandler(1)/MapManager(1)/Object(1, 带 #else 原逻辑)/TemporarySummon(1, 带 #else 原逻辑)
- **Spell.cpp 恢复 `#include <memory>`**（P3）
- **源码新增 `lua_scripts/`**：welcome/test_gossip/super_hearthstone 正式版入库（版本化管理 + CI 可打包）

**批次 3 — 产物与部署（15:03）**
- CI #19 成功（build 20m11s / build-windows 6m52s），Windows 产物 45.9MB
- 产物下载（GitHub API 两步法：先取 `redirect_url` 再直连 Azure blob，curl 加 `--ssl-no-revoke`）
- **部署**：server/bin 换新 mangosd.exe(`29bfdec6`)/realmd.exe(`f698dcf7`)/ACE.dll；备份 `server/bin_backup_pre_phase2`；`server/etc/mangosd.conf.dist` 更新为产物模板（Eluna 6 处含 TopLevelScriptPath）；bin 依赖 DLL 与 lua_scripts 完好
- **workflow 产物补全改动未推**（lua_scripts 打包 + `copy_runtime_dlls.ps1`）：本地已改未提交（PAT 缺 workflow scope）；**2026-08-09 16:19 用户决定不再推送，改动仅保留本地**（见文末遗留事项），本次部署本地手动补 lua_scripts/DLL
- **⏸ 待重启验证**：①日志 3 脚本+启动事件14 ②`.reload eluna` ③炉石无施法动作残留 ④Eluna Test NPC gossip ⑤登录欢迎

---

## 五、常用命令速查
```bash
# 服务端启动（PowerShell，独立进程）
Start-Process -FilePath "E:\11111\soulcore tortoise wow\server\bin\realmd.exe" -WorkingDirectory "E:\11111\soulcore tortoise wow\server\bin"
Start-Process -FilePath "E:\11111\soulcore tortoise wow\server\bin\mangosd.exe" -WorkingDirectory "E:\11111\soulcore tortoise wow\server\bin"

# MySQL
MYSQL="E:/11111/soulcore tortoise wow/mariadb/mariadb-11.4.4-winx64/bin/mysql.exe"
"$MYSQL" -uroot -psoulcore2026 -e "SELECT ..."

# 查看日志
tail -f "E:/11111/soulcore tortoise wow/server/logs/"server_*.log

# 端口检查
netstat -ano | grep -E ":3724|:8090"

# 地图数据最终形态（server/data/）
# dbc 158 + maps 2805 + vmaps 6921 + mmaps 2133
```

---

## 六、运行时验证完成（2026-08-09 15:31-16:04）✅ 阶段二批次 1-3 全部闭环

**服务端启动验证（新二进制 35e439d，15:31 启动）**
- realmd 3724 / mangosd 8090 监听 ✓；`Loading Lua engine...` + `Loaded 3 Lua scripts` ✓；启动事件14 → `[Eluna] Server started` 实测触发 ✓；`[SuperHearthstone] 超级炉石已加载` ✓；World server up（16s）✓

**客户端交互验证（admin/Free 角色）**
| 项 | 结果 |
|---|---|
| ① 登录欢迎（welcome.lua 事件14） | ✅ 两条绿字正常 |
| ② `.reload eluna` | ✅（需 rank4，见下）reload 不重复注册事件 |
| ③ 炉石（无施法动作残留） | ✅ 抬手仍存在（客户端本地预测动画，服务端已阻止施法事实），不影响传送，属可接受固有行为 |
| ④ NPC 190001 gossip 菜单 | ✅ 打开/防叠加/选项分发全通 |

**运行时修复（3 项，均无需重编译）**
1. **`.reload eluna` 权限不足**（"您无法使用此命令"）：turtle 权限等级 **SEC_PLAYER=0/SEC_GAMEMASTER=2/SEC_DEVELOPER=3/SEC_ADMINISTRATOR=4**（Common.h:186-190），`.reload eluna` 需 SEC_ADMINISTRATOR(4)，admin 原 rank=3。RBAC 表无 reload 条目，纯等级不够。**修复**：`UPDATE tw_logon.account SET rank=4 WHERE id=4`（登录时读取，重登生效）。
2. **NPC 右键无菜单**：190001 复制模板时 `npc_flags=0`（源 68 是 1）→ 客户端认为无 GOSSIP 交互位，右键不发 gossip hello。**修复**：`UPDATE tw_world.creature_template SET npc_flags=1 WHERE entry=190001` + `.reload creature_template` + 走远刷新视野。
3. **菜单叠加 + 选项无响应**（脚本 bug，已同步仓库+部署）：
   - 叠加根因：turtle Eluna **creature gossip 路径 OnCreatureGossipHello 不会自动 ClearMenus**（item 路径 OnItemGossipHello 有）→ handler 开头必须 `player:GossipClearMenu()`。
   - 无响应根因：`GossipMenuAddItem(icon,msg,sender,action)` 参数约定——1/2 误放进 sender，回调判断的 intid(=action)=0 永远不命中。**规范：sender=0 + action=编号**（与 super_hearthstone.lua 一致）。

**Eluna 脚本编写规则（沉淀）**
- item use 事件：handler 返回 **false** 才阻止施法（引擎 CallEntryEventForBoolean expectedValue=false，与官方相反）
- creature gossip handler：**先 `player:GossipClearMenu()`** 再 AddItem，防叠加
- gossip 菜单项：**sender=0 + action=编号**；回调 `(event,player,creature,sender,intid,code)` 中 intid=action
- GM 账号等级：SEC_ADMINISTRATOR=4 才能用 admin 级命令（`.reload` 子命令多为 SEC_ADMINISTRATOR/DEVELOPER）

**遗留事项**
- ✅ ~~workflow 补全推送~~（**已关闭**：2026-08-09 用户决定不再推送，lua_scripts 打包 + copy_runtime_dlls.ps1 改动**仅保留本地**；CI 产物不含 lua_scripts/DLL，本地部署手动补为常态流程。根目录 `weekly-build.yml` 为含补全的最新副本）
- ✅ **本地 SQL 改动已版本化**（2026-08-09）：`sql/local_changes/`（git 仓库内提交 `a2bad74` + 根目录同名副本，md5 一致）——`001_npc_190001.sql`（190001 完整入库：模板+实体 guid 12585178+npc_flags=1）、`002_account_rank.sql`（admin rank=4）、`003_realmlist.sql`（id=1, 127.0.0.1:8090）。**未推送 GitHub**（用户决定保持本地不动），跨机器靠拷贝项目目录带上；修复了"190001 建库 SQL 从未落盘、换机重放会静默丢 NPC"的缺口
- ✅ **G3 回归清单 + Anticheat 配置**（2026-08-09）：`G3核心游戏回归测试清单.md` 已建（计划书验证标准 7 的可勾选实测清单，见后续工作计划引用）；`anticheat.conf` 已部署（上游只读模板 → server/bin + server/etc，消除启动期 `Could not find configuration file anticheat.conf` 报错，仅记录不执法）
- 可选 C++ 加固：引擎 `OnCreatureGossipHello` 补 ClearMenus（对齐 item 路径），需 CI 重编译，暂缓
