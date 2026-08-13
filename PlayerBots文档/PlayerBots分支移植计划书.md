# PlayerBots 分支移植计划书（Shyalya 移植 → Soulcore Turtle WoW + Eluna）

> 状态：**规划稿**（2026-08-10）｜ 主线：ARPG 阶段 0 ｜ 本任务为**独立分支任务**，全程不干扰主线
> 参照物：`E:\11111\Twow1181Bots`（别人整合落地的 Shyalya 服务端，已跑通 1000 机器人，仅作参照不并入本项目）

---

## 〇、定位与红线（本计划书的核心约束）

本任务以**独立 git 分支 + 独立验证环境**推进，验收全绿前不触碰主线任何资产。四条硬隔离：

| 隔离维度 | 红线 |
|---|---|
| **git 分支** | 在 `feature/playerbots` 分支上开发，验收前**不 merge main** |
| **CI** | 独立 workflow（或 weekly-build 加独立 job），只编译验证 bot 分支，**不覆盖主线产物** |
| **数据库** | **不碰** 3306 生产四库（tw_logon/world/char/logs）；运行时验证用 Twow1181Bots 的 3307 满配库 |
| **运行目录** | **不碰** `server\bin`（主线在用）；bot 分支产物装独立目录或复用 Twow1181Bots 的 server |

**冲突时优先级**：主线（ARPG 阶段 0）> 本分支。本分支任何一步与主线抢资源（端口/数据库/时间），一律本分支让路、暂停等待。

---

## 一、目标

把 Shyalya/tortoise-wow（`playerbots-integration-gh` 分支）的完整 playerbots 移植接入我们项目（Eluna fork），**与 Eluna 引擎共存**，最终可在测试服上线 N 个机器人（验收规模 1000，参考参照端），且不破坏现有 Eluna 功能与 ARPG 内容。

**明确不做**：不提交上游 PR、不做代码重构、不做 bot AI 行为深改（仅修"能跑"层面）、不并入主线生产运行（除非用户另行决定）。

---

## 二、方案决策（已定）与现状依据（实测）

### 2.1 移植源与方式
- **源**：Shyalya/tortoise-wow `playerbots-integration-gh`（198 commits，领先上游 5/落后 5）——已把 ike3 playerbots（cmangos 系）经 39KB shim 层移植到 tortoise 并 1000 机器人实测
- **方式**：不 cherry-pick 198 个 commits，直接以 **diff 级 3-way merge** 接入（模块 1017 文件纯拷贝 + 宿主 ~100 文件手工合并）
- **构建开关**：`-DBUILD_PLAYERBOTS=ON/OFF`，OFF 时 PlayerbotStubs.cpp 占位 → **可渐进引入，不破坏现有构建**

### 2.2 冲突面（已实测，47MB diff 交集统计）
- **32 个文件需手工合并** = 30×`src/game` + 顶层 `CMakeLists.txt` + `src/mangosd/mangosd.conf.dist.in`
- 深度合并约 10 个：`ScriptMgr.h`、`Player.cpp/.h`、`World.cpp`、`Unit.cpp`、`ObjectMgr.cpp/.h`、`Spell.cpp`、`Chat.cpp`、`WorldSession.cpp`、`Map.cpp/.h`
- 其余冲突为插入点式小改动，3-way merge 可消化大半
- 上游自带 petbot 骨架（`PlayerBots/PlayerBotAI.*` 等 4 文件）会被 Shyalya 删除替换 → 按他的整体方案处理

### 2.3 Eluna 共存预检（已实测）
- ✅ `TurtleLuaEngine.cpp/.h` **零处引用 PlayerBot API** → 引擎本体无直接冲突
- ⚠️ `Player.cpp`、`World.cpp`、`WorldSession.cpp` 引用 PlayerBotMgr/PlayerBotAI（上游骨架调用点）→ 已计入 32 冲突文件
- ⚠️ 最大不确定性：bot 会话是否触发 Eluna OnLogin/OnChat 等事件造成噪音 → **阶段 C 专项验证**

