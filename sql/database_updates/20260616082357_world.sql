-- ============================================
-- Fix: Trial of the Lake (quest 28/29)
-- Issue: Bauble Container (GO 177785) could not
--        be looted due to two problems:
--   1. quest_template ReqSourceId1 was 0 (item 15877
--      not visible as quest drop)
--   2. spell 19719 had effect1=61(SEND_EVENT) instead
--      of 33(OPEN_LOCK), so the lock (lockId=93) on
--      Bauble Container could not be opened
-- ============================================

-- Layer 1: Restore quest drop visibility
UPDATE quest_template
SET ReqSourceId1 = 15877, ReqSourceCount1 = 1
WHERE entry IN (28, 29);

-- Layer 2: Fix spell effect to OPEN_LOCK matching Lock 93
UPDATE spell_template SET
    effect1 = 33,              -- SPELL_EFFECT_OPEN_LOCK
    effectMiscValue1 = 12,     -- Lock 93 type: OPEN_TINKERING
    requiresSpellFocus = 0     -- No focus requirement
WHERE entry = 19719;
