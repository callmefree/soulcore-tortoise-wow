-- rune.lua v2 — 1-4 1~33 号符文（镶嵌 + 取下）
-- 阶段1 A级第4项 ｜ 依据：ARPG系统移植计划书.md 1-4 / 素材01 系统1
-- v2 改进（用户反馈）：补"取下符文"功能（清除槽4 附魔，返还符文）
-- 机制：每装备 1 符文位（槽4，PROP_ENCHANTMENT_SLOT_1，与宝石槽3/槽5 共存）

local RUNE_SLOT = 4
local RUNES = {
    68, 69, 70, 106, 107, 74, 75, 76, 90, 91, 79, 80, 81, 94, 95,
    71, 72, 73, 102, 103, 82, 83, 84, 98, 99, 110, 114, 116,
    195, 196, 197, 203, 205,
}
-- RUNES[1]=900001 El ... RUNES[33]=900033 Zod
-- ⚠️ 词缀冲突修复（审计 2026-08-11）：SetItemRandomProperties 会把随机词缀写进槽3/4/5
--    （Item.cpp:787-788），槽4 的 enchant id 可能是词缀而非符文。只有 eid 落在符文池
--    （RUNES 值域）才算"已镶符文"，否则视为词缀占位——不列取下、不当空槽目标、不清除。
local ENCH2ENTRY = {}
for i, e in ipairs(RUNES) do
    ENCH2ENTRY[e] = 900000 + i
end

local function OnRuneUse(event, player, item)
    local entry = item:GetEntry()
    local idx = entry - 900000
    if idx < 1 or idx > 33 then return true end

    -- 收集：空槽装备（取第一件做镶嵌目标）+ 带符文装备（全部列出）
    local target, gemmed = nil, {}
    for slot = 0, 18 do
        local eq = player:GetEquippedItemBySlot(slot)
        if eq then
            local eid = eq:GetEnchantmentId(RUNE_SLOT)
            if eid and ENCH2ENTRY[eid] then
                gemmed[#gemmed + 1] = eq
            elseif not (eid and eid > 0) then
                if not target then target = eq end
            end
            -- eid>0 但非符文（随机词缀占槽4）→ 跳过：既不列取下，也不当镶嵌目标
        end
    end

    player:GossipClearMenu()
    if target then
        player:GossipMenuAddItem(0, "镶嵌符文到 " .. (target:GetName() or "?"), 0, 1)
    else
        player:GossipMenuAddItem(0, "|cffff0000没有空符文槽的装备", 0, 99)
    end
    -- 直接列出带符文的部位
    for i, eq in ipairs(gemmed) do
        player:GossipMenuAddItem(0, "|cff66ccff取下 " .. (eq:GetName() or "?") .. " 的符文（返还）", 0, 200 + i)
    end
    player:GossipMenuAddItem(0, "关闭", 0, 99)
    player:GossipSendMenu(1, item)
    return false
end

-- 取下指定第 idx 件有符文的装备
local function DoRuneRemove(player, idx)
    local listed = 0
    for slot = 0, 18 do
        local eq = player:GetEquippedItemBySlot(slot)
        if eq then
            local eid = eq:GetEnchantmentId(RUNE_SLOT)
            if eid and ENCH2ENTRY[eid] then
                listed = listed + 1
                if listed == idx then
                    local back = ENCH2ENTRY[eid]
                    local ok, err = pcall(function()
                        return eq:ClearEnchantment(RUNE_SLOT)
                    end)
                    if ok then
                        -- ⚠️ AddItem 返回布尔（L5284），满包 false → 附魔已清但符文没返还，须提示
                        local ok2, added = pcall(function()
                            return player:AddItem(back, 1)
                        end)
                        if ok2 and added then
                            player:SendBroadcastMessage("|cff00ff00[符文]|r 已取下 " .. (eq:GetName() or "?") .. " 的符文并返还")
                        else
                            player:SendBroadcastMessage("|cffff0000[符文]|r 已取下但背包已满，符文未能返还！")
                        end
                    else
                        player:SendBroadcastMessage("|cffff0000[符文]|r 取下失败: " .. tostring(err))
                    end
                    return
                end
            end
        end
    end
    player:SendBroadcastMessage("|cffff0000[符文]|r 没有已镶嵌的符文")
end

local function OnRuneSelect(event, player, item, sender, action, code)
    if not item then return end
    local entry = item:GetEntry()
    local idx = entry - 900000
    if idx < 1 or idx > 33 then player:GossipComplete() return end

    if sender == 0 then
        if action == 1 then
            -- 镶嵌：找第一件空符文槽装备（词缀占槽4 的装备不当目标）
            local target = nil
            for slot = 0, 18 do
                local eq = player:GetEquippedItemBySlot(slot)
                if eq then
                    local eid = eq:GetEnchantmentId(RUNE_SLOT)
                    if not (eid and eid > 0) then
                        target = eq
                        break
                    end
                end
            end
            if not target then
                player:SendBroadcastMessage("|cffff0000[符文]|r 没有空符文槽的装备")
                player:GossipComplete()
                return
            end
            local ok, err = pcall(function()
                return target:SetEnchantment(RUNES[idx], RUNE_SLOT)
            end)
            if ok then
                player:RemoveItem(entry, 1)
                player:SendBroadcastMessage("|cff00ff00[符文]|r 已镶嵌到 " .. (target:GetName() or "?") .. "（与宝石槽共存）")
            else
                player:SendBroadcastMessage("|cffff0000[符文]|r 镶嵌失败: " .. tostring(err))
            end
            player:GossipComplete()
        elseif action >= 200 then
            -- 直接取下第 (action-200) 个带符文装备（只认符文池，跳过词缀占位）
            local listed = 0
            for slot = 0, 18 do
                local eq = player:GetEquippedItemBySlot(slot)
                if eq then
                    local eid = eq:GetEnchantmentId(RUNE_SLOT)
                    if eid and ENCH2ENTRY[eid] then
                        listed = listed + 1
                        if listed == action - 200 then
                            local back = ENCH2ENTRY[eid]
                            local ok, err = pcall(function()
                                return eq:ClearEnchantment(RUNE_SLOT)
                            end)
                            if ok then
                                -- ⚠️ AddItem 返回布尔（L5284），满包 false → 附魔已清但符文没返还，须提示
                                local ok2, added = pcall(function()
                                    return player:AddItem(back, 1)
                                end)
                                if ok2 and added then
                                    player:SendBroadcastMessage("|cff00ff00[符文]|r 已取下 " .. (eq:GetName() or "?") .. " 的符文并返还")
                                else
                                    player:SendBroadcastMessage("|cffff0000[符文]|r 已取下但背包已满，符文未能返还！")
                                end
                            else
                                player:SendBroadcastMessage("|cffff0000[符文]|r 取下失败: " .. tostring(err))
                            end
                            break
                        end
                    end
                end
            end
            player:GossipComplete()
        else
            player:GossipComplete()
        end
    elseif sender == 1 then
        if action == 0 then
            OnRuneUse(nil, player, item)   -- 返回主菜单
        elseif action >= 200 then
            DoRuneRemove(player, action - 200)
            player:GossipComplete()
        else
            player:GossipComplete()
        end
    end
end

for i = 1, 33 do
    RegisterItemEvent(900000 + i, 2, OnRuneUse)
    RegisterItemGossipEvent(900000 + i, 2, OnRuneSelect)
end

print("[ARPG] rune.lua v2 loaded — 符文系统(含取下)已启用 (900001-900033)")
