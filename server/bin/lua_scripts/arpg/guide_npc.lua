-- guide_npc.lua — 1-1 新手引导（艾薇儿 NPC 190101）
-- 阶段1 A级第1项 ｜ 依据：ARPG系统移植计划书.md 1-1 / 素材01 系统19
-- 实现：creature gossip 菜单：欢迎 → 领取新手奖励（技能书 905001 随身商贩）
-- ⚠️ gossip 三规范（阶段0落地报告/工作记录）：GossipClearMenu 防叠加；sender=0+action=编号；intid=action
-- ⚠️ 本引擎 creature gossip 路径 OnCreatureGossipHello 不会自动清菜单，handler 开头必须 GossipClearMenu

local GUIDE_NPC   = 190101   -- 艾薇儿
local VENDOR_BOOK = 905001   -- 技能书：随身商贩

local function GossipHello(event, player, creature)
    player:GossipClearMenu()  -- 必须：防菜单叠加
    player:GossipMenuAddItem(0, "我是新来的，能给我些帮助吗？", 0, 1)
    player:GossipMenuAddItem(0, "这个服务器有什么特色玩法？", 0, 2)
    player:GossipMenuAddItem(0, "再见。", 0, 3)
    player:SendGossipMenu(1, creature)
end

local function GossipSelect(event, player, creature, sender, intid, code)
    if intid == 1 then
        -- 领取新手奖励：随身商贩技能书
        if player:HasItem(VENDOR_BOOK) then
            player:SendBroadcastMessage("[艾薇儿] 你已经领过随身商贩了，去使用它吧！")
        else
            -- ⚠️ AddItem 返回布尔（L5284），满包 false → 不发奖励但允许重新领（不置 HasItem 状态）
            local ok, added = pcall(function()
                return player:AddItem(VENDOR_BOOK, 1)
            end)
            if ok and added then
                player:SendBroadcastMessage("|cff00ff00[艾薇儿]|r 送你一本《技能书：随身商贩》，右键使用可召唤随身商贩，90 秒后消失。")
                player:SendBroadcastMessage("|cffff6600[提示]|r 以后可在拍卖行/副本门口随时召唤商贩，方便清理背包。")
            else
                player:SendBroadcastMessage("|cffff0000[艾薇儿]|r 背包已满，无法领取技能书！清出空间后再来。")
            end
        end
    elseif intid == 2 then
        player:SendBroadcastMessage("|cff00ff00[ARPG 玩法]|r 本服移植了暗黑3/流放之路玩法：装备词缀、三色球、混沌石升级装备、红装、副本通行证等，详见后续更新。")
    elseif intid == 3 then
        -- 再见
    end
    player:GossipComplete()
end

RegisterCreatureGossipEvent(GUIDE_NPC, 1, GossipHello)
RegisterCreatureGossipEvent(GUIDE_NPC, 2, GossipSelect)

print("[ARPG] guide_npc.lua loaded — 艾薇儿新手引导已启用 (190101)")
