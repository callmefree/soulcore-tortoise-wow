# ARPG 移植工作记录（Soulcore Turtle WoW 1.12 + Eluna）

> 创建：2026-08-10 ｜ 上游：Penqle/tortoise-wow ｜ 引擎：WYTurtle TurtleLuaEngine（Eluna 兼容层）
> 配套：《ARPG系统移植计划书.md》（主计划）、《素材\阶段0探针报告.md》、《ARPG阶段0落地报告.md》
> **重开会话先读本文件**，然后按"七、重启与恢复"启动环境继续。

---

## 一、当前状态总览（2026-08-10 重开后恢复）

| 项 | 状态 |
|---|---|
| 服务端 | ✅ 运行中（realmd 3724 / mangosd 8090 / MariaDB 3306，mangosd 本次重启加载新脚本） |
| 阶段 0（技术探针） | ✅ **全部完成，门禁通过** |
| 阶段 1（A 级 9 项） | 🔄 **9 项全部开发完成，4 项待游戏内实测**（1-4 符文 / 1-7 重铸 / 1-8 打孔 / 1-9 门控） |
| lua_scripts/arpg/ | **9 个脚本**已部署（city_crier/combine/gate/gem/guide_npc/reforge/rune/socket/travel_vendor） |
| local_changes SQL | **12 个文件（001-003 基建 + 010-017 ARPG，016/017 本轮恢复/新增）** |
| 自定义表（tw_char） | soulcore_arpg_sockets（打孔）、soulcore_hearthstone（炉石）、soulcore_arpg_gate（门控） |
| 版本控制 | ✅ git（HEAD=c06dae8 用户撤回后，本轮改动待提交） |

**本次推进会（2026-08-10 重开）已完成**：
1. **环境恢复**：mangosd 未跑 → 重启加载全部脚本（8090 正常监听，无死循环）；git HEAD=c06dae8（用户已手动撤回推进会运行修改：gate.lua 删/016 删/socket.gem 回退）
2. **死循环根因定位（踩坑#12 实锤）**：TurtleLuaEngine.cpp `QueryGetRow` 只取**当前行**（`result->Fetch()`），游标推进靠独立 `NextRow()` 方法；gate.lua v1 的 `repeat ... until false` 永不推进游标 → 加载阶段即死循环卡死 mangosd。**用户撤回 gate.lua 的判断正确**
3. **016 恢复**：从 git c838f2e 找回 016_phase1_gate.sql → 双重放验证幂等 ✓（905004 远古符文卷轴 + soulcore_arpg_gate 表）
4. **gate.lua v2 安全版**：改用 `GetRow 取行 + NextRow 推进` 正确遍历模式，全部 DB 查询 pcall；luac52 语法检查通过
5. **socket.lua v3**：MAX_HOLES **2→1**（用户确认：每装备仅 1 个扩展宝石槽=槽5，第 2 孔无槽浪费）+ CharDBExecute 补 pcall
6. **1-7 重铸开发（新发现调整）**：itemset 表实为**空表**（0 行，Turtle 1.12 无数据）→ 改用 `item_template.set_id`（2070 件）同套互查方案；017 SQL（904003 混沌重铸石，临时表复制模板 7910，双重放幂等 ✓）+ reforge.lua（背包扫描→列套装部件→同套随机转换**优先同部位**，5% 湮灭，全 pcall）
7. **全量语法验证**：12 个 Lua 脚本 luac52 -p 全部 OK

---

## 二、阶段 1 逐项状态（9 项）

