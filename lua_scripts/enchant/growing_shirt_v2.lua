-- ============================================================================
-- growing_shirt_v2.lua  (rev.3 —— 删除 DK 幽灵分支，仅保留 9 个真实职业)
--
-- 成长衬衣 v2 —— 按职业分配相关属性 + 里程碑式成长 + 外观进化
-- 适配：Turtle-WoW 1.18.1（TurtleLuaEngine，feature/playerbots 分支）
--
-- ⚠️ 职业枚举必须用真实值！（rev.3 删除 DK 分支）
--    PB 服务器为 Turtle 1.18 系（vanilla 职业集），经 characters 库实查确认无死亡骑士：
--    真实枚举：1=战士 2=圣骑 3=猎人 4=盗贼 5=牧师 [6空缺] 7=萨满 8=法师 9=术士 11=德鲁伊
--    （注意：6 空缺、DRUID=11 而非 9）。旧版按 1..9 连续编码 → 德鲁伊被 cls>9 守卫拒发、
--    萨满/法师/术士属性错位。现改用「真实职业 -> 连续序号 idx(1..9)」编码 entry。
--
-- 数据：item_template 由 gen_growth_shirt.py 生成（entry 910101..910907）
--       entry = 910000 + idx*100 + 档位(1..7)，idx 见 CFG.CLASS_BY_IDX
-- 事件：ON_LOGIN=3 / ON_FIRST_LOGIN=30（发放+恢复）  ON_LEVEL_CHANGE=13（跨档换装）
--       三者均收敛到 ApplyGrowthShirt（幂等：已装备/已有则跳过，不重复发）
-- 部署：放入服务器 lua_scripts/，重启 mangosd 或 .reload eluna 生效。
--       item_template 改动后须 restart pbmangosd（缓存不热更）。
-- ============================================================================

-- ===================== 顶部集中配置区（只改这里） =====================
local CFG = {
    ENTRY_BASE       = 910000,  -- entry = BASE + idx*100 + 档位(1..7)
    MAX_LEVEL        = 60,
    BODY_SLOT        = 3,       -- EQUIPMENT_SLOT_BODY（衬衫槽）
    AUTO_EQUIP       = true,
    XP_BONUS_PER_TIER = 0,      -- 跨档经验奖励（0=关闭）。⚠️ 开启前须确认服务端
                                --   GiveXP 在事件中调用不会重入触发升级，否则死循环。
    DEBUG            = false,
    -- 各档起始等级（与 SQL 生成器 TIERS 一致，顺序即档位 1..7）
    TIER_STARTS      = {1, 10, 20, 30, 40, 50, 60},
    -- 真实职业枚举 -> 连续序号 idx（决定 entry 编码，避开 6 空缺与 DRUID=11 跳段）
    -- 顺序即 idx：1战士 2圣骑 3猎人 4贼 5牧 [6空缺] 7萨满 8法师 9术士 11德鲁伊(idx9)
    CLASS_BY_IDX     = {1, 2, 3, 4, 5, 7, 8, 9, 11},
    MSG_UPGRADE      = "你的成长衬衣进化为|cff00ff00%s|r（第 %d 阶）！",
    MSG_FAIL         = "|cffFF0000[成长衬衣] 发放失败，请重新登录或联系 GM。|r",
}
-- ============================================================================

local MAX_TIER = #CFG.TIER_STARTS  -- 7
local MAX_IDX  = #CFG.CLASS_BY_IDX -- 10

-- 反查表：真实职业 -> idx
local CLASS_TO_IDX = {}
for idx, cls in ipairs(CFG.CLASS_BY_IDX) do
    CLASS_TO_IDX[cls] = idx
end

-- 等级 -> 档位(1..7)
local function TierForLevel(level)
    local L = level
    if L > CFG.MAX_LEVEL then L = CFG.MAX_LEVEL end
    if L < 1 then L = 1 end
    local t = 1
    for i = 1, MAX_TIER do
        if L >= CFG.TIER_STARTS[i] then t = i end
    end
    return t
end

-- 真实职业 + 档位 -> entry
local function ShirtEntry(cls, tier)
    local idx = CLASS_TO_IDX[cls]
    if not idx then return nil end
    return CFG.ENTRY_BASE + idx * 100 + tier
end

