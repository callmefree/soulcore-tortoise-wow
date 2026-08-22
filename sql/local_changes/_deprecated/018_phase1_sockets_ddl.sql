-- ============================================================
-- 018_phase1_sockets_ddl.sql — 1-8 打孔记录表 DDL（tw_char）
-- ============================================================
-- 目的：015_phase1_punch_ddl.sql 已删除（2026-08-10 撤回时移除），
--       但 socket.lua / gem.lua 依赖 soulcore_arpg_sockets 表（1-8 硬前置）。
--       本文件为重建副本，表结构与实测一致（2026-08-11 SHOW CREATE TABLE 核对）。
-- 目标库：tw_char ｜ 幂等：CREATE TABLE IF NOT EXISTS（可安全重放）
-- ⚠️ 014_phase1_rune_punch.sql 头注释原指向已删的 015，已改为本文件（审计 2026-08-11 修复）。
-- ============================================================

CREATE TABLE IF NOT EXISTS `tw_char`.`soulcore_arpg_sockets` (
  `player_guid` bigint(20) unsigned NOT NULL,
  `item_guid` bigint(20) unsigned NOT NULL,
  `holes` tinyint(3) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`player_guid`,`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
