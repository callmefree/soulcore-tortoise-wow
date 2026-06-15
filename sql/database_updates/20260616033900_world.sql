-- ============================================================================
-- Sacred Chalice: Switch from spell 36607 to existing spell 35999
--
-- Issue: Commit c02c807 created a new spell 36607 for Sacred Chalice, but
-- spell 35999 already existed with the correct data. This update switches
-- the collection_toy mapping to use 35999 and cleans up.
--
-- Turtle-WoW 1.18
-- Date: 2026-06-16
-- ============================================================================

-- 1. Redirect Sacred Chalice toy to existing spell 35999
UPDATE `collection_toy` SET `spellId` = 35999 WHERE `itemId` = 31827;

-- 2. Update spell 35999 visuals to Moonwell-appropriate values
--    (was using forge kit visuals: 5499/289)
UPDATE `spell_template` SET
    `spellVisual1` = 1168,
    `spellIconId` = 69
WHERE `entry` = 35999;