-- 是否成长衬衣 entry（范围 910101..911007）
local function IsGrowthShirt(entry)
    if not entry then return false end
    local base = CFG.ENTRY_BASE
    if entry < base + 1 then return false end
    if entry > base + MAX_IDX * 100 + MAX_TIER then return false end
    -- 校验落在某 (idx,tier) 格内
    local rel = entry - base
    local idx = math.floor(rel / 100)
    local tier = rel % 100
    return idx >= 1 and idx <= MAX_IDX and tier >= 1 and tier <= MAX_TIER
end

-- 玩家是否「已装备」目标衬衣
local function IsEquipped(player, entry)
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        return (e == entry)
    end
    return false
end

-- 移除玩家所有成长衬衣中 != keepEntry 的（装备中 + 背包中）
local function RemoveStaleShirts(player, keepEntry)
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        if IsGrowthShirt(e) and e ~= keepEntry then
            pcall(player.RemoveItem, player, body, 1)
        end
    end
    for idx = 1, MAX_IDX do
        for t = 1, MAX_TIER do
            local e = CFG.ENTRY_BASE + idx * 100 + t
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
end

local function TierName(tier)
    return string.char(string.byte("I") + tier - 1)  -- I..VII
end

-- 核心（幂等）：发放/升级当前档衬衣
local function ApplyGrowthShirt(player)
    if not player then return end
    local cls = player:GetClass()
    local idx = CLASS_TO_IDX[cls]
    if not idx then
        if CFG.DEBUG then print("[growing_shirt_v2] 未知职业 " .. tostring(cls) .. "，跳过") end
        return
    end
    local tier = TierForLevel(player:GetLevel())
    local target = CFG.ENTRY_BASE + idx * 100 + tier

    -- 已装备当前档 → 直接跳过（幂等，避免重复发）
    if IsEquipped(player, target) then
        if CFG.DEBUG then print("[growing_shirt_v2] 已装备当前档 " .. target) end
        return
    end

    -- 背包已有当前档 → 仅装备，不再 AddItem（防重复堆叠）
    local okHave, have = pcall(player.GetItemByEntry, player, target)
    local needAdd = not (okHave and have)

    RemoveStaleShirts(player, target)

    if needAdd then
        local okAdd = pcall(player.AddItem, player, target, 1)
        if not okAdd then
            player:SendBroadcastMessage(CFG.MSG_FAIL)
            return
        end
    end

    -- 自动装备：显式传 SLOT=3（衬衫槽），Eluna 标准 Player:EquipItem(item, slot)
    if CFG.AUTO_EQUIP then
        local ok3, it = pcall(player.GetItemByEntry, player, target)
        if ok3 and it then
            pcall(function() player:EquipItem(it, CFG.BODY_SLOT) end)
        end
    end

    if CFG.XP_BONUS_PER_TIER and CFG.XP_BONUS_PER_TIER > 0 then
        local ok4 = pcall(player.GiveXP, player, CFG.XP_BONUS_PER_TIER)
        if not ok4 and CFG.DEBUG then print("[growing_shirt_v2] GiveXP 失败") end
    end

    player:SendBroadcastMessage(string.format(CFG.MSG_UPGRADE, "成长衬衣·" .. TierName(tier), tier))
end

-- bot 过滤（playerbots 不穿衬衣）：账号名匹配常见 bot 前缀，或 IP 为空
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

-- 发放/恢复路径：每次登录 + 首登 + 升级，全部收敛到幂等的 ApplyGrowthShirt
local function OnLogin(event, player)        -- event 3
    if not player or not IsRealPlayer(player) then return end
    ApplyGrowthShirt(player)
end

local function OnFirstLogin(event, player)   -- event 30
    if not player or not IsRealPlayer(player) then return end
    ApplyGrowthShirt(player)
end

local function OnLevelChange(event, player, oldLevel)  -- event 13
    if not player or not IsRealPlayer(player) then return end
    ApplyGrowthShirt(player)  -- 无需 HasAny 守卫：丢失后升级一级即自动补发
end

RegisterPlayerEvent(3,  OnLogin)             -- PLAYER_EVENT_ON_LOGIN
RegisterPlayerEvent(30, OnFirstLogin)        -- PLAYER_EVENT_ON_FIRST_LOGIN
RegisterPlayerEvent(13, OnLevelChange)       -- PLAYER_EVENT_ON_LEVEL_CHANGE

if CFG.DEBUG then
    print("[growing_shirt_v2] 已加载：成长衬衣 v2 rev.2（职业真实枚举 + 7 档里程碑，entry "
        .. (CFG.ENTRY_BASE + 1) .. ".." .. (CFG.ENTRY_BASE + MAX_IDX * 100 + MAX_TIER) .. "）")
end
