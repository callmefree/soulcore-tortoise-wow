# ARPG 移植 · 阶段 0 落地报告（技术探针与踩坑全记录）

> 日期：2026-08-10 ｜ 状态：✅ 阶段 0 门禁全通过，已关闭
> 关联：《ARPG系统移植计划书.md》（主计划）、《素材\阶段0探针报告.md》（技术结论详版）
> 用途：**后续阶段开发前先查本报告**——所有已踩的坑、已定的规则、已建的资产都在这里，避免重蹈覆辙

---

## 一、阶段 0 干了什么

6 项探针，目标 = 扫清 ARPG 17 系统移植的全部技术不确定点，**零游戏内容**：

| # | 探针 | 一句话结论 | 验证方式 |
|---|---|---|---|
| 0-1 | 词缀机制 | 1.12 **原生双词缀可行** | 源码+DBC 交叉验证 + 游戏内实测 |
| 0-1b | Eluna 附魔读写 | API 齐全，升级保词缀链路成立 | 游戏内实测（probe 命令） |
| 0-2 | 宝石插槽 | 1.12 无原生插槽 → 替代交互定稿 | 源码确认 |
| 0-3 | SQL 生成器 | 远古/太古条目批量生成 | 交付+入库验证 |
| 0-4 | ID 段登记 | 段位锁死防冲突 | 交付 |
| 0-5 | 测试规范 | 附录 A 定稿 | 跑通 |
| 0-6 | 自定义法术 | 服务端+客户端全通，**不新建 spell** | 游戏内实测（闪电之盾图标） |

---

## 二、技术结论（三源验证：源码 + DBC 二进制 + 数据库）

### 2.1 词缀系统完整链路（1.12 Turtle 实测）
```
item_template.RandomProperty（DB 池 ID）
  → item_enchantment_template（DB，按 chance 权重 roll 出 1 个 ID）[ItemEnchantmentMgr.cpp:78 GetItemEnchantMod]
  → ItemRandomProperties.dbc（条目含 enchant_id[0..2]，最多 3 个）
  → 打到装备 PROP_ENCHANTMENT_SLOT_0/1/2（槽位 3/4/5）[Item.cpp:787 SetItemRandomProperties]
  → SpellItemEnchantment.dbc（enchant 效果，type=3 EQUIP_SPELL → 装备时施放 spell）
```

**关键事实**：
- 1.12 item_template 只有 `random_property` 单字段（**无 RandomSuffix 字段**，3.35 才有）
- 但 **ItemRandomProperties.dbc 每条目自带最多 3 个 enchant**——"2 条词缀"用复合条目即可（现有 2012 条里 **979 条是复合条目**，如 ID=117 "of Twain" ench=(200,188,110)）
- SpellItemEnchantment.dbc 1522 条：type 分布 = EQUIP_SPELL(3) 1381 / COMBAT_SPELL(1) 74 / DAMAGE(2) 33 / RESISTANCE(4) 31 / **无 STAT 类**——Turtle 属性附魔全走 EQUIP_SPELL 引用 spell（如 ID=2585 spellid=24153 "Attack Power+28/Dodge+1%"）

### 2.2 Eluna 附魔 API（TurtleLuaEngine.cpp 行号备查）
| API | 行号 | 说明 |
|---|---|---|
| `Item:GetEnchantmentId(slot)` | 12150 | 读附魔 |
| `Item:SetEnchantment(enchant, slot)` | 12344 | 写附魔（含 ApplyEnchantment 生效逻辑） |
| `Item:ClearEnchantment(slot)` | 12367 | 清附魔 |
| `Unit:AddAura(spellId)` | 9443 | 挂 aura |

槽位枚举（Item.h:141）：0=PERM / 1=TEMP（**1 小时时限，勿用于持久效果**）/ 2=INSPECT / 3-6=PROP（词缀/自定义持久用）

### 2.3 宝石插槽（0-2 定稿）
- 1.12 **无 SocketColor/GemProperties/宝石插槽**（Item.h/cpp 无 socket 代码）
- **替代交互（定稿）**：宝石 = 右键使用 → Eluna 给目标装备打附魔（PROP 槽 3-6 之一做"宝石槽"）→ 换宝石 = 再使用覆盖 → 重登自动恢复
- 限制用 Eluna 计数：四色同色最多 2 枚、传奇宝石限 1 多彩位、诅咒宝石限 1 枚