| # | 系统 | 状态 | 关键实现 | 遗留 |
|---|---|---|---|---|
| 1-1 | 新手引导（艾薇儿 190101） | ✅ 通过 | gossip 菜单：领随身商贩技能书/玩法介绍；暴风城银行门口(-9066,433)，display 1267 女性人类 | — |
| 1-2 | 随身小伙伴（905001） | ✅ 通过 | 右键技能书 → SummonCreature 190105 面前 3 码，90 秒消失；item use return false 阻止 | — |
| 1-3 | 主城喊话 | ✅ 通过 | CreateLuaEvent(30s 后, 每 4 分钟) + SendWorldMessage 台词池随机 | — |
| 1-4 | 1-33 号符文（900001-900033） | 🔄 **待终测** | rune.lua v2：右键 → 菜单选装备 → SetEnchantment **槽4**（PROP_SLOT_1，与宝石槽3/槽5共存）；**主菜单直接列出带符文部位可取下** | 已静态审查（逻辑自洽）；需 .reload eluna 后重测（含取下/返还） |
| 1-5 | 四色宝石（901001-901020） | ✅ 通过 | gem.lua v3.1：右键 → gossip 菜单选装备镶嵌/取下返还；槽3 基础 + 槽5 打孔扩展；同色限 2 | 注释已清理（v3.1），槽位定稿 |
| 1-6 | 宝石合成链（905002/905003） | ✅ 通过 | 3 书页→1 书；书→随机 1 级宝石 | 3 合 1 宝石升级二期 |
| 1-7 | 套装重铸（904003） | 🔄 **开发完成待实测** | reforge.lua：右键 → 列背包带 set_id 的套装部件 → 选中 → 查同 set_id 其他部件**优先同部位** → 随机转换（5% 湮灭）；**itemset 表为空，改按 item_template.set_id 互查** | 017 SQL 双重放 ✓；luac52 ✓；待游戏内实测（测试素材：47162-47167 Earthshatter / 70542-70545 Avenger's） |
| 1-8 | 拉玛兰迪打孔器（905010） | 🔄 **待实测** | socket.lua v3：右键 → 选装备 → tw_char.soulcore_arpg_sockets 记录 holes → 宝石槽+1（gem.lua 读取，扩展槽=槽5） | **MAX_HOLES=1 已定**（槽5 只有 1 个）；CharDBExecute 已补 pcall；待游戏内实测 |
| 1-9 | 符文门控（905004 远古符文卷轴） | 🔄 **开发完成待实测** | gate.lua v2（安全版）：GetRow+NextRow 正确遍历 + 全 pcall；需持 900030（Ber）→ 激活消耗卷轴 + 随机 1 级宝石；无符文拒绝不消耗 | 016 双重放 ✓；死循环根因已修；待游戏内实测 |

**阶段 1 门禁**：9 项全 ✅ + .reload eluna 无报错 + 日志 0 新增 ERROR（**待 4 项游戏内实测**：1-4 / 1-7 / 1-8 / 1-9）

---

## 三、关键机制与 API（写脚本直接查）

### 槽位分工（防冲突，已定稿）
| 槽 | 用途 | 说明 |
|---|---|---|
| 3 (PROP_SLOT_0) | 宝石基础槽 | 每装备 1 个 |
| 4 (PROP_SLOT_1) | 符文槽 | 每装备 1 个，与宝石共存 |
| 5 (PROP_SLOT_2) | 宝石扩展槽 | 打孔后可用（socket.lua 记录） |

### 常用 Eluna API（TurtleLuaEngine.cpp 行号）
- `RegisterPlayerEvent`：OnLogin=3 / OnChat=18（**玩家事件**，勿用 RegisterServerEvent）
- `RegisterItemEvent(entry, 2, fn)` / `RegisterItemGossipEvent(entry, 2, fn)`：item use + item gossip（可同时注册，炉石同款）
- item gossip 回调 `(event, player, item, sender, action, code)`；菜单用 `player:GossipSendMenu(1, item)`
- `Item:SetEnchantment(enchant, slot)` :12344 / `GetEnchantmentId(slot)` :12150 / `ClearEnchantment(slot)` :12367
- `Unit:AddAura(spellId)` :9443；`SummonCreature(entry,x,y,z,o,type=1,ms)` :11224（type 1=TIMED_OR_DEAD_DESPAWN）
- `CreateLuaEvent(fn, ms, repeats)` :2074（repeats=0 无限）；`SendWorldMessage(msg)` :2796
- `GetEquippedItemBySlot(0-18)` / `GetItemCount` / `RemoveItem` / `AddItem` / `HasItem`
- `CharDBQuery/CharDBExecute/WorldDBQuery/WorldDBExecute`（全局）

### 事件注册铁律
- 玩家事件用 RegisterPlayerEvent（OnLogin=3/OnChat=18/OnLevelChange=13）
- 聊天触发词禁点前缀（GM 命令系统拦截）
- item use **返回 false 才阻止施法**（本引擎布尔语义与官方相反）
- **事件里所有 DB 查询必须 pcall 包裹**（表缺失/查询异常会崩事件 → 右键静默无反应）

---

## 四、踩坑记录（本阶段新增，勿重踩）

