-- gem.lua v3 — 1-5 四色宝石（支持打孔双槽：槽3 基础 + 槽5 打孔后可用）
-- 阶段1 A级第5项 ｜ 依据：ARPG系统移植计划书.md 1-5/1-8
-- v3 改进：读 soulcore_arpg_sockets 表判断装备宝石槽数（socket.lua 打孔）
-- v3.1：清理注释（槽位定稿：槽3 基础 / 槽4 符文 / 槽5 打孔扩展，互不冲突）
-- 机制：右键 → gossip 菜单选装备镶嵌 / 取下返还；附魔随装备持久
-- ⚠️ item use 返回 false 才阻止施法；item gossip 用 GossipSendMenu(1, item)
-- ⚠️ 注意：红宝石附魔 ID(68/69/70/106/107) 与符文 1-5 相同，黄/绿/紫同理——
--    ENCH2ENTRY 反向映射仅用于取下宝石返还，扫的是槽3/槽5，不会碰到符文槽4。

local GEM_SLOT_BASE = 3     -- 基础槽 PROP_ENCHANTMENT_SLOT_0
local GEM_SLOT_EXT = 5      -- 打孔扩展槽 PROP_ENCHANTMENT_SLOT_2（槽4 归符文，勿用）
local MAX_SAME = 2
local GEMS = {
    [901001] = { color = "red",    ench = {68, 69, 70, 106, 107} },
    [901006] = { color = "yellow", ench = {79, 80, 81, 94, 95} },
    [901011] = { color = "green",  ench = {74, 75, 76, 90, 91} },
    [901016] = { color = "purple", ench = {71, 72, 73, 102, 103} },
}
local COLOR_NAMES = { red = "红", yellow = "黄", green = "绿", purple = "紫" }

local ENCH2ENTRY, ENCH2COLOR = {}, {}
for e, cfg in pairs(GEMS) do
    for lv, eid in ipairs(cfg.ench) do
        ENCH2ENTRY[eid] = e + (lv - 1)
        ENCH2COLOR[eid] = cfg.color
    end
end

-- 读打孔数（pcall 防御：表/查询异常时返回 0，不崩事件）
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

