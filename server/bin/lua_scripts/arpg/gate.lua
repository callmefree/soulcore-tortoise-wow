-- gate.lua v1 — 1-9 符文门控（持有对应符文才能激活高级物品）
-- 阶段1 A级第9项 ｜ 依据：ARPG系统移植计划书.md 1-9（用户 2026-08-10 决策：
--       Turtle 1.12 无传家宝体系，原"传家宝激活"改为"符文门控系统"）
-- 配置：tw_char.soulcore_arpg_gate (item_entry, rune_entry, reward_item, descr)
-- 机制：启动读表缓存；item use 时检查持有符文（不消耗）：
--       无符文 → 拒绝提示（return false 阻止施法）
--       持符文 → 消耗被门控物品 + 发奖励（reward_item=0 时随机 1 级宝石）
-- ⚠️ item use 返回 false 才阻止施法；所有 DB 查询 pcall 包裹（踩坑#6）

local GATE = {}
local NAME_CACHE = {}         -- entry → 物品名（符文/奖励）
local GEM_LV1 = {901001, 901006, 901011, 901016}  -- 四色 1 级宝石

-- 缓存物品名（pcall：查询失败返回 0 时用兜底名）
local function CacheName(entry)
    if NAME_CACHE[entry] then return end
    local ok, q = pcall(function()
        return WorldDBQuery("SELECT name FROM item_template WHERE entry=" .. entry)
    end)
    if ok and q then
        local r = q:GetRow()
        NAME_CACHE[entry] = r and r[1] or ("物品 " .. entry)
    else
        NAME_CACHE[entry] = "物品 " .. entry
    end
end

local function LoadGate()
    local ok, q = pcall(function()
        return CharDBQuery("SELECT item_entry, rune_entry, reward_item, descr FROM soulcore_arpg_gate")
    end)
    if not (ok and q) then
        print("[ARPG] gate.lua: soulcore_arpg_gate 表不可用，门控未加载（先重放 016_phase1_gate.sql）")
        return
    end
    local n = 0
    repeat
        local r = q:GetRow()
        if not r then break end
        local itemEntry, runeEntry, reward = tonumber(r[1]), tonumber(r[2]), tonumber(r[3])
        GATE[itemEntry] = { rune = runeEntry, reward = reward, descr = r[4] or "" }
        CacheName(runeEntry)
        if reward and reward > 0 then CacheName(reward) end
        n = n + 1
    until false
    print("[ARPG] gate.lua v1 loaded — 符文门控 " .. n .. " 项已启用")
end

local function OnGateUse(event, player, item)
    local entry = item:GetEntry()
    local cfg = GATE[entry]
    if not cfg then return true end

    local runeName = NAME_CACHE[cfg.rune] or ("符文 " .. cfg.rune)
    if player:GetItemCount(cfg.rune) < 1 then
        player:SendBroadcastMessage("|cffff0000[门控]|r 激活需要持有符文：|cff00ccff" .. runeName .. "|r（" .. cfg.descr .. "）")
        return false
    end

    -- 激活成功：消耗门控物品 + 发奖励
    local reward = cfg.reward
    if reward == 0 then reward = GEM_LV1[math.random(#GEM_LV1)] end
    CacheName(reward)
    player:RemoveItem(entry, 1)
    local ok, err = pcall(function()
        return player:AddItem(reward, 1)
    end)
    if ok then
        player:SendBroadcastMessage("|cff00ff00[门控]|r 激活成功！获得 |cff66ccff" .. (NAME_CACHE[reward] or ("物品 " .. reward)) .. "|r")
    else
        player:SendBroadcastMessage("|cffff0000[门控]|r 激活失败: " .. tostring(err))
    end
    return false
end

LoadGate()
for itemEntry in pairs(GATE) do
    RegisterItemEvent(itemEntry, 2, OnGateUse)
end
