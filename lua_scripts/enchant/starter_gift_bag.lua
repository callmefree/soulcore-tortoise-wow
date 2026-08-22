-- ============================================================================
-- starter_gift_bag.lua
-- 功能：玩家角色【首次登录】时：
--   1) 自动加入指定工会（GUILD_NAME，若角色尚未在工会）
--   2) 背包获得【新手礼包】物品（entry = CFG.GIFT_BAG_ITEM）
--   玩家右键【打开新手礼包】时（ITEM_EVENT_ON_USE=2）发放礼包内容：
--     - 成长新手衬衣（按当前等级发对应档位，自动穿衬衫槽）
--     - 炉石等其他清单物品（易扩展，改 CFG.BAG_CONTENT 即可）
-- 适配：Turtle-WoW 1.18.1 build 7272 + TurtleLuaEngine（feature/playerbots 分支）
-- 事件：PLAYER_EVENT_ON_FIRST_LOGIN = 30；ITEM_EVENT_ON_USE = 2（按物品 entry 注册）
-- 关键 API 已核对源码（feature/playerbots TurtleLuaEngine）：
--   RegisterItemEvent(entry, event, func)  TurtleLuaEngine.h:408
--   ITEM_EVENT_ON_USE = 2                  TurtleLuaEngine.h:253
--   OnItemUse 为布尔事件，expectedValue=false => handler 返回 false 阻止使用（memory 铁律）
--   工会 API：GetGuildByName / Guild:AddMember / player:IsInGuild（同前版已审计）
-- 配套：growing_shirt.lua 已去掉首登自动发衬衣，仅负责开包后升级换档
-- 部署：复制本文件 + newbie_gift_bag_items.sql 到 PB 服；
--       SQL 在 tw_pb_world 执行建礼包物品，重启 mangosd 或 .reload eluna 生效
-- ============================================================================

-- ===================== 顶部集中配置区（只改这里） =====================
local CFG = {
    ---------------------------------------------------------------------------
    -- 自动入会设置（保持首登自动入会，不受礼包影响）
    ---------------------------------------------------------------------------
    AUTO_JOIN_GUILD = true,        -- 是否新角色自动入会
    GUILD_NAME      = "SoulCore",  -- 工会名（必须已在服务器存在）
    GUILD_RANK      = 4,           -- 加入等级：0=会长 1=官员 2=精英 3=会员 4=新人(最低)
    JOIN_MSG        = "欢迎加入公会 [%s]！",
    JOIN_FAIL_MSG   = "|cffFF0000[工会] 未找到工会 [%s]，请联系 GM 在配置填写正确工会名。|r",

    ---------------------------------------------------------------------------
    -- 新手礼包物品（必须与 newbie_gift_bag_items.sql 中创建的一致）
    ---------------------------------------------------------------------------
    GIFT_BAG_ITEM   = 900200,      -- 新手礼包 item_template entry

    ---------------------------------------------------------------------------
    -- 礼包内容清单：右键打开时发放。
    --   { kind = "growth_shirt" } => 按玩家【当前等级】发成长衬衣并自动穿衬衫槽
    --   { id = 物品ID, count = 数量 } => 普通物品
    -- 以后要加东西，只改这个表，无需动逻辑。
    ---------------------------------------------------------------------------
    BAG_CONTENT = {
        { kind = "growth_shirt" },                 -- 成长新手衬衣（按当前等级发档）
        { id = 6948, count = 1 },                 -- 炉石（角色创建已自带，重复发无害；不需要可删此行）
        -- 例：{ id = 118,  count = 5 },          -- 初级治疗药水
        -- 例：{ id = 1708, count = 5 },          -- 初级法力药水
    },

    ---------------------------------------------------------------------------
    -- 成长衬衣参数（须与 growing_shirt.lua 的 SHIRT_BASE_ENTRY / MAX_LEVEL 一致）
    ---------------------------------------------------------------------------
    SHIRT_BASE_ENTRY = 900100,      -- 1级衬衣 entry = SHIRT_BASE_ENTRY + 1 = 900101
    SHIRT_MAX_LEVEL  = 60,          -- 封顶等级（与 growing_shirt_items.sql 档数一致）
    BODY_SLOT        = 3,           -- EQUIPMENT_SLOT_BODY（衬衫槽），Player.h:591
    AUTO_EQUIP_SHIRT = true,        -- 打开礼包后是否自动把衬衣穿到衬衫槽

    ---------------------------------------------------------------------------
    -- 通用开关与提示
    ---------------------------------------------------------------------------
    SKIP_BOTS     = true,           -- 不给 Playerbot 机器人发礼包/入会
    WELCOME_MSG   = "欢迎来到 SoulCore！你的【新手礼包】已放入背包，右键打开获取新手物品。",
    OPEN_MSG      = "你打开了新手礼包，获得了里面的物品！",
    DEBUG         = false,
}
-- ============================================================================

