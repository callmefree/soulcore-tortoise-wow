-- combine.lua — 1-6 宝石合成链（书页→书→兑换宝石）
-- 阶段1 A级第6项 ｜ 依据：ARPG系统移植计划书.md 1-6 / 素材01 系统5
-- 一期：905002 书页 3 合 1 → 905003 书；905003 书 → 随机 1 级四色宝石
-- ⚠️ item use 返回 false 才阻止施法（本引擎语义）

local PAGE = 905002   -- 宝石书页
local BOOK = 905003   -- 宝石书
local LV1_GEMS = { 901001, 901006, 901011, 901016 }  -- 1 级四色宝石

-- 书页 3 合 1 → 书
local function OnPageUse(event, player, item)
    if not player or not item then return true end
    local count = player:GetItemCount(PAGE)
    if count < 3 then
        player:SendBroadcastMessage("|cffff0000[合成]|r 需要 3 张宝石书页（当前 " .. count .. " 张）")
        return false
    end
    player:RemoveItem(PAGE, 3)
    player:AddItem(BOOK, 1)
    player:SendBroadcastMessage("|cff00ff00[合成]|r 3 张书页 → 1 本宝石书")
    return false
end

-- 书 → 随机 1 级宝石
local function OnBookUse(event, player, item)
    if not player or not item then return true end
    local gem = LV1_GEMS[math.random(#LV1_GEMS)]
    player:RemoveItem(BOOK, 1)
    player:AddItem(gem, 1)
    player:SendBroadcastMessage("|cff00ff00[合成]|r 宝石书开启，获得 1 颗随机 1 级四色宝石")
    return false
end

RegisterItemEvent(PAGE, 2, OnPageUse)
RegisterItemEvent(BOOK, 2, OnBookUse)

print("[ARPG] combine.lua loaded — 宝石合成链已启用 (905002/905003)")