### 2.4 参照端可用资产（Twow1181Bots，实测确认）
- **战斗崩溃修复样板**：`PlayerbotAIConfig.cpp` 修补版（OpenLogFile 的 fopen 未判空 → 补 `if(!file) return false`）→ 阶段 B 直接采用，省一次崩溃排查
- **满配数据库**：3307 四库，1000 bots 已建号（characters 1.66MB、random_bots 8MB、equip_cache 36MB）→ 阶段 E/F 直接复用做运行时验证
- **部署坑点手册**：`compile-guide.md`（migrations 手动标记防 AutoUpdate 重放、realmflags=0、DataDir="."、bot 表仅 world+classic 目录）
- **调优配置参考**：aiplayerbot.conf 5 处改动（AutoJoinBG=1、MinLevel=1、DisableActivityPriorities=0、botActiveAlone=10、EnableActionLog=0）

---

## 三、总体路线图（7 个阶段，依赖递进）

```
A 基线准备与分支建立 → B 代码合并（32 冲突） → C Eluna 共存专项
→ D 构建与 CI → E 数据库与配置 → F 实测验收（渐进） → G 收尾决策
```

每阶段独立门禁：**验收不过，停在本阶段，不进入下一阶段**。阶段 A~D 可与主线并行（不占端口/库），E/F 需与主线错峰（会起独立测试服进程）。

---

## 四、阶段详解（每阶段含任务清单 + 验收标准）

### 阶段 A：基线准备与分支建立（0.5 天）
任务：
1. 恢复源码 git 库：clone `callmefree/soulcore-tortoise-wow` 到独立目录（如 `E:\11111\soulcore-playerbots`），或从 `_audit\soulcore` 快照恢复当前 main 状态
2. 添加双 remote：`shyalya` → `https://github.com/Shyalya/tortoise-wow`；`upstream` → Penqle（当前 main）
3. 先同步上游 main（我们落后 23 commits）→ 产生 `chore/sync-upstream` 一次性同步，与主线提交解耦
4. 从同步后的 main 分叉 `feature/playerbots`
5. fetch `shyalya/playerbots-integration-gh` 到本地 ref（不合并）

**验收**：`git log --oneline feature/playerbots` 清晰、双 remote 可 fetch；写 `git merge-tree` dry-run 报告，统计实际冲突块数（预计 32 文件 / ~200 冲突块）

### 阶段 B：代码合并（1.5~2 天，核心工作量）
任务：
1. 先应用**模块层**：`src/modules/PlayerBots/` 1017 文件纯拷贝（含 cmangos-compat-shim.h、stubs、botpch、sql）
2. **宿主层 3-way merge**：以"上游 main + Shyalya bot 改动"为基准，合入我们的 Eluna 改动，按冲突清单逐文件解（见附录 A）
3. 顺序建议：先易后难——CMakeLists/conf 类 → 插入点类（Chat/Channel/Group/NPCHandler/MovementHandler 等）→ 深度类（ScriptMgr.h、Player.cpp、World.cpp、Unit.cpp、ObjectMgr）
4. **直接采用参照端修复**：`PlayerbotAIConfig.cpp` 用 Twow1181Bots 的修补版（fopen 判空）
5. 处理 petbot 骨架：按 Shyalya 方案删除 `PlayerBots/PlayerBotAI.*`、`PlayerBotMgr.*`，确认无残留调用

**验收**：全量 `git diff --stat` 与 Shyalya 基线一致（模块层无遗漏）；Eluna 侧改动全部保留（diff 对照）；本阶段不要求编译通过（那是 D 的事），但**不允许有任何未决 TODO/注释掉的代码**

### 阶段 C：Eluna × PlayerBots 共存专项（1 天）
任务：
1. **ScriptMgr.h 深度合并复查**：Eluna hooks 与 bot hooks 共存，确认无重定义/签名冲突
2. **事件隔离验证**（静态）：读 PlayerBot 会话代码，确认 bot 会话不会触发 Eluna OnLogin(3)/OnChat(18)/OnLevelChange(13) 等玩家事件；如有，加会话类型判断过滤（`IS_PLAYER_GUID` 或 bot 会话标记）
3. **reload eluna 兼容**：bot 在线时 `.reload eluna` 不崩
4. 检查 bot 生成的角色对 `lua_scripts/` 现有脚本（welcome/super_hearthstone/test_gossip）无副作用

**验收（门禁）**：静态审查通过 + 阶段 D 编译后跑最小实测（见 F 的 20-bot 规模）验证 OnLogin 事件不因 bot 刷屏、Eluna 脚本功能正常

