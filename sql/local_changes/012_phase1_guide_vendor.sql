-- ============================================================
-- 012_phase1_guide_vendor.sql — 阶段1 便利三件套数据（1-1 艾薇儿 / 1-2 随身商贩）
-- ============================================================
-- 来源：ARPG系统移植计划书.md 阶段 1（1-1 新手引导 / 1-2 随身小伙伴）
-- 目标库：tw_world ｜ 幂等：REPLACE / INSERT IGNORE
-- 用法：mysql --default-character-set=utf8 tw_world < 012_phase1_guide_vendor.sql
-- 说明：905001 技能书由 Eluna 处理使用召唤（travel_vendor.lua）；190105 随身商贩召唤出来
-- ============================================================

-- ============ 1-2 随身商贩 ============
-- item 905001「技能书：随身商贩」：复制炉石 6948 模板，去掉使用法术，Eluna 处理 use
REPLACE INTO `item_template`
SELECT 905001, class, subclass, '技能书：随身商贩', description, display_id,
       quality, flags, buy_count, buy_price, sell_price, inventory_type, allowable_class, allowable_race,
       item_level, required_level, required_skill, required_skill_rank, required_spell, required_honor_rank,
       required_city_rank, required_reputation_faction, required_reputation_rank, max_count, stackable,
       container_slots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3,
       stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7,
       stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, delay, range_mod,
       ammo_type, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, dmg_min3, dmg_max3,
       dmg_type3, dmg_min4, dmg_max4, dmg_type4, dmg_min5, dmg_max5, dmg_type5, block, armor, holy_res,
       fire_res, nature_res, frost_res, shadow_res, arcane_res, 8690, 0, spellcharges_1,
       spellppmrate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, 0, 0,
       spellcharges_2, spellppmrate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2,
       0, 0, spellcharges_3, spellppmrate_3, spellcooldown_3, spellcategory_3,
       spellcategorycooldown_3, 0, 0, spellcharges_4, spellppmrate_4, spellcooldown_4,
       spellcategory_4, spellcategorycooldown_4, 0, 0, spellcharges_5, spellppmrate_5,
       spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, page_text, page_language,
       page_material, start_quest, lock_id, material, sheath, 0, set_id, max_durability, area_bound,
       map_bound, duration, bag_family, disenchant_id, food_type, min_money_loot, max_money_loot,
       wrapped_gift, extra_flags, other_team_entry, script_name
FROM `item_template` WHERE entry = 6948;

-- 清除炉石自带的使用法术（spellid_1 已置 0，spellcharges_1 复制的是 6948 的值需置 0）
UPDATE `item_template` SET spellcharges_1 = 0, spellcharges_2 = 0, spellcharges_3 = 0,
       spellcharges_4 = 0, spellcharges_5 = 0, description = '使用后召唤一名随身商贩，1 分钟后消失。' WHERE entry = 905001;

