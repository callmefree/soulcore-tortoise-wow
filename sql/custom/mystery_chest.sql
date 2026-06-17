-- ============================================================================
-- 神秘宝箱 - 纯数据库实现
-- 
-- 实现方式：
--   创建 ITEM_FLAG_LOOTABLE 物品（flags=4），右键打开弹出拾取窗口
--   掉落实时从 item_loot_template 中随机计算
--   暴风城/奥格旅店老板售价 100G
--   
-- 所有物品 ID 已通过 Node.js 解析器确认存在于 Turtle WoW 数据库中
-- 使用方法：在 world 库执行此 SQL，然后 .reload 对应表即可
-- ============================================================================

-- ===================================================
-- 1. 创建物品：神秘宝箱 (item ID: 950000)
-- ===================================================
DELETE FROM `item_template` WHERE `entry` = 950000;
INSERT INTO `item_template` (`entry`, `class`, `subclass`, `name`, `description`, `display_id`,
    `quality`, `flags`, `buy_count`, `buy_price`, `sell_price`, `inventory_type`,
    `allowable_class`, `allowable_race`, `item_level`, `required_level`,
    `max_count`, `stackable`,
    `bonding`,
    `material`, `sheath`)
VALUES
(950000,
    0,              -- class: 消耗品
    0,              -- subclass: 通用
    '神秘宝箱',     -- name
    '右键打开，随机获得宝物！',  -- description
    6418,           -- display_id: 小背包模型
    3,              -- quality: 3=稀有(蓝)
    4,              -- flags: 4 = ITEM_FLAG_LOOTABLE (可右键打开)
    1,              -- buy_count
    1000000,        -- buy_price: 100G (100 * 10000)
    0,              -- sell_price: 不可出售
    0,              -- inventory_type
    -1,             -- allowable_class: 所有职业
    -1,             -- allowable_race: 所有种族
    60,             -- item_level
    0,              -- required_level: 无限制
    0,              -- max_count
    5,              -- stackable: 可叠加5个
    1,              -- bonding: 拾取绑定
    1,              -- material
    0);             -- sheath


-- ===================================================
-- 2. 掉落表：神秘宝箱可开出物品
-- ===================================================
-- groupid=0：每件各自独立概率判定，平均一次出2-4件

DELETE FROM `item_loot_template` WHERE `entry` = 950000;

-- ========== 附魔材料（常见 30-50%） ==========
INSERT INTO `item_loot_template` (`entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount`, `condition_id`) VALUES
(950000, 10940, 50, 0, 3, 8, 0),   -- Strange Dust 奇异之尘 ×3-8
(950000, 11134, 45, 0, 2, 6, 0),   -- Lesser Mystic Essence 次级神秘精华 ×2-6
(950000, 11135, 40, 0, 2, 5, 0),   -- Greater Mystic Essence 强效神秘精华 ×2-5
(950000, 11177, 35, 0, 1, 3, 0),   -- Small Radiant Shard 小块光耀碎片 ×1-3
(950000, 14341, 35, 0, 2, 4, 0),   -- Rune Thread 符文线 ×2-4
(950000, 16202, 30, 0, 1, 2, 0);   -- Lesser Eternal Essence 次级永恒精华 ×1-2

-- ========== 药水消耗品（中等常见 10-25%） ==========
INSERT INTO `item_loot_template` (`entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount`, `condition_id`) VALUES
(950000, 13446, 25, 0, 1, 3, 0),   -- Major Healing Potion 特效治疗药水 ×1-3
(950000, 13444, 25, 0, 1, 3, 0),   -- Major Mana Potion 特效法力药水 ×1-3
(950000, 13452, 18, 0, 1, 2, 0),   -- Elixir of the Mongoose 猫鼬药剂 ×1-2
(950000, 13442, 15, 0, 1, 2, 0),   -- Mighty Rage Potion 强效怒气药水 ×1-2
(950000, 13447, 15, 0, 1, 2, 0),   -- Elixir of the Sages 贤者药剂 ×1-2
(950000, 9088,  15, 0, 1, 3, 0),   -- Gift of Arthas 阿萨斯之礼物 ×1-3
(950000, 5634,  15, 0, 1, 3, 0),   -- Free Action Potion 自由行动药水 ×1-3
(950000, 13510, 10, 0, 1, 1, 0),   -- Flask of the Titans 泰坦合剂 ×1
(950000, 13455, 10, 0, 1, 2, 0),   -- Greater Stoneshield Potion 强效石盾药水 ×1-2
(950000, 13453, 10, 0, 1, 2, 0),   -- Elixir of Brute Force 蛮力药剂 ×1-2
(950000, 13454, 10, 0, 1, 2, 0);   -- Greater Arcane Elixir 强效奥法药剂 ×1-2