### 2.4 自定义法术（0-6 定案）
- Spell.dbc 26928 条（Turtle 自定义段 ID 25001-58052 共 7592 条）
- **约束：本项目不新建 spell**（新条目要改服务端+客户端双份 DBC + 打 MPQ 补丁 = C 级工作量）
- passive（被动）spell 客户端**不显示 buff 图标**（正常行为，属性照常生效）——常驻增益用它；需要玩家感知的（三色球）用非 passive
- 判定方法：Spell.dbc **字段 6 = Attributes**（SpellMgr.cpp:3388），passive = bit 6 (0x40)

---

## 三、踩坑记录（按时间序，后续勿重复踩）

### 坑 1：事件注册函数用错 → OnLogin 完全不触发
- **现象**：probe 脚本 `RegisterServerEvent(3, OnLogin)` 登录无任何反应
- **根因**：OnLogin/OnChat 是**玩家事件**（PLAYER_EVENT_ON_*），必须 `RegisterPlayerEvent`；`RegisterServerEvent` 是服务器事件（3 号是别的）
- **修复**：`RegisterPlayerEvent(3, ...)`（对照 welcome.lua）
- **铁律**：写事件前查 TurtleLuaEngine.h:42 起的事件枚举，玩家事件统一 RegisterPlayerEvent

### 坑 2：聊天触发词带点 → "no such command"
- **现象**：`.probe` 提示 no such command
- **根因**：`.` 开头消息被 GM 命令系统先拦截，OnChat 事件收不到
- **修复**：触发词去点（`probe`）
- **铁律**：Eluna 聊天触发词**禁用点前缀**；GM 命令功能需 C++ 注册（本引擎已实现 .reload eluna）

### 坑 3：passive spell 无图标，误判为"客户端不承载"
- **现象**：AddAura 高 ID spell 成功但无 buff 图标
- **根因**：测试的 4 个 spell 都是 passive 被动型，客户端本来就不显示被动图标
- **验证**：换非 passive 高 ID spell（25002 等）→ 客户端显示"闪电之盾"图标 → 全通
- **教训**：先查 spell Attributes 再下结论；被动效果不显示图标是特性不是 bug

### 坑 4：暗黑逍遥 MySQL 启动 crash recovery + 表缺失（素材挖掘阶段）
- 现象：mysqld 5.6.25 启动报 `auth/account_muted .ibd 缺失`，InnoDB crash recovery
- 处理：`--skip-grant-tables --port=3307` 只读启动，world 库可正常查；用后 shutdown
- 教训：读他人端数据库一律**只读启动 + 独立端口**，不碰原数据

### 坑 5：MySQL 5.6 无 REGEXP_REPLACE
- 现象：暗黑逍遥库（5.6）查询报函数不存在
- 处理：改用 SUBSTRING_INDEX/LIKE 组合
- 教训：老版本 MySQL 特性差异；本机 MariaDB 11.4 才有 REGEXP_REPLACE

### 坑 6：python-docx 打开 21MB 攻略 docx 报 `KeyError: 'NULL'`
- 现象：`docx.Document()` 抛 "no item named 'NULL'"
- 根因：文档 rels 引用了缺失关系项
- 处理：绕开 python-docx，直接解析 zip 内 `word/document.xml` 提取 `<w:t>` 文本（正则）
- 教训：docx 本质是 zip，python-docx 失败时直接解压解析

### 坑 7：bash rm 触发安全删除机制路径拼接错误
- 现象：`rm 'E:\...'` 被 safe-delete 拦截，报路径重复拼接（/e/... + E:\...）
- 处理：用 unix 风格路径 `/e/11111/...` 删除成功
- 教训：bash 工具删除文件用 unix 路径（工作区文件；个人目录删除仍需遵守安全规则）

