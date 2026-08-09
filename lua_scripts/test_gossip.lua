-- NPC gossip 测试 (creature entry 190001, 已入库 tw_world)
-- 第二阶段修正: creature:GossipMenuAddItem -> player:GossipMenuAddItem; player:GossipMenu -> player:SendGossipMenu
-- (GossipMenuAddItem/SendGossipMenu 均为 Player 方法, TurtleLuaEngine.cpp:8344/8360)
-- 2026-08-09 修复:
--   1) handler 开头必须 player:GossipClearMenu() —— turtle Eluna 的 creature gossip
--      路径(OnCreatureGossipHello)不会自动清空旧菜单, 不清会导致菜单反复叠加。
--   2) GossipMenuAddItem(icon, msg, sender, action) 第3参数=sender/第4参数=action;
--      GossipSelect 回调参数(event, player, creature, sender, intid, code) 中 intid=action。
--      约定 sender=0 + action=编号 分发(与 super_hearthstone.lua 一致), 避免判断错位。

local function GossipHello(event, player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, "查看我的信息", 0, 1)
    player:GossipMenuAddItem(0, "给我一个炉石", 0, 2)
    player:SendGossipMenu(1, creature)
end

local function GossipSelect(event, player, creature, sender, intid, code)
    if intid == 1 then
        player:SendBroadcastMessage("[Eluna] 你的名字: " .. player:GetName() .. ", 等级: " .. player:GetLevel())
    elseif intid == 2 then
        player:AddItem(6948, 1)
        player:SendBroadcastMessage("[Eluna] 已给你一个炉石!")
    end
    player:GossipComplete()
end

RegisterCreatureGossipEvent(190001, 1, GossipHello)
RegisterCreatureGossipEvent(190001, 2, GossipSelect)
