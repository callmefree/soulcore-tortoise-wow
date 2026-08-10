-- ============================================================
-- 011_phase0_probes.sql — 阶段 0 探针测试数据
-- ============================================================
-- 来源：阶段0探针报告.md（0-1 词缀 / 0-2 宝石替代交互）
-- 原因：游戏内实测用测试数据；ID 段=950001+（临时测试段，不占正式规划段）
-- 目标库：tw_world ｜ 幂等：INSERT IGNORE / REPLACE
-- 用法：入库后启动服务端，GM 实测（见下方"实测步骤"注释）
-- ============================================================

-- 0-1a 词缀池：entry=9001 → roll 到现成复合条目 ItemRandomProperties ID=117 "of Twain"
--      （ench=200,188,110 = 被击10%暗影箭20伤 + 野兽杀手2 + 防御1，全部 EQUIP_SPELL 原生机制）
REPLACE INTO `item_enchantment_template` (entry, ench, chance) VALUES
(9001, 117, 100.0);

-- 0-1b 测试紫装 950001（复制原版 647 Destiny 命运 全字段，random_property=9001 挂词缀池）
-- 注意：random_property 存池 ID（item_enchantment_template.entry），生成时 roll 到 117 → "of Twain"
REPLACE INTO `item_template`
SELECT 950001, class, subclass, CONCAT(name, '|cFF00FF00★测试词缀★'), description, display_id,
       quality, flags, buy_count, buy_price, sell_price, inventory_type, allowable_class, allowable_race,
       item_level, required_level, required_skill, required_skill_rank, required_spell, required_honor_rank,
       required_city_rank, required_reputation_faction, required_reputation_rank, max_count, stackable,
       container_slots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3,
       stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7,
       stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, delay, range_mod,
       ammo_type, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, dmg_min3, dmg_max3,
       dmg_type3, dmg_min4, dmg_max4, dmg_type4, dmg_min5, dmg_max5, dmg_type5, block, armor, holy_res,
       fire_res, nature_res, frost_res, shadow_res, arcane_res, spellid_1, spelltrigger_1, spellcharges_1,
       spellppmrate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2,
       spellcharges_2, spellppmrate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2,
       spellid_3, spelltrigger_3, spellcharges_3, spellppmrate_3, spellcooldown_3, spellcategory_3,
       spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmrate_4, spellcooldown_4,
       spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmrate_5,
       spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, page_text, page_language,
       page_material, start_quest, lock_id, material, sheath, 9001, set_id, max_durability, area_bound,
       map_bound, duration, bag_family, disenchant_id, food_type, min_money_loot, max_money_loot,
       wrapped_gift, extra_flags, other_team_entry, script_name
FROM `item_template` WHERE entry = 647;

-- ============================================================
-- 实测步骤（服务端运行后）
-- ============================================================
-- 1. 0-1 双词缀：GM 登录 → .reload item_template → .additem 950001
--    检查：物品名带"★测试词缀★"，属性面板出现 2-3 条词缀
--          （被击10%暗影箭 + 野兽杀手 + 防御），换装重登后词缀保留
-- 2. 0-1b Eluna 读写：见 lua_scripts/probe_ench.lua（阶段0临时脚本）
-- 3. 0-6 spell 显示：probe_ench.lua 内对 Free AddAura 一个 Turtle 高 ID 被动 spell
--    → 重登看 buff 图标/工具条
-- 4. 通过后：删除 950001 与 9001 池（或保留作回归样例），探针报告勾选
-- ============================================================
