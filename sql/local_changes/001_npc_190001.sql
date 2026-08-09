-- ============================================================
-- 001_npc_190001.sql — Eluna Test NPC（暴风城银行门口）
-- 目标库: tw_world
--
-- 来源（2026-08-09 第二阶段批次1）:
--   复制 creature_template entry=68（暴风城卫兵）模板, 改 entry=190001 / name='Eluna Test NPC'
--   实体刷在暴风城银行门口: map 0, (-9065, 434, 93.5), guid 12585178
-- 修复: npc_flags=1（复制模板时丢失 GOSSIP 位, 客户端右键不发 gossip hello,
--       2026-08-09 运行时修复 UPDATE tw_world.creature_template SET npc_flags=1）
--
-- 用法: mysql --default-character-set=utf8 tw_world < 001_npc_190001.sql
-- 幂等: template 用 REPLACE（entry 主键）; creature 实体用 INSERT IGNORE（guid 唯一）
--       重复执行安全。若 INSERT IGNORE 未生效（guid 12585178 被占）, 换一个空闲 guid 执行。
-- ============================================================

REPLACE INTO `creature_template` (`entry`, `display_id1`, `display_id2`, `display_id3`, `display_id4`, `mount_display_id`, `name`, `subname`, `gossip_menu_id`, `level_min`, `level_max`, `health_min`, `health_max`, `mana_min`, `mana_max`, `armor`, `faction`, `npc_flags`, `speed_walk`, `speed_run`, `scale`, `detection_range`, `call_for_help_range`, `leash_range`, `rank`, `xp_multiplier`, `dmg_min`, `dmg_max`, `dmg_school`, `attack_power`, `dmg_multiplier`, `base_attack_time`, `ranged_attack_time`, `unit_class`, `unit_flags`, `dynamic_flags`, `beast_family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `ranged_dmg_min`, `ranged_dmg_max`, `ranged_attack_power`, `type`, `type_flags`, `loot_id`, `pickpocket_loot_id`, `skinning_loot_id`, `holy_res`, `fire_res`, `nature_res`, `frost_res`, `shadow_res`, `arcane_res`, `spell_id1`, `spell_id2`, `spell_id3`, `spell_id4`, `spell_list_id`, `pet_spell_list_id`, `spawn_spell_id`, `auras`, `gold_min`, `gold_max`, `ai_name`, `movement_type`, `inhabit_type`, `civilian`, `racial_leader`, `regeneration`, `equipment_id`, `trainer_id`, `vendor_id`, `mechanic_immune_mask`, `school_immune_mask`, `immunity_flags`, `flags_extra`, `phase_quest_id`, `script_name`) VALUES (190001,3167,5446,0,0,0,'Eluna Test NPC','',435,55,55,5134,5737,0,0,7700,11,1,1,1.42857,0,18,5,0,0,0,242,316.8,0,248,1,2000,2000,1,36864,0,0,0,0,0,0,331.474,464.387,100,7,0,68,0,0,0,0,0,0,0,0,0,0,0,0,680,0,0,NULL,1,690,'EventAI',0,3,0,0,3,68,0,0,1,0,0,525312,0,'npc_guard_emote');

-- creature 实体（若 guid 12585178 已被占用将跳过, 需另选空闲 guid）
INSERT IGNORE INTO `creature` (`guid`, `id`, `id2`, `id3`, `id4`, `map`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`, `health_percent`, `mana_percent`, `movement_type`, `spawn_flags`, `visibility_mod`) VALUES (12585178,190001,0,0,0,0,-9065,434,93.5,3.14,120,120,0,100,100,0,0,0);

-- 兜底: 旧库中 190001 已存在但 npc_flags 未修复（=0）时, 补回 GOSSIP 位（影响 0 行无害）
UPDATE `creature_template` SET `npc_flags` = 1 WHERE `entry` = 190001;
