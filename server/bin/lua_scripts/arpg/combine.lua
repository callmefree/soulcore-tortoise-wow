-- combine.lua — 1-6 宝石合成链（书页→书→兑换宝石）
-- 阶段1 A级第6项 ｜ 依据：ARPG系统移植计划书.md 1-6 / 素材01 系统5
-- 一期：905002 书页 3 合 1 → 905003 书；905003 书 → 随机 1 级四色宝石
-- ⚠️ item use 返回 false 才阻止施法（本引擎语义）

local PAGE = 905002   -- 宝石书页
local BOOK = 905003   -- 宝石书
local LV1_GEMS = { 901001, 901006, 901011, 901016 }  -- 1 级四色宝石

-- ⚠️ 随机播种（审计 2026-08-11）：随机宝石需真随机。幂等：共享 _G._ARPG_SEEDED
if not _G._ARPG_SEEDED then
    math.randomseed(os.time())
    _G._ARPG_SEEDED = true
end

-- 书页 3 合 1 → 书
local function OnPageUse(event, player, item)
    if not player or not item then return true end
    local count = player:GetItemCount(PAGE)
    if count < 3 then
        player:SendBroadcastMessage("|cffff0000[合成]|r 需要 3 张宝石书页（当前 " .. count .. " 张）")
        return false
    end
    player:RemoveItem(PAGE, 3)
    -- ⚠️ AddItem 返回布尔（L5284），满包 false → 书页已扣但书没给，须返还
    local ok, added = pcall(function()
        return player:AddItem(BOOK, 1)
    end)
    if ok and added then
        player:SendBroadcastMessage("|cff00ff00[合成]|r 3 张书页 → 1 本宝石书")
    else
        player:AddItem(PAGE, 3)
        player:SendBroadcastMessage("|cffff0000[合成]|r 合成失败（背包已满），书页已返还")
    end
    return false
end

-- 书 → 随机 1 级宝石
local function OnBookUse(event, player, item)
    if not player or not item then return true end
    local gem = LV1_GEMS[math.random(#LV1_GEMS)]
    player:RemoveItem(BOOK, 1)
    -- ⚠️ AddItem 返回布尔（L5284），满包 false → 书已扣但宝石没给，须返还
    local ok, added = pcall(function()
        return player:AddItem(gem, 1)
    end)
    if ok and added then
        player:SendBroadcastMessage("|cff00ff00[合成]|r 宝石书开启，获得 1 颗随机 1 级四色宝石")
    else
        player:AddItem(BOOK, 1)
        player:SendBroadcastMessage("|cffff0000[合成]|r 开启失败（背包已满），宝石书已返还")
    end
    return false
end

RegisterItemEvent(PAGE, 2, OnPageUse)
RegisterItemEvent(BOOK, 2, OnBookUse)

print("[ARPG] combine.lua loaded — 宝石合成链已启用 (905002/905003)")
