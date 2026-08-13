# SoulCore Tortoise WoW — 精炼知识库总览

> 生成：2026-08-12（基于本目录全部资料精炼）｜ 性质：单页入口，取代散落的 10+ 份状态文档
> 权威依据：`MEMORY.md` + `2026-08-12.md`（2026-08-12 13:29 用户终审「ARPG 全部归档、后续不再应用」）
> 更新：2026-08-13（PlayerBots 分支从「规划稿」推进至阶段 A-D，文档归入 `PlayerBots文档/` 子目录）

---

## 一、项目定位

- **是什么**：Turtle WoW（MaNGOS 系 1.12）私服，已集成 **Eluna Lua 引擎**（基于 WYTurtle 的 TurtleLuaEngine 兼容层），支持用 Lua 脚本加自定义 NPC/事件/GM 命令/热重载，**不改 C++**。
- **上游**：`Penqle/tortoise-wow`（main）；fork `callmefree/soulcore-tortoise-wow`（已含 Eluna 移植 + 27 个自定义 commit）。
- **本工作区 git 仓库**：只跟踪 44 个**文档/lua/sql/yml**（白名单 `.gitignore`），**不含源码、不含二进制、不含客户端/数据库**。源码在 GitHub fork；二进制靠 CI 产物；运行态在 Ubuntu 生产机。
- **本机 `E:\11111\soulcore tortoise wow\` 实际内容**：文档 + 归档 + `客户端/`(11GB，gitignore) + `mariadb/` + `server/`(bin/data/，gitignore) + `sql/`(空，gitignore) + `工具/`。**运行态资产不在这个 git 副本里**。

---

## 二、当前权威状态（2026-08-12 终态）

| 模块 | 状态 | 说明 |
|---|---|---|
| **Eluna 引擎移植** | ✅ 完成并验证 | 编译（CI #19 / 35e439d）+ 部署（Windows + Ubuntu）+ 运行时闭环（G2 门禁 2026-08-09 过） |
| **Ubuntu 生产部署** | ✅ 运行中 | realmd(3724)+mangosd(8090) tmux 常驻；二进制 = CI run #31566426630（d428056，含上游 8-11 同步） |
| **通用 Lua 脚本（3 个）** | ✅ 活跃 | `welcome.lua` / `test_gossip.lua` / `super_hearthstone.lua`（均非 ARPG，保留） |
| **G3 核心游戏回归** | ⏸ **从未执行** | 所有文档均标 pending；prod 已上线但此验证未完成 |
| **ARPG 移植（暗黑3/POE）** | ❌ **已终止/归档** | 2026-08-12 13:29 用户指令「全部归档，后续不再应用」；13:38 服务器 arpg 脚本已清除 |
| **PlayerBots 分支移植** | 🔄 **阶段 A-D 已推进** | 独立分支 + 独立库(3307) + 独立 server 目录；阶段 A-C 门禁通过，阶段 D 独立 CI 双平台×双配置编译验证中（2026-08-13） |

---

## 三、部署拓扑

| 环境 | 角色 | 现状 |
|---|---|---|
| **Ubuntu 22.04.5 @ soulcore.asia:56789** | 生产运行 | 运行中；`/opt/soulcore/server/{bin,data,etc,logs,sql}`；MariaDB 11.4.12；四库已导 |
| **Windows 本机 `E:\11111\...`** | 开发/文档/本地运行 | 完整 server/bin + 客户端 + mariadb 绿色版（但本 git 副本不含二进制） |

- **客户端连接铁律**：`realmlist` 表 `address` 必须写纯 IPv4 `125.110.90.129`（port 8090）。域名 `soulcore.asia` 双栈（IPv6+IPv4）会走 IPv6 失败 → 客户端 `realmlist.wtf` 也写 IP，不可写域名。
- **Ubuntu 启动铁律**：① CI 把 conf 路径硬编码进二进制 → 需符号链接 `ln -sfn /opt/soulcore/server/bin /home/runner/work/soulcore-tortoise-wow/server/etc`；② mangosd 对 stdin EOF 敏感 → 必须用 `tmux` 常驻 pty，不可用 setsid/nohup。
- **C++ 编译只能走 CI**（本地无 VS）：GitHub Actions `weekly-build.yml` 双平台（Linux `build` job 产物 `soulcore-tortoise-wow` artifact；Windows 含 extractor + ACE patch）。

---

## 四、Eluna 引擎通用铁律（可复用，非 ARPG）

> 这些属引擎行为，未来任何 Eluna 脚本都需遵守，已与 ARPG 内容层脱钩保留。

1. **布尔事件语义与官方相反**：`CallEntryEventForBoolean` 按调用点 `expectedValue` 匹配返回值。**item use 事件 expectedValue=false → handler 返回 `false` 才阻止施法，返回 true 反而放行**。写前必查 TurtleLuaEngine.cpp 对应调用点的 expectedValue。
2. **gossip 三规范**：① creature gossip handler 开头必须 `player:GossipClearMenu()`（引擎 OnCreatureGossipHello 不自动清菜单）；② `GossipMenuAddItem(icon,msg,sender,action)` 用 **sender=0 + action=编号**；③ 回调 `(event,player,creature,sender,intid,code)` 中 intid=action。
3. **事件注册**：玩家事件（OnLogin=3/OnChat=18/OnLevelChange=13/OnEquip=29/OnKillCreature=7）用 `RegisterPlayerEvent`，**非** `RegisterServerEvent`。聊天触发词禁点前缀（GM 命令系统拦截）。
4. **🚨 查询游标死循环坑**：`q:GetRow()` 只取当前行、不推进游标；游标靠独立 `q:NextRow()`（返回 boolean）推进。官方 `repeat r=q:GetRow() until not r` 在本引擎 = **加载期死循环卡死 mangosd**。正确遍历：`r=q:GetRow() while r do ... if not q:NextRow() then break end r=q:GetRow() end`。
5. **DB 查询必 pcall**：事件里所有 `CharDBQuery/WorldDBQuery` 必须 pcall 包裹，否则表缺失/异常会崩事件（右键静默无反应）。
6. **不新建 spell**：本项目约束（避免客户端 DBC 补丁=C 级），效果复用现有 26928 条 DBC spell；被动 spell 客户端不显示图标是正常。
7. **权限**：`.reload` 子命令多需 `SEC_ADMINISTRATOR=4`；GM 账号 rank 必须≥4。
8. **Lua 语法检查**：`luac52.exe -p`（Lua 5.2.4）。

---

## 五、活跃资产清单（保留，非 ARPG）

| 文件 | 用途 |
|---|---|
| `部署与Eluna移植工作记录.md` | 部署命根子（全量记录） |
| `soulcore_preset_status.md` | Ubuntu 预置状态报告 |
| `切换电脑交接清单.md` | 换机恢复步骤（注意：部分已过时，见下） |
| `PlayerBots文档/`（5 份） | PlayerBots 分支移植计划书 + StageA/B/C 报告 + 协作手册（独立工作线） |
| `super_hearthstone.lua` | 通用炉石增强（右键传送菜单） |
| `weekly-build.yml` | CI 最新副本（含本地补全，未推 GitHub） |
| `工具/ssh_soulcore.py` | paramiko 强制 IPv4 运维工具（密码不入库） |

---

## 六、已归档 / 终止（ARPG，2026-08-12）

- **位置**：`_archive/ARPG_归档_2026-08-12/`（8 份 md + `素材/` + `工具/gen_*` + `sql_local_changes/` + `lua_scripts_arpg/` 4 个 lua）。
- **内容**：ARPG 系统移植计划书、工作记录、阶段0报告、Eluna 移植计划书/审计/审查报告、G3 回归清单、后续工作计划、暗黑逍遥素材库。
- **终止原因**：阶段 2 词缀/三色球方向用户不满（效果层受 0-6 约束只能复用现有 buff，无法自定义显示）；2026-08-12 13:29 用户指令全部归档、后续不再应用；13:38 服务器 arpg 脚本已清除。
- **⚠️ 归档内文档仍为「待用户重定方向再开」措辞**（13:10 文档对齐快照），与最终「终止不再应用」冲突——以 13:29 终审为准。

---

## 七、进行中：PlayerBots 分支移植（2026-08-12 开工）

- **文档**：`PlayerBots文档/`（计划书 + StageA/B/C 报告 + 协作手册），源码在 `E:\11111\soulcore-playerbots`（独立 git 仓库，`feature/playerbots` 分支）。
- **目标**：把 Shyalya/tortoise-wow `playerbots-integration-gh` 移植进本项目，与 Eluna 共存，验收 1000 bots。
- **硬隔离红线**：独立 `feature/playerbots` 分支（验收前不 merge main）、独立 CI job（不覆盖主线产物）、不碰 3306 生产四库（用 3307 满配参照库）、不碰 `server\bin`（独立目录）。
- **进度**：阶段 A（基线/克隆）✅ → 阶段 B（代码合并）✅ → 阶段 C（Eluna×PlayerBots 共存守卫）✅ → 阶段 D（独立 CI 双平台×双配置 BUILD_PLAYERBOTS）编译验证中（run #31657448607）；参照端 `E:\11111\Twow1181Bots`（1000 bot 已跑通）。

---

## 八、测试凭据速查

- GM 账号：**admin / admin123**（rank=4 = SEC_ADMINISTRATOR）
- 测试角色：**Free**（夜精灵德鲁伊，121 级，联盟）
- 测试 NPC：**190001**「Eluna Test NPC」（暴风城银行门口 -9065,434,93.5，guid 12585178）
- 数据库：root/soulcore2026（3306）；应用账号 mangos/mangos；四库 tw_logon/tw_world/tw_char/tw_logs
- 端口：realmd 3724（客户端连）、mangosd 8090

---

## 九、决策记录（2026-08-12 用户拍板）

1. **ARPG 状态 = 永久终止**（按 13:29 终审）。归档内文档「待重定方向再开」措辞已过时，以「终止不再应用」为准；档案仅作历史留档。
2. **通用 SQL 001-003 保持现状**：NPC 190001 / admin rank4 / realmlist 仍留在 ARPG 归档的 `sql_local_changes/` 内，不单独提回根目录（重部署时从归档取）。
3. **G3 核心回归 = 暂不做**：生产服先跑着，G3 延后。
4. **PlayerBots = 已开工**：2026-08-12 启动 `PlayerBots分支移植计划书.md`（现于 `PlayerBots文档/`），阶段 A-D 已推进，文档归入子目录（2026-08-13）。
5. **文档过时项**：`切换电脑交接清单.md`/`soulcore_preset_status.md` 部分内容已被后续操作覆盖（如 realmlist 127.0.0.1 → 125.110.90.129）；待 PlayerBots 阶段 A 告一段落后再统一修订。
