-- ============================================================
-- 002_account_rank.sql — admin 升 SEC_ADMINISTRATOR(rank=4)
-- 目标库: tw_logon
--
-- 原因（2026-08-09 运行时实测）:
--   .reload eluna 等 admin 级命令需 rank=4。turtle 权限等级:
--   SEC_PLAYER=0 / SEC_GAMEMASTER=2 / SEC_DEVELOPER=3 / SEC_ADMINISTRATOR=4
--   原 admin rank=3 执行 .reload eluna 报"您无法使用此命令"。
--   （RBAC 表无 reload 条目, 纯等级不够）
--
-- 用法: mysql --default-character-set=utf8 tw_logon < 002_account_rank.sql
-- 幂等: 重复执行无害（已是 4 则影响 0 行）。登录时读取, 改后需重登生效。
-- ============================================================

UPDATE `tw_logon`.`account` SET `rank` = 4 WHERE `id` = 4 AND `username` = 'admin';
