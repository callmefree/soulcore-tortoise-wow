-- ======================================================================
-- Post-fix: Restore ReqSourceId/ReqSourceCount/ReqSpellCast for quests
-- where ReqSourceId has independent values from ReqItemId.
--
-- Root cause: Upstream sql/database_updates/20260507165648_world.sql
-- (commit 3a0008d9, by Penqle) did a REPLACE INTO quest_template that
-- wrote ReqItemId values into ReqSourceId for ALL quests, breaking
-- source-item tracking for 56 quests with distinct source items.
--
-- Cosmetic cases (ReqSourceId=0 becoming ReqItemId) are harmless and
-- left as-is per operator decision.
-- 4 additional entries (2605, 3602, 4005, 6146) have ReqSourceId2
-- corruption but were not caught by the ReqSourceId1-based query.
-- Also had ReqSourceId1 wrongly set to ReqItemId1 value.
--
-- Fix verified against: twptr_world (3307, 1.17 old server)
-- Applied to: tw_world (3306, 191 test server, 2026-06-17)
-- ======================================================================

UPDATE quest_template SET ReqSourceId1 = 15877, ReqSourceCount1 = 1, ReqSpellCast1 = 19719 WHERE entry = 28;
UPDATE quest_template SET ReqSourceId1 = 15877, ReqSourceCount1 = 1, ReqSpellCast1 = 19719 WHERE entry = 29;
UPDATE quest_template SET ReqSourceId1 = 15883, ReqSourceCount1 = 1, ReqSourceId2 = 15882, ReqSourceCount2 = 1 WHERE entry = 30;
UPDATE quest_template SET ReqSourceId1 = 15883, ReqSourceCount1 = 1, ReqSourceId2 = 15882, ReqSourceCount2 = 1 WHERE entry = 272;
UPDATE quest_template SET ReqSourceId1 = 3467, ReqSourceCount1 = 1, ReqSourceId2 = 3499, ReqSourceCount2 = 1, ReqSpellCast1 = 3366, ReqSpellCast2 = 3366 WHERE entry = 498;
UPDATE quest_template SET ReqSourceId1 = 9437, ReqSourceCount1 = 999, ReqSourceId2 = 9439, ReqSourceCount2 = 999 WHERE entry = 654;
UPDATE quest_template SET ReqSourceId1 = 4702, ReqSourceCount1 = 5 WHERE entry = 746;
UPDATE quest_template SET ReqSourceId1 = 10338, ReqSourceCount1 = 1 WHERE entry = 882;
UPDATE quest_template SET ReqSourceId1 = 5165, ReqSourceCount1 = 999999, ReqSpellCast2 = 5316 WHERE entry = 905;
UPDATE quest_template SET ReqSourceId1 = 12220, ReqSourceCount1 = 5 WHERE entry = 1016;
UPDATE quest_template SET ReqSourceId1 = 5475, ReqSourceCount1 = 1 WHERE entry = 1026;
UPDATE quest_template SET ReqSourceId1 = 5388, ReqSourceCount1 = 1 WHERE entry = 1045;
UPDATE quest_template SET ReqSourceId1 = 5695, ReqSourceCount1 = 1, ReqSourceId2 = 5694, ReqSourceCount2 = 1 WHERE entry = 1079;
UPDATE quest_template SET ReqSourceId1 = 5687, ReqSourceCount1 = 1 WHERE entry = 1089;
UPDATE quest_template SET ReqSourceId1 = 17345, ReqSourceCount1 = 9999999 WHERE entry = 1126;
UPDATE quest_template SET ReqSourceId1 = 5810, ReqSourceCount1 = 1 WHERE entry = 1136;
UPDATE quest_template SET ReqSourceId1 = 5845, ReqSourceCount1 = 1 WHERE entry = 1150;
UPDATE quest_template SET ReqSourceId1 = 5851, ReqSourceCount1 = 1 WHERE entry = 1182;
UPDATE quest_template SET ReqSourceId1 = 5867, ReqSourceCount1 = 1 WHERE entry = 1195;
UPDATE quest_template SET ReqSourceId1 = 6074, ReqSourceCount1 = 1 WHERE entry = 1380;
UPDATE quest_template SET ReqSourceId1 = 6074, ReqSourceCount1 = 1 WHERE entry = 1381;
UPDATE quest_template SET ReqSourceId1 = 6766, ReqSourceCount1 = 1 WHERE entry = 1435;
UPDATE quest_template SET ReqSourceId1 = 6783, ReqSourceCount1 = 1 WHERE entry = 1667;
UPDATE quest_template SET ReqSourceId1 = 7131, ReqSourceCount1 = 999 WHERE entry = 1846;
UPDATE quest_template SET ReqSourceId1 = 7208, ReqSourceCount1 = 1 WHERE entry = 1858;
UPDATE quest_template SET ReqSourceId1 = 7273, ReqSourceCount1 = 10 WHERE entry = 1948;
UPDATE quest_template SET ReqSourceId1 = 8049, ReqSourceCount1 = 1 WHERE entry = 2459;
UPDATE quest_template SET ReqSourceId1 = 9320, ReqSourceCount1 = 20, ReqSpellCast1 = 11547 WHERE entry = 2932;
UPDATE quest_template SET ReqSourceId1 = 9472, ReqSourceCount1 = 1, ReqSpellCast2 = 11792 WHERE entry = 2994;
UPDATE quest_template SET ReqSourceId1 = 9530, ReqSourceCount1 = 1 WHERE entry = 3062;
UPDATE quest_template SET ReqSourceId1 = 10663, ReqSourceCount1 = 1 WHERE entry = 3528;
UPDATE quest_template SET ReqSourceId1 = 11242, ReqSourceCount1 = 1 WHERE entry = 3909;
UPDATE quest_template SET ReqSourceId1 = 11147, ReqSourceCount1 = 1, ReqSourceId2 = 11148, ReqSourceCount2 = 5 WHERE entry = 3924;
UPDATE quest_template SET ReqSourceId1 = 12230, ReqSourceCount1 = 100 WHERE entry = 4293;
UPDATE quest_template SET ReqSourceId1 = 12235, ReqSourceCount1 = 100 WHERE entry = 4294;
UPDATE quest_template SET ReqSourceId1 = 12341, ReqSourceCount1 = 1, ReqSourceId2 = 12342, ReqSourceCount2 = 1 WHERE entry = 4763;
UPDATE quest_template SET ReqSourceId1 = 12722, ReqSourceCount1 = 1 WHERE entry = 5051;
UPDATE quest_template SET ReqSourceId1 = 12733, ReqSourceCount1 = 1 WHERE entry = 5056;
UPDATE quest_template SET ReqSourceId1 = 12814, ReqSourceCount1 = 1, ReqSpellCast1 = 16989 WHERE entry = 5096;
UPDATE quest_template SET ReqSourceId1 = 12886, ReqSourceCount1 = 1, ReqSourceId2 = 12887, ReqSourceCount2 = 1 WHERE entry = 5149;
UPDATE quest_template SET ReqSourceId1 = 13157, ReqSourceCount1 = 99 WHERE entry = 5206;
UPDATE quest_template SET ReqSourceId1 = 18501, ReqSourceCount1 = 1 WHERE entry = 5526;
UPDATE quest_template SET ReqSourceId1 = 15447, ReqSourceCount1 = 7 WHERE entry = 6022;
UPDATE quest_template SET ReqSourceId1 = 15874, ReqSourceCount1 = 10 WHERE entry = 6142;
UPDATE quest_template SET ReqSourceId1 = 16333, ReqSourceCount1 = 1, ReqSpellCast1 = 20364 WHERE entry = 6395;
UPDATE quest_template SET ReqSourceId1 = 17757, ReqSourceCount1 = 1 WHERE entry = 7067;
UPDATE quest_template SET ReqSourceId1 = 18749, ReqSourceCount1 = 1 WHERE entry = 7647;
UPDATE quest_template SET ReqSourceId1 = 19881, ReqSourceCount1 = 5 WHERE entry = 8201;
UPDATE quest_template SET ReqSourceId1 = 22046, ReqSourceCount1 = 1 WHERE entry = 8989;
UPDATE quest_template SET ReqSourceId1 = 22046, ReqSourceCount1 = 1 WHERE entry = 8990;
UPDATE quest_template SET ReqSourceId1 = 22046, ReqSourceCount1 = 1 WHERE entry = 8991;
UPDATE quest_template SET ReqSourceId1 = 22046, ReqSourceCount1 = 1 WHERE entry = 8992;
UPDATE quest_template SET ReqSourceId1 = 51837, ReqSourceCount1 = 1 WHERE entry = 39991;
UPDATE quest_template SET ReqSourceId1 = 51837, ReqSourceCount1 = 1 WHERE entry = 39992;
UPDATE quest_template SET ReqSourceId1 = 51837, ReqSourceCount1 = 1 WHERE entry = 39993;
UPDATE quest_template SET ReqSourceId1 = 60246, ReqSourceCount1 = 1 WHERE entry = 40175;
-- Extra: 4 entries where ReqSourceId2 was independently tracking items
-- but got zeroed out by the upstream REPLACE INTO
UPDATE quest_template SET ReqSourceId1 = 0, ReqSourceCount1 = 0, ReqSourceId2 = 8429, ReqSourceCount2 = 30 WHERE entry = 2605;
UPDATE quest_template SET ReqSourceId1 = 0, ReqSourceCount1 = 0, ReqSourceId2 = 10839, ReqSourceCount2 = 1 WHERE entry = 3602;
UPDATE quest_template SET ReqSourceId2 = 11172, ReqSourceCount2 = 11 WHERE entry = 4005;
UPDATE quest_template SET ReqSourceId1 = 0, ReqSourceCount1 = 0, ReqSourceId2 = 15875, ReqSourceCount2 = 1 WHERE entry = 6146;
