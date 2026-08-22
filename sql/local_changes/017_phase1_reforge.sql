-- ============================================================
-- 017_phase1_reforge.sql — 1-7 套装重铸石（904003）
-- ============================================================
-- 来源：ARPG系统移植计划书.md 1-7（套装重铸，5% 失败消失）
-- 机制：reforge.lua 右键重铸石 → 列背包带 set_id 的装备 →
--       查同 set_id 其他部件 → 随机转换（优先同部位）；5% 概率失败物品消失
-- 目标库：tw_world
-- 幂等：临时表 REPLACE SELECT（重放多次结果一致）
-- ⚠️ 造物品不手写全列：临时表复制模板 7910 改字段，REPLACE SELECT 入库（踩坑#8）
-- ============================================================

CREATE TEMPORARY TABLE `tw_world`.`_tmp_item` AS SELECT * FROM `tw_world`.`item_template` WHERE entry = 7910;
UPDATE `tw_world`.`_tmp_item` SET
    entry = 904003,
    name = '混沌重铸石',
    description = '对一件套装部件使用，随机转换为同套装的其他部件（优先同部位，有 5% 几率失败并消失）',
    quality = 4,
    max_count = 20,
    spellid_1 = 8690,        -- 载体法术（右键触发），脚本 return false 阻止
    spelltrigger_1 = 0,
    spellcooldown_1 = 1000;
REPLACE INTO `tw_world`.`item_template` SELECT * FROM `tw_world`.`_tmp_item`;
DROP TEMPORARY TABLE `tw_world`.`_tmp_item`;