### 坑 8：DBC 字段布局与标准不一致（SpellItemEnchantment）
- 现象：按标准布局解析 enchant 名字全空/错位
- 根因：Turtle 魔改 DBC 扩展了字段（24 字段 vs 标准 21）
- 处理：**以服务端源码 DBCStructure.h 的 struct 布局为准**解析（type=字段1-3、amount=4-6、spellid=10-12、名字=13-20）
- 教训：解析魔改 DBC 前先查 DBCStructure.h/DBCStores.cpp 的字段映射

---

## 四、沉淀规则清单（后续所有阶段必守）

### 写脚本前
1. **事件注册**：玩家事件用 `RegisterPlayerEvent`（OnLogin=3/OnChat=18/OnLevelChange=13…），事件号查 TurtleLunaEngine.h:42 起枚举
2. **聊天触发词**：禁用 `.` 前缀（GM 命令系统拦截）
3. **布尔事件语义与官方相反**：item use 事件 `expectedValue=false` → **返回 false 才阻止施法**（写前查调用点，见 Eluna 移植工作记录）
4. **不新建 spell**：效果复用现有 26928 条 DBC spell；需要数值/图标特殊化时用 Eluna 逻辑模拟
5. **持久效果不用 TEMP 槽**（1 小时时限），用 PROP 槽 3-6
6. **被动效果**：不显示图标是正常，玩家感知型效果选非 passive spell（字段 6 无 0x40）

### 建数据时
7. ID 段按 `010_id_registry.sql` 锁段（符文 900001+ / 宝石 901xxx / 通货 904xxx / 远古+910000 / 太古+920000 / NPC 190100+ / 测试段 950001+）
8. 词缀池 = `item_enchantment_template` entry 9000+ → roll 到 **ItemRandomProperties.dbc 现有条目**（0-1 结论），勿引用不存在的 IRP ID（否则 ObjectMgr.cpp:2557 启动报错清零）
9. 装备特效：`spellid_N + spelltrigger_N`（1=使用 2=装备）随 item_template 建，远古/太古生成器已自动拷贝

### 部署验证
10. 测试角色 Free，GM admin（rank4 才能 .reload eluna）
11. 加载验证：日志 `[Lua] Loaded N Lua scripts` 无 ERROR；改动后 `.reload eluna`
12. 回滚：移走 lua 文件 + `.reload eluna` 即下线单个系统

---

## 五、数据资产清单（已落盘）

| 资产 | 路径 | 说明 |
|---|---|---|
| ID 段登记表 | `sql/local_changes/010_id_registry.sql` | 段位锁死 |
| 探针测试数据 | `sql/local_changes/011_phase0_probes.sql` | 词缀池 9001→IRP117 + 测试紫装 950001（**保留作词缀系统起点**） |
| SQL 生成器 | `工具/gen_equip_sql.py` | 原版紫装 → 远古/太古 INSERT（属性×1.2/×1.4、特效拷贝） |
| 生成器样例 | `工具/gen_equip_test.sql` | 3 件紫装 6 条（已入库，910647/920647/910809/910811 等） |
| 技术结论 | `素材\阶段0探针报告.md` | 探针详版 |
| 本报告 | 项目根目录 | 踩坑+规则速查 |

> ⚠️ 已入库测试数据：910647/920647/910809/920809/910811/920811（远古/太古样例）+ 950001（词缀测试）。这些是**有效资产**，阶段 2c/2d 直接复用；950001 可作词缀回归样例。

---

## 六、阶段 1 开工检查单

- [ ] 服务端运行（realmd 3724 + mangosd 8090）+ `.reload eluna` 可用
- [ ] 测试角色 Free 在线；GM admin 可用
- [ ] lua_scripts 当前 3 个正式脚本（welcome/test_gossip/super_hearthstone）
- [ ] 新脚本命名 `lua_scripts/arpg/` 子目录（按系统分文件，arpg_init.lua 统一注册）
- [ ] 写事件用 RegisterPlayerEvent；聊天触发词不带点；item use 返回 false 阻止
- [ ] 每系统做完：部署 → .reload eluna → Free 实测 → 日志 0 ERROR → 勾验收

---

_维护：新踩的坑追加到"三、踩坑记录"；新规则追加到"四、沉淀规则清单"；阶段推进后更新头部状态。_