-- ========== 稀有掉落（合剂 + 附魔公式 3-5%） ==========
INSERT INTO `item_loot_template` (`entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount`, `condition_id`) VALUES
(950000, 13513,  5, 0, 1, 1, 0),   -- Flask of Chromatic Resistance 多彩抗性合剂
(950000, 13512,  5, 0, 1, 1, 0),   -- Flask of Supreme Power 超级能量合剂
(950000, 13506,  5, 0, 1, 1, 0),   -- Flask of Petrification 石化合剂
(950000, 16244,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Greater Strength 附魔手套-强效力量
(950000, 16248,  3, 0, 1, 1, 0),   -- Formula: Enchant Weapon - Unholy 附魔武器-邪恶
(950000, 16249,  3, 0, 1, 1, 0),   -- Formula: Enchant 2H Weapon - Major Intellect 附魔双手武器-特效智力
(950000, 20726,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Threat 附魔手套-威胁
(950000, 20727,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Shadow Power 附魔手套-暗影之力
(950000, 20728,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Frost Power 附魔手套-冰霜之力
(950000, 20729,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Fire Power 附魔手套-火焰之力
(950000, 20730,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Healing Power 附魔手套-治疗之力
(950000, 20731,  3, 0, 1, 1, 0),   -- Formula: Enchant Gloves - Superior Agility 附魔手套-超强敏捷
(950000, 20734,  3, 0, 1, 1, 0),   -- Formula: Enchant Cloak - Stealth 附魔披风-潜行
(950000, 20736,  3, 0, 1, 1, 0);   -- Formula: Enchant Cloak - Dodge 附魔披风-闪躲

-- ========== 极稀有（史诗级物品 0.1-1%） ==========
INSERT INTO `item_loot_template` (`entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount`, `condition_id`) VALUES
(950000, 17182,  0.5, 0, 1, 1, 0),  -- Sulfuras, Hand of Ragnaros 萨弗拉斯·炎魔拉格纳罗斯之手
(950000, 18563,  0.5, 0, 1, 1, 0),  -- Bindings of the Windseeker 逐风者禁锢之颅（左）
(950000, 18564,  0.5, 0, 1, 1, 0),  -- Bindings of the Windseeker 逐风者禁锢之颅（右）
(950000, 19019,  0.5, 0, 1, 1, 0),  -- Thunderfury, Blessed Blade... 雷霆之怒·逐风者的祝福之剑
(950000, 18703,  0.5, 0, 1, 1, 0),  -- Ancient Petrified Leaf 远古石叶（猎人史诗任务）
(950000, 18704,  0.5, 0, 1, 1, 0),  -- Mature Blue Dragon Sinew 成年蓝龙的肌腱
(950000, 18665,  0.5, 0, 1, 1, 0),  -- The Eye of Shadow 暗影之眼（牧师史诗任务）
(950000, 16966,  1,   0, 1, 1, 0),  -- Breastplate of Wrath 愤怒胸甲
(950000, 17068,  1,   0, 1, 1, 0),  -- Deathbringer 死亡使者
(950000, 17203,  1,   0, 1, 1, 0),  -- Sulfuron Ingot 萨弗隆铁锭
(950000, 19143,  1,   0, 1, 1, 0),  -- Flameguard Gauntlets 火焰卫士护手
(950000, 19363,  1,   0, 1, 1, 0);  -- Crul\'shorukh, Edge of Chaos 克鲁索洛克恩·混乱之刃


-- ===================================================
-- 3. 旅店老板添加商品
-- ===================================================

-- 暴风城旅店老板：Innkeeper Farley (entry 295)
DELETE FROM `npc_vendor` WHERE `entry` = 295 AND `item` = 950000;
INSERT INTO `npc_vendor` (`entry`, `item`, `maxcount`, `incrtime`, `itemflags`) VALUES
(295, 950000, 0, 0, 0);

-- 奥格瑞玛旅店老板：Innkeeper Gryshka (entry 6807)
DELETE FROM `npc_vendor` WHERE `entry` = 6807 AND `item` = 950000;
INSERT INTO `npc_vendor` (`entry`, `item`, `maxcount`, `incrtime`, `itemflags`) VALUES
(6807, 950000, 0, 0, 0);