1. **item 无使用法术 → 客户端右键不触发**：spellid_1=0 时客户端不认为可"使用"。必须给可右键物品配一个现有法术（如 8690 炉石）作载体，脚本 return false 阻止。
2. **客户端缓存物品定义**：改物品模板后需**小退重登**（客户端才重新拉取，否则右键无动作）。
3. **SQL 改表后服务端内存不刷新**：.reload eluna 只管 Lua；item_template/creature 需 `.reload item_template`/`.reload creature_template` 或重启。
4. **mysql 客户端脚本中途报错停止后续**：014 的 `||`（MySQL 是逻辑或）导致整个文件后半段（CREATE TABLE）没执行 → 打孔表缺失 → 宝石事件崩。**重要 DDL 单独执行或放文件开头**。
5. **复杂数据生成用 Python 脚本**（gen_runes.py）：SQL JOIN+UNION 生成 33 条易列数不匹配。
6. **Eluna DB 查询必须 pcall**：gem.lua v3 查不存在的表直接抛错崩事件（右键无反应），已全部加防御。
7. gossip 菜单：creature gossip 需 GossipClearMenu 防叠加；item gossip 用 GossipSendMenu(1, item)。
8. **全列 INSERT/REPLACE 严禁手写**：014 v1/v2 手写 130 列 SELECT 实际是 **137 列**（多 7 列，且 mysql 客户端遇错即停 → 后续 DDL 全没跑）。永远用生成器（gen_runes.py 类）产出 → mysqldump 固化 → 重放验证。**014 v3 已按此重做并双重放验证**。
9. **打孔数 ≠ 宝石槽数**：socket.lua 原 MAX_HOLES=2（可打 2 孔），但装备只有 1 个扩展宝石槽（槽5，槽4 归符文）→ 第 2 孔无槽可用纯浪费打孔器。**打孔上限 = 可用扩展槽数**，已改 1。
10. **套装表名是 `itemset` 不是 `item_set`**（Turtle 1.12）：查表前先 SHOW TABLES 确认，别按官方文档的名字猜。**且本服 itemset 是空表（0 行）**，套装互查直接走 `item_template.set_id`（2070 件）。
11. **造新物品的正解 = 临时表复制模板**：`CREATE TEMPORARY TABLE _t AS SELECT * FROM item_template WHERE entry=模板;` → `UPDATE _t SET entry=新号, name=..., ...` → `REPLACE INTO item_template SELECT * FROM _t;` → DROP。**不手写 130 列**（016 已验证双重放幂等）。
12. **🚨 GetRow 不推进游标 = 死循环（推进会事故根因，已实锤）**：TurtleLuaEngine.cpp `QueryGetRow` 每次返回 `result->Fetch()` 的**当前行**；游标推进靠独立方法 **`NextRow()`**（返回 boolean）。官方 Eluna 惯用法 `repeat r=q:GetRow() until not r` 在本引擎**永不退出**（永远取第 1 行）→ 加载阶段死循环卡死 mangosd（gate.lua v1 事故）。**正确遍历模式**：
    ```lua
    local r = q:GetRow()          -- 首行（空表= nil）
    while r do
        ...处理 r...
        if not q:NextRow() then break end   -- 推进；false=无下一行
        r = q:GetRow()
    end
    ```
    **单行查询**（WHERE 主键/唯一条件）只用一次 GetRow 取首行即可，安全。gem/socket/reforge 已按此规范。
13. **Lua 语法检查用 luac52**：`luac52.exe -p file.lua`（LuaBinaries 5.2.4，本机已下载 /tmp/lua52/）。改动脚本后必查，防加载期语法错。
14. **Start-Process -RedirectStandardOutput 与 -WorkingDirectory 同用时 PATH 冲突报错**（PowerShell "已添加项"）：需要重定向时先设环境变量或用 cmd 方式，普通启动不用重定向。

---

## 五、数据资产清单

### SQL（sql/local_changes/，按序重放，README.md 有完整命令）
| 文件 | 内容 |
|---|---|
| 001-003 | 基建（NPC 190001 / admin rank4 / realmlist） |
| 010_id_registry.sql | ARPG ID 段登记（锁段） |
| 011_phase0_probes.sql | 探针测试：词缀池 9001→IRP117 + 测试紫装 950001（保留） |
| 012_phase1_guide_vendor.sql | 905001 技能书 / 190105 随身商贩(+15货) / 190101 艾薇儿 |
| 013_phase1_gems.sql | 四色宝石 901001-901020 + 书页 905002/书 905003 |
| 014_phase1_rune_punch.sql | 符文 900001-900033 + 905010 打孔器（v3：gen_runes.py 数据固化导出，已验证可重放，幂等） |
| 016_phase1_gate.sql | 905004 远古符文卷轴 + tw_char.soulcore_arpg_gate 门控配置表（**git c838f2e 找回，本轮重新验证双重放幂等**） |
| 017_phase1_reforge.sql | 904003 混沌重铸石（**本轮新建**，临时表复制模板 7910，双重放验证幂等） |

> ⚠️ 015（打孔 DDL）已随用户撤回删除：soulcore_arpg_sockets 表推进会前已在库（保留），不依赖 015 文件。

### Lua（server/bin/lua_scripts/）
- 正式 3 个：welcome / test_gossip / super_hearthstone
- arpg/ **9 个**：city_crier / combine / gate(v2 安全版) / gem(v3) / guide_npc / reforge(1-7 新建) / rune(v2) / socket(v3) / travel_vendor