-- 取目标工会名（支持联盟/部落分设，或同名单字符串）
local function GetTargetGuildName(player)
    local nm = CFG.GUILD_NAME
    if type(nm) == "table" then
        local ok, team = pcall(player.GetTeamId, player)
        team = (ok and team) or 0
        return nm[team] or nm[0]
    end
    return nm
end

-- 自动入会（IsInGuild 守卫 + 工会存在性校验 + pcall 包裹）
local function JoinStarterGuild(player)
    if not CFG.AUTO_JOIN_GUILD then return end

    local ok0, already = pcall(player.IsInGuild, player)
    if ok0 and already then return end

    local name = GetTargetGuildName(player)
    if not name or name == "" then
        if CFG.DEBUG then print("[starter_gift] GUILD_NAME 未配置，跳过入会") end
        return
    end

    local ok1, guild = pcall(GetGuildByName, name)
    if not ok1 or not guild then
        player:SendBroadcastMessage(string.format(CFG.JOIN_FAIL_MSG, name))
        if CFG.DEBUG then print("[starter_gift] 入会失败：未找到工会 " .. name) end
        return
    end

    local ok2 = pcall(guild.AddMember, guild, player, CFG.GUILD_RANK)
    if ok2 then
        player:SendBroadcastMessage(string.format(CFG.JOIN_MSG, name))
        if CFG.DEBUG then
            local _, pnm = pcall(player.GetName, player)
            print(string.format("[starter_gift] 玩家 %s 加入工会 %s", pnm or "?", name))
        end
    else
        player:SendBroadcastMessage(string.format(CFG.JOIN_FAIL_MSG, name))
        if CFG.DEBUG then print("[starter_gift] 入会调用异常：工会 " .. name) end
    end
end

-- 背包满溢安全发奖：发前发后差值检测，防止静默丢件
local function SafeGiveItem(player, itemId, amount)
    local ok1, pre = pcall(player.GetItemCount, player, itemId)
    if not ok1 then pre = 0 end

    local ok2 = pcall(player.AddItem, player, itemId, amount)
    if not ok2 then
        player:SendBroadcastMessage("|cffFF0000[礼包] 物品 " .. itemId .. " 发放失败（物品不存在或背包异常）。|r")
        return 0
    end

    local ok3, post = pcall(player.GetItemCount, player, itemId)
    if not ok3 then post = 0 end

    local got = post - pre
    if got <= 0 then
        player:SendBroadcastMessage("|cffFF0000[礼包] 物品 " .. itemId .. " 未能放入背包（可能已满或不存在）。|r")
        return 0
    end
    return got
end

-- 真人 / Bot 识别（GetAccountName 正则 + GetPlayerIP 空判断；fail-open 判为真实玩家）
local function IsRealPlayer(player)
    local ok, name = pcall(player.GetAccountName, player)
    if ok and name then
        if name:match("^rndbot") or name:match("^bot") or name:match("^playerbot")
           or name:match("^altbot") or name:match("^roster") then
            return false
        end
    end
    local ok2, ip = pcall(player.GetPlayerIP, player)
    if ok2 and (ip == "" or ip == nil) then
        return false
    end
    return true
