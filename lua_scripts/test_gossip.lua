-- NPC gossip 测试 (creature entry 190001, 已入库 tw_world)
-- 第二阶段修正: creature:GossipMenuAddItem -> player:GossipMenuAddItem; player:GossipMenu -> player:SendGossipMenu
-- (GossipMenuAddItem/SendGossipMenu 均为 Player 方法, TurtleLuaEngine.cpp:8344/8360)

local function GossipHello(event, player, creature)
    player:GossipMenuAddItem(0, "查看我的信息", 1, 0)
    player:GossipMenuAddItem(0, "给我一个炉石", 2, 0)
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
