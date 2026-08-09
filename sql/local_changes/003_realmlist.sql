-- ============================================================
-- 003_realmlist.sql — realmlist 初始化/修正（新库必备）
-- 目标库: tw_logon
--
-- 注意:
--   1) id 必须 = 1（服务端 RealmID=1, 自增可能到 2 需改回）;
--   2) realmbuilds 会被 mangosd 启动自动覆盖为 '5875 '（客户端 build, 正确）;
--   3) 客户端连 realmd 3724, mangosd 实际端口 8090（Turtle 非 8085）。
--
-- 用法: mysql --default-character-set=utf8 tw_logon < 003_realmlist.sql
-- 幂等: 已存在则跳过插入 + UPDATE 修正关键字段, 重复执行无害。
-- ============================================================

-- 不存在时插入（id=1 兜底）
INSERT IGNORE INTO `realmlist` (`id`, `name`, `address`, `port`, `icon`, `realmflags`, `timezone`, `allowedSecurityLevel`, `population`, `realmbuilds`)
VALUES (1, 'Turtle WoW', '127.0.0.1', 8090, 6, 0, 1, 0, 0, '5875');

-- 确保关键字段正确（幂等）
UPDATE `realmlist`
SET `name` = 'Turtle WoW', `address` = '127.0.0.1', `port` = 8090,
    `icon` = 6, `realmflags` = 0, `timezone` = 1,
    `allowedSecurityLevel` = 0, `realmbuilds` = '5875'
WHERE `id` = 1;
