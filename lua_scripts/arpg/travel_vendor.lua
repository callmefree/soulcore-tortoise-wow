-- travel_vendor.lua — 1-2 随身小伙伴（技能书召唤随身商贩）
-- 阶段1 A级第2项 ｜ 依据：ARPG系统移植计划书.md 1-2 / 素材01 系统18
-- 实现：item 905001 使用 → 玩家面前 SummonCreature 190105（随身商贩），90 秒自动消失
-- ⚠️ 本引擎布尔语义与官方相反：item use 事件 expectedValue=false → 返回 false 才阻止施法
--     （阶段0落地报告坑3 / 工作记录铁律）——召唤成功后 return false 阻止原施法

local VENDOR_BOOK = 905001   -- 技能书：随身商贩
local VENDOR_NPC  = 190105   -- 随身商贩（npc_flags=128 VENDOR + 15 件货物）
local DESPAWN_MS  = 90000    -- 90 秒

local function OnVendorBookUse(event, player, item)
    if not player or not item then return true end  -- 防御

    local x, y, z, o = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
    -- 玩家面前 3 码召唤
    local fx = x + math.cos(o) * 3
    local fy = y + math.sin(o) * 3

    local ok, err = pcall(function()
        -- SummonCreature(entry, x, y, z, o, summonType=1 TIMED_OR_DEAD_DESPAWN, despawnTime=90000)
        local npc = player:SummonCreature(VENDOR_NPC, fx, fy, z, o, 1, DESPAWN_MS)
        return npc ~= nil
    end)
    if ok then
        player:SendBroadcastMessage("|cff00ff00[随身商贩]|r 召唤成功，90 秒后消失（再点技能书可重新召唤）")
    else
        player:SendBroadcastMessage("|cffff0000[随身商贩]|r 召唤失败: " .. tostring(err))
    end
    return false  -- 阻止原施法（本引擎 item use 返回 false 才阻止）
end

RegisterItemEvent(VENDOR_BOOK, 2, OnVendorBookUse)  -- 2 = ITEM_EVENT_ON_USE

print("[ARPG] travel_vendor.lua loaded — 随身商贩已启用 (905001)")