### 阶段 D：构建与 CI（0.5~1 天）
任务：
1. 本地（或参照端方式）Windows Release 编译：`cmake -B build -A x64 -DBUILD_PLAYERBOTS=ON -DUSE_EXTRACTORS=ON -DACE_ROOT=... -DBOOST_ROOT=...`
2. 双配置验证：`ON`（bot 版）/ `OFF`（纯 Eluna 版）都能编译——证明开关可逆、不破坏主线构建链
3. 独立 CI workflow：`playerbots-branch-build.yml`（Linux/Windows 矩阵，参照 weekly-build.yml 结构，vcpkg ACE patch 流程沿用），产物**命名加 `-pb` 后缀**，不覆盖主线 artifact

**验收（门禁）**：双配置本地编译通过 + CI 双平台绿。这是本计划最大的技术风险关口，若编译失败，回到 B/C 修，不计入 D

### 阶段 E：数据库与配置（0.5 天）
任务：
1. **迁移脚本盘点**：Shyalya diff 中 38 个 sql 文件分类——bot 专用表（`src/modules/PlayerBots/sql/`）vs 上游同步（base/database_updates）
2. **测试库准备**：优先复用 Twow1181Bots 的 3307 满配库（零成本）；如需自建，按其 compile-guide 流程（base 186 + migrations 手动标记 + bot 表仅 world/classic）
3. 配置准备：`aiplayerbot.conf`（参照端 5 处调优先抄，规模参数按测试计划改）、`mangosd.conf` 四库连接指向测试库
4. realmlist 条目：独立测试 realm（`SoulCore-Bots`，端口错峰如 8091），realmflags=0

**验收**：mangosd 启动报错清零；`ai_playerbot_*` 表齐全；用参照端库时验证 1000 bots 数据可被新编译的 mangosd 读取

### 阶段 F：实测验收（1~2 天，需与主线错峰）
任务（渐进规模）：
1. **20 bots 冒烟**：登录欢迎/炉石/190001 gossip（Eluna 脚本）+ bot 召唤/跟随/进组命令全链路
2. **200 bots 稳定性**：跑 2h 无崩溃；`%` 名字日志问题、战场排队 mutex 等已知 bug 不复发
3. **1000 bots 满配**（用参照端库）：验证 Shyalya 已修的运行期 bug（反作弊空指针、治疗距离、目标缓存）不回归；**重点验证 bot 与 Eluna 事件共存**（阶段 C 门禁复核）
4. **与 ARPG 内容共存抽测**：加载一个阶段 0 产出（如测试紫装 950001 词缀），确认 bot 环境无冲突
5. G3 核心回归（抽查，不跑全量——全量留主线做）

**验收（总门禁）**：1000 bots 稳定运行 ≥2h、Eluna 3 个既有脚本功能正常、无新崩溃/Assertion、性能可接受（CPU/内存记录在案）

### 阶段 G：收尾决策（0.5 天）
任务：汇总全部证据（编译/CI/实测/共存结论），产出《PlayerBots 移植验收报告》，给用户三选一：
1. **合入主线**（走正式 review + 全量 G3 回归后 merge main）
2. **保持独立分支**（留作测试服，定期随上游同步）
3. **归档废弃**（记录结论，分支冻结）

---

## 五、测试方法论（统一验证手段）

沿用项目既有规范（与 ARPG 阶段 0 测试规范同源）：
- 每个验收项必须**游戏内实测**（GM 账号 admin，测试角色独立建号，不污染主线角色）
- 错误隔离：任何 Lua/bot 异常先 pcall 隔离，不重启大法
- 日志留存：每次实测保留 `logs/` 关键段（bot 相关 + mangosd 错误），写进阶段报告
- **不干扰主线**：测试服端口 8091/3725（与主线 8090/3724 错开）；测试库 3307；测试进程独立启动/关闭

---

## 六、风险与对策