end

-- 当前等级对应的成长衬衣 entry（封顶 SHIRT_MAX_LEVEL）
local function ShirtEntryForLevel(level)
    local L = level
    if L > CFG.SHIRT_MAX_LEVEL then L = CFG.SHIRT_MAX_LEVEL end
    if L < 1 then L = 1 end
    return CFG.SHIRT_BASE_ENTRY + L
end

-- 打开礼包时发放成长衬衣：按当前等级发对应档，去重 + 自动穿衬衫槽
local function GiveGrowthShirt(player)
    local L = player:GetLevel()
    local target = ShirtEntryForLevel(L)

    -- 已装备当前档则跳过
    local ok, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if ok and body then
        local _, e = pcall(body.GetEntry, body)
        if e == target then return end
    end
    -- 背包已有当前档则跳过
    local ok2, existing = pcall(player.GetItemByEntry, player, target)
    if ok2 and existing then return end

    local okAdd = pcall(player.AddItem, player, target, 1)
    if not okAdd then
        player:SendBroadcastMessage("|cffFF0000[新手礼包] 成长衬衣发放失败，请联系 GM。|r")
        return
    end

    if CFG.AUTO_EQUIP_SHIRT then
        local ok3, it = pcall(player.GetItemByEntry, player, target)
        if ok3 and it then
            pcall(player.EquipItem, player, it)
        end
    end
end

-- 右键打开新手礼包（ITEM_EVENT_ON_USE=2）
-- 签名：(event, player, item, count)
local function OnOpenGift(event, player, item, count)
    if not player or not item then return end

    if CFG.SKIP_BOTS then
        local ok, real = pcall(IsRealPlayer, player)
        if ok and not real then return end
    end

    -- 发放礼包内容
    for _, v in ipairs(CFG.BAG_CONTENT) do
        if v.kind == "growth_shirt" then
            GiveGrowthShirt(player)
        elseif v.id and v.id > 0 then
            SafeGiveItem(player, v.id, v.count or 1)
        end
    end

    -- 消耗礼包物品（打开即消失，防止重复开）
    pcall(player.RemoveItem, player, item, 1)

    player:SendBroadcastMessage(CFG.OPEN_MSG)
    if CFG.DEBUG then
        local _, nm = pcall(player.GetName, player)
        print("[starter_gift] 玩家 " .. (nm or "?") .. " 打开了新手礼包")
    end

    -- 返回 false：阻止物品被当作普通消耗品处理（OnItemUse 布尔语义，expectedValue=false）
    return false
end

-- 首次登录事件处理（仅角色第一次登录触发一次）
local function OnFirstLogin(event, player)
    if not player then return end

    if CFG.SKIP_BOTS then
        local ok, real = pcall(IsRealPlayer, player)
        if ok and not real then
            if CFG.DEBUG then
                local _, nm = pcall(player.GetName, player)
                print("[starter_gift] 跳过 Bot: " .. (nm or "?"))
            end
            return
        end
    end

    -- 1) 自动入会（保持首登入会）
    JoinStarterGuild(player)

    -- 2) 发放【新手礼包】物品（内容在打开时才发放）
    SafeGiveItem(player, CFG.GIFT_BAG_ITEM, 1)

    if CFG.WELCOME_MSG and CFG.WELCOME_MSG ~= "" then
        player:SendBroadcastMessage(CFG.WELCOME_MSG)
    end
end

-- 30 = PLAYER_EVENT_ON_FIRST_LOGIN
RegisterPlayerEvent(30, OnFirstLogin)
-- 2  = ITEM_EVENT_ON_USE（按礼包物品 entry 注册）
RegisterItemEvent(CFG.GIFT_BAG_ITEM, 2, OnOpenGift)

if CFG.DEBUG then
    print("[starter_gift_bag] 已加载：新号首登发礼包 + 右键打开发放内容")
end