-- creature 190105「随身商贩」：复制旅馆老板 295（npc_flags 135=GOSSIP+VENDOR+INNKEEPER），只保留 VENDOR
REPLACE INTO `creature_template` (`entry`, `display_id1`, `display_id2`, `display_id3`, `display_id4`, `mount_display_id`, `name`, `subname`, `gossip_menu_id`, `level_min`, `level_max`, `health_min`, `health_max`, `mana_min`, `mana_max`, `armor`, `faction`, `npc_flags`, `speed_walk`, `speed_run`, `scale`, `detection_range`, `call_for_help_range`, `leash_range`, `rank`, `xp_multiplier`, `dmg_min`, `dmg_max`, `dmg_school`, `attack_power`, `dmg_multiplier`, `base_attack_time`, `ranged_attack_time`, `unit_class`, `unit_flags`, `dynamic_flags`, `beast_family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `ranged_dmg_min`, `ranged_dmg_max`, `ranged_attack_power`, `type`, `type_flags`, `loot_id`, `pickpocket_loot_id`, `skinning_loot_id`, `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`, `spell_id1`, `spell_id2`, `spell_id3`, `spell_id4`, `spell_list_id`, `pet_spell_list_id`, `spawn_spell_id`, `auras`, `gold_min`, `gold_max`, `ai_name`, `movement_type`, `inhabit_type`, `civilian`, `racial_leader`, `regeneration`, `equipment_id`, `trainer_id`, `vendor_id`, `mechanic_immune_mask`, `school_immune_mask`, `immunity_flags`, `flags_extra`, `phase_quest_id`, `script_name`)
SELECT 190105, display_id1, display_id2, display_id3, display_id4, mount_display_id, '随身商贩', '随叫随到', gossip_menu_id, level_min, level_max, health_min, health_max, mana_min, mana_max, armor, faction, 128, speed_walk, speed_run, scale, detection_range, call_for_help_range, leash_range, rank, xp_multiplier, dmg_min, dmg_max, dmg_school, attack_power, dmg_multiplier, base_attack_time, ranged_attack_time, unit_class, unit_flags, dynamic_flags, beast_family, trainer_type, trainer_spell, trainer_class, trainer_race, ranged_dmg_min, ranged_dmg_max, ranged_attack_power, type, type_flags, loot_id, pickpocket_loot_id, skinning_loot_id, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, spell_id1, spell_id2, spell_id3, spell_id4, spell_list_id, pet_spell_list_id, spawn_spell_id, auras, gold_min, gold_max, ai_name, movement_type, inhabit_type, civilian, racial_leader, regeneration, equipment_id, trainer_id, vendor_id, mechanic_immune_mask, school_immune_mask, immunity_flags, flags_extra, phase_quest_id, script_name
FROM `creature_template` WHERE entry = 295;

-- 随身商贩货物：复制旅馆老板 295 的货 + 常用消耗品
INSERT IGNORE INTO `npc_vendor` (entry, slot, item, maxcount, incrtime, itemflags, condition_id)
SELECT 190105, slot, item, maxcount, incrtime, itemflags, condition_id FROM `npc_vendor` WHERE entry = 295;

-- ============ 1-1 艾薇儿（新手引导） ============
-- creature 190101「艾薇儿」：复制暴风城卫兵 68 模板（gossip），npc_flags=1
REPLACE INTO `creature_template` (`entry`, `display_id1`, `display_id2`, `display_id3`, `display_id4`, `mount_display_id`, `name`, `subname`, `gossip_menu_id`, `level_min`, `level_max`, `health_min`, `health_max`, `mana_min`, `mana_max`, `armor`, `faction`, `npc_flags`, `speed_walk`, `speed_run`, `scale`, `detection_range`, `call_for_help_range`, `leash_range`, `rank`, `xp_multiplier`, `dmg_min`, `dmg_max`, `dmg_school`, `attack_power`, `dmg_multiplier`, `base_attack_time`, `ranged_attack_time`, `unit_class`, `unit_flags`, `dynamic_flags`, `beast_family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `ranged_dmg_min`, `ranged_dmg_max`, `ranged_attack_power`, `type`, `type_flags`, `loot_id`, `pickpocket_loot_id`, `skinning_loot_id`, `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`, `spell_id1`, `spell_id2`, `spell_id3`, `spell_id4`, `spell_list_id`, `pet_spell_list_id`, `spawn_spell_id`, `auras`, `gold_min`, `gold_max`, `ai_name`, `movement_type`, `inhabit_type`, `civilian`, `racial_leader`, `regeneration`, `equipment_id`, `trainer_id`, `vendor_id`, `mechanic_immune_mask`, `school_immune_mask`, `immunity_flags`, `flags_extra`, `phase_quest_id`, `script_name`)
SELECT 190101, display_id1, display_id2, display_id3, display_id4, mount_display_id, '艾薇儿', '新手引导', gossip_menu_id, level_min, level_max, health_min, health_max, mana_min, mana_max, armor, faction, 1, speed_walk, speed_run, scale, detection_range, call_for_help_range, leash_range, rank, xp_multiplier, dmg_min, dmg_max, dmg_school, attack_power, dmg_multiplier, base_attack_time, ranged_attack_time, unit_class, unit_flags, dynamic_flags, beast_family, trainer_type, trainer_spell, trainer_class, trainer_race, ranged_dmg_min, ranged_dmg_max, ranged_attack_power, type, type_flags, loot_id, pickpocket_loot_id, skinning_loot_id, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, spell_id1, spell_id2, spell_id3, spell_id4, spell_list_id, pet_spell_list_id, spawn_spell_id, auras, gold_min, gold_max, ai_name, movement_type, inhabit_type, civilian, racial_leader, regeneration, equipment_id, trainer_id, vendor_id, mechanic_immune_mask, school_immune_mask, immunity_flags, flags_extra, phase_quest_id, script_name
FROM `creature_template` WHERE entry = 68;

-- 艾薇儿实体：暴风城银行门口（与 190001 并排，guid 自选空闲段）
INSERT IGNORE INTO `creature` (`guid`, `id`, `id2`, `id3`, `id4`, `map`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`, `health_percent`, `mana_percent`, `movement_type`, `spawn_flags`, `visibility_mod`) VALUES (12585179,190101,0,0,0,0,-9052,431,93.6,3.14,120,120,0,100,100,0,0,0);

-- 兜底：190105/190101 npc_flags 修正
UPDATE `creature_template` SET npc_flags = 128 WHERE entry = 190105;
UPDATE `creature_template` SET npc_flags = 1 WHERE entry = 190101;