| # | 风险 | 等级 | 对策 |
|---|---|---|---|
| 1 | Eluna × PlayerBots 事件冲突（最大不确定） | 高 | 阶段 C 静态审查 + F 的 20-bot 冒烟先行；预案：bot 会话拦截 Eluna 玩家事件 |
| 2 | 32 文件合并出隐蔽逻辑冲突（编译过但运行错） | 高 | 按"先易后难"顺序合；每文件合完对照双方 diff 复核；F 渐进规模兜底 |
| 3 | 编译失败（shim/PCH/C++17 兼容） | 中 | 阶段 D 双配置验证；参照 Twow1181Bots 的 vcpkg 库清单（ACE+10 个 Boost，禁全量 boost） |
| 4 | 上游继续漂移（我们 23、Shyalya 5 落后） | 中 | 阶段 A 一次性同步；合并期间冻结上游 sync，验收后再跟 |
| 5 | bot 大规模性能压力 | 中 | 参照端已验证 1000 可行；我们机器同配置，F 阶段实测记录 |
| 6 | 数据库迁移误伤主线库 | 低 | 硬隔离：只碰 3307/独立测试库，3306 生产库只读连接 |
| 7 | 许可证（AGPL-3.0 新代码） | 低 | 私服自用无分发问题；如未来公开，按 AGPL 合规处理 |

---

## 七、工作量与里程碑（粗估）

| 阶段 | 工作量 | 里程碑 |
|---|---|---|
| A 基线 | 0.5 天 | 分支建立 + dry-run 冲突报告 |
| B 合并 | 1.5~2 天 | 32 冲突全解，模块层无遗漏 |
| C 共存专项 | 1 天 | 静态审查通过（门禁） |
| D 构建 CI | 0.5~1 天 | 双配置编译 + CI 绿（门禁） |
| E 数据库配置 | 0.5 天 | 测试服可启动 |
| F 实测验收 | 1~2 天 | 1000 bots 稳定 ≥2h（总门禁） |
| G 收尾 | 0.5 天 | 验收报告 + 三选一决策 |

**合计约 5.5~7 天**（分散在主线间隙推进，不与 ARPG 阶段 0 并行抢人）。参照端（Twow1181Bots）已验证全部技术难点可解，本计划主要成本是"合并工程"而非"技术攻关"。

---

## 附录 A：32 个冲突文件清单（实测交集）

**src/game（30）**：
`BattleGround.cpp`、`CMakeLists.txt`、`Chat/Channel.cpp/.h`、`Chat/Chat.cpp/.h`、`Database/DBCStructure.h`、`Group/Group.cpp`、`GuildBank/GuildBank.cpp`、`Handlers/CharacterHandler.cpp`、`Handlers/ChatHandler.cpp`、`Handlers/MovementHandler.cpp`、`Handlers/NPCHandler.cpp`、`Maps/Map.cpp/.h`、`ObjectMgr.cpp/.h`、`Objects/Creature.cpp/.h`、`Objects/GameObject.cpp/.h`、`Objects/Object.cpp`、`Objects/Pet.cpp`、`Objects/Player.cpp/.h`、`Objects/Unit.cpp`、`ScriptMgr.h`、`Spells/Spell.cpp`、`World.cpp`、`WorldSession.cpp`

**非 game（2）**：顶层 `CMakeLists.txt`、`src/mangosd/mangosd.conf.dist.in`

> 深度合并约 10 个（加粗者）：ScriptMgr.h、Player.cpp/.h、World.cpp、Unit.cpp、ObjectMgr.cpp/.h、Spell.cpp、Chat.cpp、WorldSession.cpp、Map.cpp/.h

---

## 附录 B：参照物资料索引

| 资源 | 位置 | 用途 |
|---|---|---|
| Shyalya 仓库 | `github.com/Shyalya/tortoise-wow` @ `playerbots-integration-gh` | 移植源 |
| 整合端服务端 | `E:\11111\Twow1181Bots\server` | 满配库/修复样板/运行参照 |
| 编译部署手册 | `E:\11111\Twow1181Bots\server\compile-guide.md` | 坑点全集 |
| 战斗崩溃修复 | `E:\11111\Twow1181Bots\server\PlayerbotAIConfig.cpp` | 阶段 B 直接采用 |
| 调优配置 | `E:\11111\Twow1181Bots\server\aiplayerbot.conf` | 阶段 E 参考 |
| 上游 | `Penqle/tortoise-wow` main | 基线同步 |
| 我方 fork | `callmefree/soulcore-tortoise-wow` main | 主线（含 Eluna） |
