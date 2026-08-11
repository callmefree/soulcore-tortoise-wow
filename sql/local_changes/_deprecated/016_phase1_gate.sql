-- ============================================================
-- 016_phase1_gate.sql — 1-9 符文门控系统（持有对应符文才能激活高级物品）
-- ============================================================
-- 来源：ARPG系统移植计划书.md 1-9（原"传家宝符文激活"因 Turtle 1.12 无传家宝
--       体系，2026-08-10 用户决策改为"符文门控系统"，见工作记录）
-- 机制：tw_char.soulcore_arpg_gate 配置 item_entry → 所需 rune_entry；
--       gate.lua 启动读表缓存，item use 时检查持有符文（不消耗），
--       通过则消耗物品 + 发奖励（reward_item=0 表示随机 1 级宝石）
-- 目标库：tw_char + tw_world（本文件用全限定名，任意默认库重放均可）
-- 幂等：CREATE TABLE IF NOT EXISTS / REPLACE / 临时表 REPLACE SELECT
-- ⚠️ 造物品不手写全列：临时表复制模板 7910 改字段，REPLACE SELECT 入库（踩坑#8）
-- ============================================================

-- ============ 1. 门控配置表（tw_char）——DDL 放文件最前 ============
CREATE TABLE IF NOT EXISTS `tw_char`.`soulcore_arpg_gate` (
    `item_entry`  int(10) unsigned NOT NULL COMMENT '被门控物品 entry',
    `rune_entry`  int(10) unsigned NOT NULL COMMENT '所需符文 entry（持有即可，不消耗）',
    `reward_item` int(10) unsigned NOT NULL DEFAULT 0 COMMENT '激活奖励物品；0=随机 1 级宝石',
    `descr`       varchar(255) DEFAULT NULL COMMENT '门控说明（提示文案用）',
    PRIMARY KEY (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ============ 2. 演示门控物品：远古符文卷轴 905004 ============
-- 模板 7910（宝石，与 ARPG 其他物品同源）→ 临时表 → 改字段 → REPLACE 入库
CREATE TEMPORARY TABLE `tw_world`.`_tmp_item` AS SELECT * FROM `tw_world`.`item_template` WHERE entry = 7910;
UPDATE `tw_world`.`_tmp_item` SET
    entry = 905004,
    name = '远古符文卷轴',
    description = '需要持有 30 号符文 Ber（暴击+2%）才能激活：随机获得 1 颗 1 级宝石',
    quality = 4,
    max_count = 10,
    spellid_1 = 8690,        -- 载体法术（右键触发），脚本 return false 阻止
    spelltrigger_1 = 0,
    spellcooldown_1 = 3600000;
REPLACE INTO `tw_world`.`item_template` SELECT * FROM `tw_world`.`_tmp_item`;
DROP TEMPORARY TABLE `tw_world`.`_tmp_item`;

-- ============ 3. 门控配置（幂等 REPLACE） ============
REPLACE INTO `tw_char`.`soulcore_arpg_gate` (item_entry, rune_entry, reward_item, descr)
VALUES (905004, 900030, 0, '随机 1 级宝石（4 色）');
