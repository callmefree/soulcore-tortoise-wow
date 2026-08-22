-- ============================================================
-- 015_phase1_punch_ddl.sql — 拉玛兰迪打孔记录表（独立 DDL）
-- ============================================================
-- 来源：自 014 文件末尾段拆出。014 曾因 `||`（MySQL 逻辑或）bug
--       导致整段后续 SQL 未执行 → 打孔表缺失 → gem/socket 事件崩。
--       教训：重要 DDL 单独成文件（见工作记录踩坑 #4）。
-- 目标库：tw_char ｜ 幂等：CREATE TABLE IF NOT EXISTS
-- 表语义：player_guid + item_guid → 孔数（基础 1 槽 + 每打孔 +1）
-- ============================================================

CREATE TABLE IF NOT EXISTS `soulcore_arpg_sockets` (
    `player_guid` bigint(20) unsigned NOT NULL,
    `item_guid`   bigint(20) unsigned NOT NULL,
    `holes`       tinyint(3) unsigned NOT NULL DEFAULT 1,
    PRIMARY KEY (`player_guid`, `item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
