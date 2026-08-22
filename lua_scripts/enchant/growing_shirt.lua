-- ============================================================================
-- growing_shirt.lua
-- 功能：玩家【打开新手礼包】后会获得成长新手衬衣；之后每次升级自动换为
--       当前等级对应档位（清旧档、发新档、自动穿衬衫槽）。
--       衬衣外观统一 (display_id=9891)，属性随等级增长（每级 +1，五维同步，
--       1级各10 → 60级各69），属性写在 item_template 固有字段，server 端必定生效。
-- 适配：Turtle-WoW 1.18.1 build 7272 + TurtleLuaEngine（feature/playerbots 分支）
-- 数据：item_template 预建 60 件（entry 900101..900160），见配套 SQL growing_shirt_items.sql
--       ITEM_MOD 枚举见 ItemPrototype.h: STR=4 AGI=3 STA=7 INT=5 SPI=6（Turtle 非标准值！）
-- 事件：PLAYER_EVENT_ON_LEVEL_CHANGE = 13
-- 改动说明（2026-08-16）：原【首登自动发衬衣】已移除——衬衣改由 starter_gift_bag.lua
--       在玩家【打开新手礼包】时发放（OnItemUse）。本脚本仅负责开包后的升级换档，
--       且 OnLevelChange 增加守卫：玩家未拥有任何成长衬衣前不自动发（避免绕过礼包）。
-- 部署：本 lua 放入服务器 lua_scripts/，重启 mangosd 或 .reload eluna 生效。
-- ============================================================================

-- ===================== 顶部集中配置区（只改这里） =====================
local CFG = {
    SHIRT_BASE_ENTRY = 900100,      -- 1级衬衣 entry = SHIRT_BASE_ENTRY + 1 = 900101
    MAX_LEVEL        = 60,          -- 封顶等级（须与配套 SQL 生成档数一致）
    BODY_SLOT        = 3,           -- EQUIPMENT_SLOT_BODY（衬衫槽），Player.h:591
    AUTO_EQUIP       = true,        -- 换档后是否自动穿到衬衫槽
    PER_LEVEL        = 1,           -- 每升 1 级每种属性增长值
    BASE_STAT        = 10,          -- 1 级每种属性基数
    MSG_UPGRADE      = "你的成长衬衣已成长到 %d 级（力量/敏捷/耐力/智力/精神 各 %d）！",
    DEBUG            = false,
}
-- ============================================================================

local function ShirtEntryForLevel(level)
    local L = level
    if L > CFG.MAX_LEVEL then L = CFG.MAX_LEVEL end
    if L < 1 then L = 1 end
    return CFG.SHIRT_BASE_ENTRY + L
end

-- 判断是否为成长衬衣 entry
local function IsGrowthShirt(entry)
    return entry and entry >= CFG.SHIRT_BASE_ENTRY
       and entry <= CFG.SHIRT_BASE_ENTRY + CFG.MAX_LEVEL
end

-- 玩家是否已拥有任意成长衬衣（装备中或背包中）
local function HasAnyGrowthShirt(player)
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        if IsGrowthShirt(e) then return true end
    end
    for lvl = 1, CFG.MAX_LEVEL do
        local e = CFG.SHIRT_BASE_ENTRY + lvl
        local ok2, it = pcall(player.GetItemByEntry, player, e)
        if ok2 and it then return true end
    end
    return false
end

-- 移除玩家所有「非 keepEntry」的成长衬衣（装备中 + 背包中）
local function RemoveStaleShirts(player, keepEntry)
    -- 装备中的旧衬衣
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        if IsGrowthShirt(e) and e ~= keepEntry then
            pcall(player.RemoveItem, player, body, 1)
        end
    end
    -- 背包中所有旧档（逐档清除，加迭代上限防极端死循环）
    for lvl = 1, CFG.MAX_LEVEL do
        local e = CFG.SHIRT_BASE_ENTRY + lvl
        if e ~= keepEntry then
            local tries = 0
            while tries < 20 do
                tries = tries + 1
                local ok2, it = pcall(player.GetItemByEntry, player, e)
                if ok2 and it then
                    pcall(player.RemoveItem, player, it, 1)
                else
                    break
                end
            end
        end
    end
end

local function StatValueForLevel(level)
    local L = level
    if L > CFG.MAX_LEVEL then L = CFG.MAX_LEVEL end
    return CFG.BASE_STAT + (L - 1) * CFG.PER_LEVEL
end

local function ApplyGrowthShirt(player)
    if not player then return end
    local L = player:GetLevel()
    local target = ShirtEntryForLevel(L)

    -- 已装备当前档则跳过（避免重复发）
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        if e == target then
            if CFG.DEBUG then print("[growing_shirt] 已装备当前档衬衣 " .. target) end
            return
        end
    end

    RemoveStaleShirts(player, target)

    local okAdd = pcall(player.AddItem, player, target, 1)
    if not okAdd then
        player:SendBroadcastMessage("|cffFF0000[成长衬衣] 发放失败，请联系 GM。|r")
        return
    end

    if CFG.AUTO_EQUIP then
        local ok3, it = pcall(player.GetItemByEntry, player, target)
        if ok3 and it then
            pcall(player.EquipItem, player, it)
        end
    end

    local v = StatValueForLevel(L)
    player:SendBroadcastMessage(string.format(CFG.MSG_UPGRADE, math.min(L, CFG.MAX_LEVEL), v))
end

-- 与 starter_gift_bag.lua 一致的 bot 过滤
local function IsRealPlayer(player)
    local ok, name = pcall(player.GetAccountName, player)
    if ok and name and (name:match("^rndbot") or name:match("^bot") or name:match("^playerbot")
                      or name:match("^altbot") or name:match("^roster")) then
        return false
    end
    local ok2, ip = pcall(player.GetPlayerIP, player)
    if ok2 and (ip == "" or ip == nil) then
        return false
    end
    return true
end

-- 升级换档：仅当玩家已拥有成长衬衣（开过礼包）时才换档，避免绕过礼包自动发
local function OnLevelChange(event, player, oldLevel)
    if not player then return end
    if not IsRealPlayer(player) then return end
    if not HasAnyGrowthShirt(player) then return end
    ApplyGrowthShirt(player)
end

-- 注：原 PLAYER_EVENT_ON_FIRST_LOGIN(30) 自动发衬衣已移除，改由 starter_gift_bag.lua
--     在玩家【打开新手礼包】时发放。本脚本只负责开包后的升级换档。
RegisterPlayerEvent(13, OnLevelChange)  -- PLAYER_EVENT_ON_LEVEL_CHANGE

if CFG.DEBUG then
    print("[growing_shirt] 已加载：成长新手衬衣升级换档（开包后生效，1级各" .. CFG.BASE_STAT
        .. " → " .. CFG.MAX_LEVEL .. "级各" .. StatValueForLevel(CFG.MAX_LEVEL) .. "）")
end
