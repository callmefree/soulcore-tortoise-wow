-- Disable Naxxramas Gargoyle Stoneskin (28995) heal effect
-- Stoneskin: effect1 was SPELL_EFFECT_APPLY_AURA (6) with SPELL_AURA_PERIODIC_HEAL (8) at 99999 base points per 1s tick
-- Effect2 was SPELL_AURA_SCHOOL_IMMUNITY (40) with miscValue=127 (all schools)
-- Players reported the gargoyle healing to full in 3 seconds even when out of mana
-- Fix: clear both effects to make the spell a no-op

UPDATE spell_template SET
    effect1 = 0,
    effectApplyAuraName1 = 0,
    effectBasePoints1 = 0,
    effectDieSides1 = 0,
    effect2 = 0,
    effectApplyAuraName2 = 0,
    effectMiscValue2 = 0
WHERE entry = 28995;
