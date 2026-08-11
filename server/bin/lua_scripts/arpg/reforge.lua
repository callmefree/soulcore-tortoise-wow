-- reforge.lua — 1-7 套装重铸（混沌重铸石 904003）
-- 阶段1 A级第7项 ｜ 依据：ARPG系统移植计划书.md 1-7 / 素材01 系统14
-- 机制：右键重铸石 → 列背包中带 set_id 的套装部件 → 选中 →
--       查同 set_id 其他部件（优先同部位）→ 随机转换（5% 失败，物品湮灭）
-- ⚠️ itemset 表为空（Turtle 1.12 无数据，踩坑#10），改用 item_template.set_id
--     同套互查（2070 件带 set_id，探针已验证，见工作记录 1-7）。
-- ⚠️ item use 返回 false 才阻止施法；item gossip 用 GossipSendMenu(1, item)
-- ⚠️ 遍历查询用 GetRow 取行 + NextRow 推进（踩坑#12），全部 DB 查询 pcall（踩坑#6）

local REFORGE = 904003       -- 混沌重铸石
local FAIL_RATE = 5          -- 5% 失败概率
local MAX_LIST = 30          -- gossip 菜单最多列 30 件（超限分批）

-- ⚠️ 随机播种（审计 2026-08-11）：Lua 5.2 math.random 未播种时序列固定（5% 失败/随机目标重启间不变）。
--    幂等：共享 _G._ARPG_SEEDED，只播一次
if not _G._ARPG_SEEDED then
    math.randomseed(os.time())
    _G._ARPG_SEEDED = true
end