### 工具（工具/）
- gen_equip_sql.py（远古/太古生成，已验证）
- gen_runes.py（符文 33 条生成，含 905010）
- gen_equip_test.sql（样例：910647/920647/910809/920809/910811/920811 已入库）

### 物品 ID 段（已用）
900001-900033 符文 / 901001-901020 四色宝石 / 904003 混沌重铸石（1-7）/ 905001 技能书 / 905002 书页 / 905003 书 / 905004 远古符文卷轴（门控演示）/ 905010 打孔器 / 950001 测试紫装 / 910xxx/920xxx 远古太古样例 / NPC 190101 艾薇儿 / 190105 随身商贩

### 已入库测试数据
- 910647/920647（命运 远古/太古）、910809/920809、910811/920811
- 950001 测试紫装（random_property=9001 → "of Twain" 双词缀）
- 词缀池 item_enchantment_template 9001 → IRP 117

---

## 六、下一步工作

### 立即（阶段 1 收尾 —— 4 项游戏内实测，测前 `.reload eluna`）
1. **实测 1-4 符文**（rune.lua v2）：
   - `.additem 900001`（El 力量+1）、`.additem 900002` → 右键符文 → 菜单选"镶嵌到 XX" → 属性面板 +1
   - 右键另一符文 → **主菜单直列"取下 XX 的符文"** → 取下 → 符文返还 + 附魔消失
   - 共存验证：先镶宝石（`.additem 901001` 槽3）再镶符文（槽4），两附魔都在
2. **实测 1-8 打孔器**（socket.lua v3）：
   - `.additem 905010` → 右键 → 列表出现装备（当前 1/2 槽）→ 打孔 → 消耗 1 打孔器 + holes=1
   - 再用宝石右键 → 该装备出现槽5 → 镶第 2 颗宝石 → 属性叠加
   - 重登后双宝石仍在（持久性）；打孔后菜单显示 2/2 槽
3. **实测 1-9 符文门控**（gate.lua v2）：
   - 无符文：`.additem 905004` → 右键 → 拒绝提示"需要持有符文：Ber"，卷轴不消耗
   - 持符文：`.additem 900030` → 再右键卷轴 → 激活成功 → 卷轴 -1 + 随机 1 级宝石
4. **实测 1-7 套装重铸**（reforge.lua）：
   - `.additem 904003` ×2~3、`.additem 47162`（Earthshatter Crown，set 671）→ 右键重铸石 → 列表出现"重铸 Earthshatter Crown（套装 671）" → 选中 → 随机转成同套其他部件（优先同部位）
   - 多测几次看 5% 失败湮灭是否出现（概率低，可接受不触发）
5. 9 项全过后更新阶段 1 门禁 → 计划书勾选 → git 提交推进记录 → 进阶段 2

### 后续
- 阶段 2（B 级 9 项）：2a 词缀（复用 IRP 复合条目）/ 2b 三色球 / 2c 通货+远古太古（复用 gen_equip_sql.py）/ 2d 红装 / 2e 传奇宝石 / 2f 诅咒宝石 / 2g 副本门控 / 2h 赫拉迪克方块 / 2i 全职业宠物
- 阶段 3：掉落整合 / 数值平衡 / G3 回归补测

---

## 七、重启与恢复（换机/重开会话）

```bash
# 1. 启动 MariaDB（3306，root/soulcore2026）
"E:\11111\soulcore tortoise wow\mariadb\mariadb-11.4.4-winx64\bin\mariadbd.exe" --console --port=3306

# 2. 启动服务端（PowerShell，独立进程）
Start-Process -FilePath "E:\11111\soulcore tortoise wow\server\bin\realmd.exe" -WorkingDirectory "E:\11111\soulcore tortoise wow\server\bin"
Start-Process -FilePath "E:\11111\soulcore tortoise wow\server\bin\mangosd.exe" -WorkingDirectory "E:\11111\soulcore tortoise wow\server\bin"

# 3. 验证
#    日志: [Lua] Loaded 10 Lua scripts（3 正式 + 7 arpg）
#    测试角色 Free（GM admin/admin123 rank4）
#    常用: .reload eluna / .reload item_template / .reload creature_template
```

**重开会话后立即检查**：
- [ ] 服务端/DB 是否在跑（netstat 3724/8090/3306）
- [ ] lua_scripts/arpg/ 7 个脚本是否完整
- [ ] 阶段 1 遗留测试项（1-4 符文终测 / 1-8 打孔实测）是否已完成
- [ ] 最新日志无 Lua ERROR

---

_维护：每完成一项更新"二、阶段 1 逐项状态"；新踩坑追加"四、踩坑记录"；SQL/lua 变更同步"五、数据资产清单"。_