-- 装备可用宝石槽列表
local function GetSlots(eq, playerGuid)
    local slots = { GEM_SLOT_BASE }
    local holes = GetHoles(playerGuid, eq:GetGUIDLow())
    if holes >= 1 then slots[#slots + 1] = GEM_SLOT_EXT end
    return slots
end

-- 扫描装备：空槽 + 已嵌
local function ScanEquip(player)
    local pg = player:GetGUIDLow()
    local empty, gemmed = {}, {}
    for slot = 0, 18 do
        local eq = player:GetEquippedItemBySlot(slot)
        if eq then
            local slots = GetSlots(eq, pg)
            local filled = 0
            for _, s in ipairs(slots) do
                local eid = eq:GetEnchantmentId(s)
                if eid and eid > 0 then
                    filled = filled + 1
                    gemmed[#gemmed + 1] = { item = eq, slot = s, ench = eid, entry = ENCH2ENTRY[eid] }
                else
                    empty[#empty + 1] = { item = eq, slot = s }
                end
            end
            -- 简化显示：一件装备只列一次（若至少有一个空槽）
        end
    end
    return empty, gemmed
end

local function ColorCount(gemmed, color)
    local n = 0
    for _, g in ipairs(gemmed) do
        if ENCH2COLOR[g.ench] == color then n = n + 1 end
    end
    return n
end

local function OnGemUse(event, player, item)
    local cfg = GEMS[item:GetEntry()]
    if not cfg then return true end
    local empty, gemmed = ScanEquip(player)
    local sameCount = ColorCount(gemmed, cfg.color)

    player:GossipClearMenu()
    if sameCount >= MAX_SAME then
        player:GossipMenuAddItem(0, "|cffff0000同色宝石已满（" .. COLOR_NAMES[cfg.color] .. " " .. sameCount .. "/" .. MAX_SAME .. "）", 0, 99)
    else
        if #empty == 0 then
            player:GossipMenuAddItem(0, "|cffff0000没有空余宝石槽（可取下旧宝石或用拉玛兰迪的礼物打孔）", 0, 99)
        else
            local seen = {}
            for i, e in ipairs(empty) do
                local key = tostring(e.item:GetGUIDLow())
                if not seen[key] then
                    seen[key] = true
                    local name = e.item:GetName() or "?"
                    player:GossipMenuAddItem(0, "镶嵌到 " .. name, 0, 100 + i)
                end
            end
        end
    end
    if #gemmed > 0 then
        player:GossipMenuAddItem(0, "|cff66ccff取下宝石（" .. #gemmed .. " 颗，返还宝石）", 0, 90)
    end
    player:GossipMenuAddItem(0, "关闭", 0, 99)
    player:GossipSendMenu(1, item)
    return false
end

local function DoSocket(player, item, target)
    local cfg = GEMS[item:GetEntry()]
    local entry = item:GetEntry()
    local level = (entry - 1) % 5 + 1
    local ok, err = pcall(function()
        return target.item:SetEnchantment(cfg.ench[level], target.slot)
    end)
    if ok then
        player:RemoveItem(entry, 1)
        player:SendBroadcastMessage("|cff00ff00[宝石]|r " .. COLOR_NAMES[cfg.color] .. "宝石 Lv" .. level .. " 已镶嵌")
    else
        player:SendBroadcastMessage("|cffff0000[宝石]|r 镶嵌失败: " .. tostring(err))
    end
end

local function ShowRemoveMenu(player, item)
    local _, gemmed = ScanEquip(player)
    player:GossipClearMenu()
    if #gemmed == 0 then
        player:GossipMenuAddItem(0, "没有可取的宝石", 0, 99)
    else
        local seen = {}
        for i, g in ipairs(gemmed) do
            local key = tostring(g.item:GetGUIDLow())
            if not seen[key] then
                seen[key] = true
                local color = ENCH2COLOR[g.ench] and COLOR_NAMES[ENCH2COLOR[g.ench]] or "?"
                player:GossipMenuAddItem(0, "取下 " .. color .. "宝石（" .. (g.item:GetName() or "?") .. "）", 1, 200 + i)
            end
        end
    end
    player:GossipMenuAddItem(0, "返回", 1, 0)
    player:GossipSendMenu(1, item)
end

local function DoRemove(player, idx)
    local _, gemmed = ScanEquip(player)
    local g = gemmed[idx]
    if not g then
        player:SendBroadcastMessage("|cffff0000[宝石]|r 该装备已无宝石")
        return
    end
    local ok, err = pcall(function()
        return g.item:ClearEnchantment(g.slot)
    end)
    if ok then
        if g.entry then player:AddItem(g.entry, 1) end
        player:SendBroadcastMessage("|cff00ff00[宝石]|r 已取下并返还宝石")
    else
        player:SendBroadcastMessage("|cffff0000[宝石]|r 取下失败: " .. tostring(err))
    end
end

local function OnGemSelect(event, player, item, sender, action, code)
    if not item then return end
    if sender == 0 then
        if action >= 100 and action <= 119 then
            local empty = ScanEquip(player)
            local e = empty[action - 100]
            if e then DoSocket(player, item, e) end
            player:GossipComplete()
        elseif action == 90 then
            ShowRemoveMenu(player, item)
        else
            player:GossipComplete()
        end
    elseif sender == 1 then
        if action == 0 then
            OnGemUse(nil, player, item)
        elseif action >= 200 then
            DoRemove(player, action - 200)
            player:GossipComplete()
        else
            player:GossipComplete()
        end
    end
end

for entry in pairs(GEMS) do
    for lv = 0, 4 do
        RegisterItemEvent(entry + lv, 2, OnGemUse)
        RegisterItemGossipEvent(entry + lv, 2, OnGemSelect)
    end
end

print("[ARPG] gem.lua v3 loaded — 宝石镶嵌(含打孔双槽)已启用 (901001-901020)")
