-- ============================================================
-- 018_irp_p1_pool_50001.sql — P1-A 随机附魔权重池 entry=50001
-- ============================================================
-- 来源: outputs/p1_weight_50001.sql（2026-08-21 P1-A，PB 服）
-- 目标库: tw_pb_world   前置: P1 探针 DBC 已部署
-- 状态: ✅ 已应用（2026-08-21）
-- 说明: 绿装随机词缀三选一 33% 平权池；ench = 原生 SIE ID

-- P1-A 权重池：tw_pb_world.item_enchantment_template entry=50001 -> [5, 754, 115000] 三选一 33%平权
DELETE FROM item_enchantment_template WHERE entry=50001;
INSERT INTO item_enchantment_template (entry, ench, chance) VALUES
(50001, 5,     33.33),
(50001, 754,   33.33),
(50001, 115000,33.34);
SELECT entry, COUNT(*) c, SUM(chance) s FROM item_enchantment_template WHERE entry=50001 GROUP BY entry;
SELECT entry, ench, chance FROM item_enchantment_template WHERE entry=50001 ORDER BY ench;

