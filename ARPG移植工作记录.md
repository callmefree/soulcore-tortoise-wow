# ARPG 移植工作记录（Soulcore Turtle WoW 1.12 + Eluna）

> 创建：2026-08-10 ｜ 上游：Penqle/tortoise-wow ｜ 引擎：WYTurtle TurtleLuaEngine（Eluna 兼容层）
> 配套：《ARPG系统移植计划书.md》（主计划）、《素材\阶段0探针报告.md》、《ARPG阶段0落地报告.md》
> **重开会话先读本文件**，然后按"七、重启与恢复"启动环境继续。

---

## 一、当前状态总览（2026-08-12 更新）

| 项 | 状态 |
|---|---|
| 服务端 | ✅ **Ubuntu 运行中**（realmd 3724 + mangosd 8090，tmux 会话；MariaDB 3306 本机） |
| 阶段 0（技术探针） | ✅ **全部完成，门禁通过** |
| 阶段 1（A 级） | ✅ **门禁关闭（2026-08-12）**：1-1/1-2/1-3 + 1-7 重铸全部实测通过；5 项砍除（2026-08-11 决策） |
| 阶段 2（B 级） | ⏸️ **曾开工后全部撤销（2026-08-12），待用户重定方向**（详见"二、阶段 2 尝试与撤销记录"） |
| lua_scripts/arpg/ | **4 个脚本**（city_crier/guide_npc/reforge/travel_vendor） |
| local_changes SQL | **7 个文件（001-003 基建 + 010-012 + 017；013/014/016/018 移入 _deprecated/）** |
| 自定义表（tw_char） | soulcore_hearthstone（炉石）；soulcore_arpg_sockets/gate（阶段 1 遗留，未用） |
| 版本控制 | ✅ git（HEAD=**de056e2** = 阶段 1 完成点；阶段 2 提交已回退） |

---

## 二、阶段 2 尝试与撤销记录（2026-08-12，重要教训）

**历程**（用户指令"推进到阶段 2"→ 2a 词缀 → 2b 三色球 → 用户撤销全部）：

1. **2a 原生词缀（020）**：random_property=池9100（60 条现成复合 IRP）挂 1764 件紫装。实测通过（词缀显示/随机/持久）但用户不满：**英文/无后缀名、组合固定、绑死 ItemRandomProperties.dbc** → 撤销。
2. **独立词缀库 v1/v2（021+affix.lua）**：自建词缀表（中文名/权重）+ 首次穿戴 roll + AddAura 生效。用户反馈"**词缀没在装备上显示**"（tooltip 无）→ 改附魔方案。
3. **附魔方案 v3/v4**：SetEnchantment 打 PROP 槽（槽3前缀/槽4后缀），tooltip 显示效果文字。用户反馈"**属性还是原来的/暴击率无效**" → 根因：**原版属性附魔全是 passive+HIDDEN_CLIENTSIDE，服务端生效但客户端面板不显示**。
4. **v5**：改用客户端可见 buff aura（23964 暴击+10/12966 攻速+10 等）。用户点破"**调用的还是系统原有的 buff**" → 效果层受 0-6 约束（不新建 spell）只能复用现有 buff。
5. **用户决策：撤销阶段 2 全部改动**（2026-08-12 13:02）。

**已执行撤销**：affix.lua/balls.lua 删除、soulcore_arpg_affix（tw_world）/soulcore_arpg_item_affix（tw_char）删表、020 回滚（random_property=9100→0）、git reset --hard de056e2、服务恢复 Loaded 7 脚本。

