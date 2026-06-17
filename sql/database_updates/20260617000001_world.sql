-- Fix Crusader Strike family flags for Righteous/Blessed Strikes proc chain
-- ============================================================================
-- Problem: Righteous Strikes (51341-51345) uses SPELL_AURA_ADD_TARGET_TRIGGER
-- to proc Zealous Defense on Crusader Strike hits. But Crusader Strike spells
-- have SpellFamilyName=0 (no family), so:
--   1. CanProcFrom() in HandleTriggers blocks the proc (family mask mismatch)
--   2. Spell::HandleAddTargetTriggerAuras() also blocked (isAffectedOnSpell)
--
-- Fix: Populate SpellFamilyName=10 (Paladin) and SpellFamilyFlags=34359738368
-- (bit 35 = CF_PALADIN_CRUSADER_STRIKE) for all Crusader Strike spell IDs
-- via spell_mod.
--
-- Also covers old vanilla CS IDs (7297, 8825, 8826) that may still be
-- referenced by existing characters or talent systems.
-- ============================================================================

REPLACE INTO `spell_mod` (`Id`, `SpellFamilyName`, `SpellFamilyFlags`, `Comment`)
VALUES
    (47314, 10, 34359738368, 'Crusader Strike rank 1: paladin family + CF_PALADIN_CRUSADER_STRIKE'),
    (47315, 10, 34359738368, 'Crusader Strike rank 2'),
    (47316, 10, 34359738368, 'Crusader Strike rank 3'),
    (47317, 10, 34359738368, 'Crusader Strike rank 4'),
    (47318, 10, 34359738368, 'Crusader Strike rank 5'),
    (7297,  10, 34359738368, 'Crusader Strike rank 1 old'),
    (8825,  10, 34359738368, 'Crusader Strike rank 2 old'),
    (8826,  10, 34359738368, 'Crusader Strike rank 3 old');