-- 扫描背包（主背包 255 + 包袋 19-22，slot 0-15），返回 entry 列表（去重，背包序）与 entry→Item 映射
-- ⚠️ 引擎 GetItemByPos 只认 bag=255（INVENTORY_SLOT_BAG_0, Player.h:583）或 19-22（包袋位，
--    Player.h:612-613）；bag=0-4 恒返回 nil（踩坑：审计 2026-08-11 实锤 Player.cpp:10513-10527）
local BAGS = {255, 19, 20, 21, 22}
local function ScanBag(player)
    local entries, itemMap = {}, {}
    for _, bag in ipairs(BAGS) do
        for slot = 0, 15 do
            local ok, item = pcall(function()
                return player:GetItemByPos(bag, slot)
            end)
            if ok and item then
                local e = item:GetEntry()
                if e and not itemMap[e] then
                    itemMap[e] = item
                    entries[#entries + 1] = e
                end
            end
        end
    end
    return entries, itemMap
end

-- 一次查询所有背包物品的 set_id（IN 列表）
local function QuerySetIds(entries)
    if #entries == 0 then return {} end
    local list = table.concat(entries, ",")
    local ok, q = pcall(function()
        return WorldDBQuery("SELECT entry, set_id, name FROM item_template WHERE entry IN (" .. list .. ") AND set_id > 0")
    end)
    local sets = {}
    if ok and q then
        local r = q:GetRow()
        while r do
            sets[tonumber(r[1])] = { set = tonumber(r[2]), name = r[3] or "?" }
            if not q:NextRow() then break end
            r = q:GetRow()
        end
    end
    return sets
end

-- 取同套其他部件：优先同部位，返回 {entry=, name=} 或 nil
local function FindSameSetTarget(setId, curEntry, curType)
    local ok, q = pcall(function()
        return WorldDBQuery("SELECT entry, name, inventory_type FROM item_template WHERE set_id=" .. setId .. " AND entry<>" .. curEntry)
    end)
    if not (ok and q) then return nil end
    local sameType, others = {}, {}
    local r = q:GetRow()
    while r do
        local t = { entry = tonumber(r[1]), name = r[2] or "?", type = tonumber(r[3]) or 0 }
        if t.type == curType then sameType[#sameType + 1] = t else others[#others + 1] = t end
        if not q:NextRow() then break end
        r = q:GetRow()
    end
    local pool = (#sameType > 0) and sameType or others
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function OnReforgeUse(event, player, item)
    local entries, _ = ScanBag(player)
    local sets = QuerySetIds(entries)

    player:GossipClearMenu()
    local listed = 0
    -- 按背包扫描序枚举（稳定顺序，与选中回调一致），过滤出套装物品
    for _, e in ipairs(entries) do
        local info = sets[e]
        if info then
            if listed >= MAX_LIST then
                player:GossipMenuAddItem(0, "|cffff0000（还有更多，请分批重铸）", 0, 99)
                break
            end
            listed = listed + 1
            player:GossipMenuAddItem(0, "重铸 " .. (info.name or ("物品 " .. e)) .. "（套装 " .. info.set .. "）", 0, 100 + listed)
        end
    end
    if listed == 0 then
        player:GossipMenuAddItem(0, "|cffff0000背包里没有套装部件（带 set_id 的物品）", 0, 99)
    end
    player:GossipMenuAddItem(0, "关闭", 0, 99)
    player:GossipSendMenu(1, item)
    return false
end

local function DoReforge(player, item, entry, info)
    local curType = 0
    local okT, qT = pcall(function()
        return WorldDBQuery("SELECT inventory_type FROM item_template WHERE entry=" .. entry)
    end)
    if okT and qT then
        local r = qT:GetRow()
        curType = r and tonumber(r[1]) or 0
    end
    local target = FindSameSetTarget(info.set, entry, curType)
    if not target then
        player:SendBroadcastMessage("|cffff0000[重铸]|r 该套装只有这一件部件，无可转换目标")
        player:GossipComplete()
        return
    end

    player:RemoveItem(REFORGE, 1)          -- 重铸石消耗（无论成败）
    if math.random(100) <= FAIL_RATE then
        player:RemoveItem(entry, 1)
        player:SendBroadcastMessage("|cffff0000[重铸]|r 重铸失败！" .. (info.name or "?") .. " 已湮灭（" .. FAIL_RATE .. "% 失败率）")
        player:GossipComplete()
        return
    end

    player:RemoveItem(entry, 1)
    -- ⚠️ PlayerAddItem 返回布尔（TurtleLuaEngine.cpp:5284）：pcall 第一个返回是 pcall 状态（恒 true），
    --    第二个才是 AddItem 结果。满包时 AddItem 返回 false（Player.cpp:23943 返回 nullptr）→ 需返还原物品
    local ok, added = pcall(function()
        return player:AddItem(target.entry, 1)
    end)
    if ok and added then
        player:SendBroadcastMessage("|cff00ff00[重铸]|r " .. (info.name or "?") .. " → |cff66ccff" .. (target.name or ("物品 " .. target.entry)) .. "|r（同套装转换）")
    else
        player:AddItem(entry, 1)            -- 兜底：失败返还原物品
        player:SendBroadcastMessage("|cffff0000[重铸]|r 转换失败（背包已满或无空间），已返还原物品")
    end
    player:GossipComplete()
end

local function OnReforgeSelect(event, player, item, sender, action, code)
    if not item then return end
    if action < 100 then
        player:GossipComplete()
        return
    end
    local entries, _ = ScanBag(player)
    local sets = QuerySetIds(entries)
    -- 与 OnReforgeUse 相同的背包扫描序，定位第 (action-100) 个套装物品
    local listed = 0
    for _, e in ipairs(entries) do
        local info = sets[e]
        if info then
            listed = listed + 1
            if listed == action - 100 then
                DoReforge(player, item, e, info)
                return
            end
        end
    end
    player:GossipComplete()
end

RegisterItemEvent(REFORGE, 2, OnReforgeUse)
RegisterItemGossipEvent(REFORGE, 2, OnReforgeSelect)

print("[ARPG] reforge.lua loaded — 套装重铸已启用 (904003)")
