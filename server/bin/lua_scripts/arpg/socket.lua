-- socket.lua — 1-8 拉玛兰迪打孔器（为装备打孔，增加宝石槽）
-- 阶段1 A级第8项 ｜ 依据：ARPG系统移植计划书.md 1-8 / 素材01 系统13
-- 机制：打孔记录 tw_char.soulcore_arpg_sockets (player_guid, item_guid, holes)
--       gem.lua 读该表决定装备可用宝石槽数（基础 1 槽=槽3，打孔后槽5 也可用）
-- ⚠️ v3：MAX_HOLES 2→1（2026-08-10 决策）。每件装备只有 1 个扩展宝石槽
--      （槽5，槽4 归符文），打 2 孔无槽可用纯浪费打孔器。
-- ⚠️ item use 返回 false 才阻止施法；item gossip 用 GossipSendMenu(1, item)
-- ⚠️ GetRow 只取当前行不推进游标（本引擎），单次调用取首行安全（踩坑#12）

local PUNCHER = 905010      -- 拉玛兰迪的礼物
local MAX_HOLES = 1         -- 每件装备最多打 1 孔（→ 2 颗宝石：槽3 + 槽5）

local function GetHoles(playerGuid, itemGuid)
    local ok, q = pcall(function()
        return CharDBQuery("SELECT holes FROM soulcore_arpg_sockets WHERE player_guid=" .. playerGuid .. " AND item_guid=" .. itemGuid)
    end)
    if ok and q then
        local ok2, row = pcall(function()
            local r = q:GetRow()
            return r and tonumber(r[1]) or 0
        end)
        return ok2 and row or 0
    end
    return 0
end

local function OnPuncherUse(event, player, item)
    player:GossipClearMenu()
    local listed = 0
    for slot = 0, 18 do
        local eq = player:GetEquippedItemBySlot(slot)
        if eq then
            local guid = eq:GetGUIDLow()
            local holes = GetHoles(player:GetGUIDLow(), guid)
            if holes < MAX_HOLES then
                listed = listed + 1
                player:GossipMenuAddItem(0, "给 " .. (eq:GetName() or "?") .. " 打孔（当前 " .. (holes + 1) .. "/" .. (MAX_HOLES + 1) .. " 槽）", 0, 100 + listed)
            end
        end
    end
    if listed == 0 then
        player:GossipMenuAddItem(0, "|cffff0000没有可打孔的装备（均已满 " .. MAX_HOLES .. " 孔）", 0, 99)
    end
    player:GossipMenuAddItem(0, "关闭", 0, 99)
    player:GossipSendMenu(1, item)
    return false
end

local function OnPuncherSelect(event, player, item, sender, action, code)
    if not item or action < 100 then
        player:GossipComplete()
        return
    end
    local target = nil
    local listed = 0
    for slot = 0, 18 do
        local eq = player:GetEquippedItemBySlot(slot)
        if eq then
            local holes = GetHoles(player:GetGUIDLow(), eq:GetGUIDLow())
            if holes < MAX_HOLES then
                listed = listed + 1
                if listed == action - 100 then
                    target = eq
                    break
                end
            end
        end
    end
    if not target then
        player:SendBroadcastMessage("|cffff0000[打孔]|r 目标装备不存在或已满孔")
        player:GossipComplete()
        return
    end
    local pg, ig = player:GetGUIDLow(), target:GetGUIDLow()
    local holes = GetHoles(pg, ig) + 1
    local ok, err = pcall(function()
        CharDBExecute("REPLACE INTO soulcore_arpg_sockets (player_guid, item_guid, holes) VALUES (" .. pg .. "," .. ig .. "," .. holes .. ")")
    end)
    if not ok then
        player:SendBroadcastMessage("|cffff0000[打孔]|r 写入打孔记录失败: " .. tostring(err))
        player:GossipComplete()
        return
    end
    player:RemoveItem(PUNCHER, 1)
    player:SendBroadcastMessage("|cff00ff00[打孔]|r " .. (target:GetName() or "?") .. " 已打孔，现在可镶嵌 " .. (holes + 1) .. " 颗宝石")
    player:GossipComplete()
end

RegisterItemEvent(PUNCHER, 2, OnPuncherUse)
RegisterItemGossipEvent(PUNCHER, 2, OnPuncherSelect)

print("[ARPG] socket.lua loaded — 拉玛兰迪打孔器已启用 (905010)")