**核心认知（再开阶段 2 前必读）**：
- **0-6 约束是效果层天花板**：不新建 spell（避免客户端 DBC 补丁）→ 词缀/球效果只能复用现有 buff；"效果完全自定义"（自建 buff 名/图标/数值）**唯一路径 = 客户端 DBC 补丁**（改 Spell.dbc 打包 MPQ，原 C 级）。
- **原版属性附魔全 passive**（SPELL_ATTR_PASSIVE=0x40 + HIDDEN_CLIENTSIDE=0x80），SetEnchantment 打 PROP 槽客户端面板不显示（服务端生效）→ 附魔路线死。
- **客户端可见的现成 buff**（词缀/球可用）：23964 暴击+10 / 12966 攻速+10 / 12968 攻速+20 / 12970 攻速+30 / 8233 攻强+46 / 10484 攻强+249 / 22818 护甲+15 / 179 抗性+5 / 111 抗性+20 / 168 抗性+30。
- **Spell.dbc 字段布局实锤**（Turtle 173 字段版）：basepoints@76-78(+1)、Effect@88-90、ApplyAuraName@91-93、StackAmount@26、PASSIVE=0x40@idx6、SpellIconID@117；名字列大多为空。SIE：idx1=effect type、idx10=spell、idx13/19=名字。
- **玩家事件 id 与官方不同**：OnKillCreature=7 / OnKilledByCreature=8（官方 8/9）；OnEquip=29 / OnLootItem=32 / OnLogin=3。
- **AI 运维**：工具/ssh_soulcore.py（paramiko 强制 IPv4，密码不入库）；character_inventory_copy 缺表修复（上游新代码需要，`CREATE TABLE ... LIKE character_inventory`）。

**下次开工流程**：先跟用户对齐"效果层走哪条路"（接受现有 buff / 上 DBC 补丁）→ 再写计划。

---

**2026-08-11 大决策：砍除五系统，槽位让给词缀**：
- **背景**：1.12 仅 7 附魔槽（0-6），gem(槽3/5)+rune(槽4) 与词缀（引擎 SetItemRandomProperties 硬编码写 3/4/5）结构性冲突；3.35 暗黑逍遥有 12 槽可挪词缀到 9/10/11，1.12 无此空间（Item.h:141-152 实锤）。
- **决策**：宝石/符文/打孔器/合成链/门控**全部砍除**，槽 3/4/5 留给阶段 2 词缀（走引擎原生 IRP，随机属性掉落自动生成、持久化、客户端显示全免费）。宝石/符文若未来要回归，槽 2/6 仍空闲可用。
- **改动**：删 5 脚本（gem/rune/socket/combine/gate）；013/014/016/018 SQL 移入 `sql/local_changes/_deprecated/`（含 README 说明）；010 ID 登记表回收 900xxx/901xxx/905010 段；guide_npc 玩法文案去宝石/符文。
- **槽位终局**：0=玩家附魔、1=临时、**3/4/5=词缀（阶段 2）**、2/6 空闲（未来宝石/符文回归用）。

**本次推进会（2026-08-10 重开）已完成**：
1. **环境恢复**：mangosd 未跑 → 重启加载全部脚本（8090 正常监听，无死循环）；git HEAD=c06dae8（用户已手动撤回推进会运行修改：gate.lua 删/016 删/socket.gem 回退）
2. **死循环根因定位（踩坑#12 实锤）**：TurtleLuaEngine.cpp `QueryGetRow` 只取**当前行**（`result->Fetch()`），游标推进靠独立 `NextRow()` 方法；gate.lua v1 的 `repeat ... until false` 永不推进游标 → 加载阶段即死循环卡死 mangosd。**用户撤回 gate.lua 的判断正确**
3. **016 恢复**：从 git c838f2e 找回 016_phase1_gate.sql → 双重放验证幂等 ✓（905004 远古符文卷轴 + soulcore_arpg_gate 表）
4. **gate.lua v2 安全版**：改用 `GetRow 取行 + NextRow 推进` 正确遍历模式，全部 DB 查询 pcall；luac52 语法检查通过
5. **socket.lua v3**：MAX_HOLES **2→1**（用户确认：每装备仅 1 个扩展宝石槽=槽5，第 2 孔无槽浪费）+ CharDBExecute 补 pcall
6. **1-7 重铸开发（新发现调整）**：itemset 表实为**空表**（0 行，Turtle 1.12 无数据）→ 改用 `item_template.set_id`（2070 件）同套互查方案；017 SQL（904003 混沌重铸石，临时表复制模板 7910，双重放幂等 ✓）+ reforge.lua（背包扫描→列套装部件→同套随机转换**优先同部位**，5% 湮灭，全 pcall）
7. **全量语法验证**：12 个 Lua 脚本 luac52 -p 全部 OK

