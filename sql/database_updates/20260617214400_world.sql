-- ==============================================
-- 修复 Gemology 分支法术 57551 的空操作 effect
-- effect1 改为 SPELL_EFFECT_LEARN_SPELL (36)
-- 使得任务 41282 "The Final Cut" 完成时正确学会宝石学
-- ==============================================

UPDATE spell_template
SET effect1 = 36,
    effectTriggerSpell1 = 57551
WHERE entry = 57551;
