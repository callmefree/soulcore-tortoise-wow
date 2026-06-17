-- REVERT: Restore Naxxramas Gargoyle Stoneskin (28995) original effects
-- Original data from DBC extraction

UPDATE spell_template SET
    effect1 = 6,
    effectApplyAuraName1 = 8,
    effectBasePoints1 = 99999,
    effectDieSides1 = 1,
    effect2 = 6,
    effectApplyAuraName2 = 40,
    effectMiscValue2 = 127
WHERE entry = 28995;