---

## 三、阶段 1 逐项状态（9 项）

| # | 系统 | 状态 | 关键实现 | 遗留 |
|---|---|---|---|---|
| 1-1 | 新手引导（艾薇儿 190101） | ✅ 通过 | gossip 菜单：领随身商贩技能书/玩法介绍；暴风城银行门口(-9066,433)，display 1267 女性人类 | — |
| 1-2 | 随身小伙伴（905001） | ✅ 通过 | 右键技能书 → SummonCreature 190105 面前 3 码，90 秒消失；item use return false 阻止 | — |
| 1-3 | 主城喊话 | ✅ 通过 | CreateLuaEvent(30s 后, 每 4 分钟) + SendWorldMessage 台词池随机 | — |
| 1-4 | 1-33 号符文（900001-900033） | ❌ **已砍除**（2026-08-11） | rune.lua 已删；900xxx 段回收 | 槽位让给词缀（阶段 2） |
| 1-5 | 四色宝石（901001-901020） | ❌ **已砍除**（2026-08-11） | gem.lua 已删；901xxx 段回收 | 槽位让给词缀（阶段 2） |
| 1-6 | 宝石合成链（905002/905003） | ❌ **已砍除**（2026-08-11） | combine.lua 已删（产物是宝石，连带） | — |
| 1-7 | 套装重铸（904003） | 🔄 **开发完成待实测** | reforge.lua：右键 → 列背包带 set_id 的套装部件 → 选中 → 查同 set_id 其他部件**优先同部位** → 随机转换（5% 湮灭）；**itemset 表为空，改按 item_template.set_id 互查** | 017 SQL 双重放 ✓；luac52 ✓；待游戏内实测（测试素材：47162-47167 Earthshatter / 70542-70545 Avenger's） |
| 1-8 | 拉玛兰迪打孔器（905010） | ❌ **已砍除**（2026-08-11） | socket.lua 已删；018 sockets DDL 移入 _deprecated/ | 槽位让给词缀（阶段 2） |
| 1-9 | 符文门控（905004 远古符文卷轴） | ❌ **已砍除**（2026-08-11） | gate.lua 已删（钥匙=符文、奖励=宝石，均砍连带） | 016 SQL 移入 _deprecated/ |

**阶段 1 门禁**：保留 4 项（1-1/1-2/1-3 已通过 + 1-7 待实测）+ 5 项砍除（2026-08-11 用户决策）。**1-7 重铸为唯一待游戏内实测项**。

---

## 四、关键机制与 API（写脚本直接查）

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

## 五、踩坑记录（本阶段新增，勿重踩）

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

## 六、数据资产清单

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

## 七、下一步工作

### 立即（阶段 1 收尾 —— 4 项游戏内实测，测前 `.reload eluna`）
1. **实测 1-4 符文**（rune.lua v2）：
   - `.additem 900001`（El 力量+1）、`.additem 900002` → 右键符文 → 菜单选"镶嵌到 XX" → 属性面板 +1
   - 右键另一符文 → **主菜单直列"取下 XX 的符文"** → 取下 → 符文返还 + 附魔消失
   - 共存验证：先镶宝石（`.additem 901001` 槽3）再镶符文（槽4），两附魔都在
2. **实测 1-8 打孔器**（socket.lua v3）：
   - `.additem 905010` → 右键 → 列表出现装备（当前 1/2 槽）→ 打孔 → 消耗 1 打孔器 + holes=1
   - 再用宝石右键 → 该装备出现槽5 → 镶第 2 颗宝石 → 属性叠加
   - 重登后双宝石仍在（持久性）；打孔后装备在菜单中不再可打孔（holes=1 已达 MAX_HOLES，文案显示"当前 1/2 槽"）
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

## 八、重启与恢复（换机/重开会话）

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
