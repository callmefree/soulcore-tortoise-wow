-- ============================================================================
-- growing_shirt_mvp.lua  (新手衬衣 —— 全职业 5 属性双槽 STAT 附魔)
-- 新手衬衣：同一件衬衣(entry 910000) + item:SetEnchantment 随等级刷新
--   PERM(0)+TEMP(1) 双槽附魔，属性随等级渐变，全职业通用。
-- 机制（v3 改版，替代 v1 职业分属性 70001..70063）：
--   5 属性 = 力量/敏捷/耐力/智力/精神，全部随等级档位渐变
--   STAT 附魔一条最多 3 effect → 拆 2 条附魔（id 段 80001..80014）：
--     附魔 A = 力量(4)/敏捷(3)/耐力(7) 3 effect（type=5/5/5）→ PERM(0) 槽
--     附魔 B = 智力(5)/精神(6)       2 effect（type=5/5/0）→ TEMP(1) 槽
--   每档 SetEnchantment 两次（A→PERM、B→TEMP），5 属性一次到位
--   数值档位：TIER = {20,40,60,80,100,120,120}，1/10/20/30/40/50/60 级
-- 适配：Turtle-WoW 1.18.1 / TurtleLuaEngine（feature/playerbots 分支）
-- 数据：item_template 由配套 SQL 生成（entry 910000，无静态属性，属性全走附魔）
--
-- ⚠️ 引擎铁律（已读源码交叉验证）：
--   1. item:SetEnchantment(enchant, slot)：附魔 id 在前、slot 在后
--      （TurtleLuaEngine.cpp:12346-12367；与标准 Eluna 相反！）
--      SetEnchantment 内部 duration/charges 传 0 → 不入时长列表（Player.cpp:14009），
--      TEMP 槽等同"永久"、与 PERM 同样持久化（item_instance enchantments 三槽）。
--      幂等：同值 early-return（Item.cpp:998-1002）；错传返 false 不写坏。
--      EnchantmentSlot：0=PERM / 1=TEMP / 3-6=PROP（Item.h:141-152）。
--   2. ApplyEnchantment 遍历全部槽（Player.cpp:13858-13861），STAT type 在
--      TEMP 槽同样生效（Player.cpp:13918+）；type=0(NONE) 仅 switch case break
--      （Player.cpp:13891-13892），故 5/5/0 = 2 effect。
--   3. player.RemoveItem(player, e, 1)：第二参是 entry 数字（不是 item 对象）。
--      （本脚本不删除物品，无此调用。）
--   4. player.GetItemByEntry 只返回首件且含银行（inBank=true）；对银行物品 EquipItem
--      绑定会先移除再装备、失败即丢物 → 装备前守卫 item:GetBagSlot() < 39。
--      （本脚本只读 GetEquippedItemBySlot，不主动发/穿物品，天然避开。）
--   5. pcall(player.M, player, ...) 等价 player:M(...)，可用。
--
-- ⚠️ DBC 铁律（v3 新增）：
--   * 新附魔 id 80001..80014 需同时存在于服务端 DBC（追加 14 条）与客户端
--     patch-A（patch-7 SIE 1514 + 14 = 1528 条）。
--   * 旧 63 条（70001..70063）在服务端 SIE 保留不删（无人引用无害）；
--     客户端 patch-A 已重建为只含 14 条新附魔（干净）。
--   * DBC 改动无 .reload，改后必须重启 mangosd。
--
-- 事件号：ON_LOGIN=3 / ON_FIRST_LOGIN=30 / ON_LEVEL_CHANGE=13 / ON_EQUIP=29
-- 部署：放入服务器 lua_scripts/，重启 mangosd 或 .reload eluna 生效。
--       item_template 改动须 restart pbmangosd（缓存不热更）。
-- ============================================================================

-- ===================== 顶部集中配置区（只改这里） =====================
local CFG = {
    ENTRY        = 910000,   -- 新手衬衣 item entry（item_template 单行，无静态属性）
    BODY_SLOT    = 3,        -- EQUIPMENT_SLOT_BODY（衬衫槽）
    PERM_SLOT    = 0,        -- EnchantmentSlot::PERM（附魔 A：力/敏/耐）
    TEMP_SLOT    = 1,        -- EnchantmentSlot::TEMP（附魔 B：智/精）
    MAX_LEVEL    = 60,       -- 封顶等级（须与 TIER_STARTS 末档一致）
    DEBUG        = false,    -- true 时打印刷新日志到服务端控制台
    -- 各档起始等级（顺序即档位 1..7）
    TIER_STARTS  = {1, 10, 20, 30, 40, 50, 60},
    -- 档位 -> {附魔A(id), 附魔B(id)}（SpellItemEnchantment.dbc 已追加，id 段 80001..80014）
    -- 附魔 A = 力/敏/耐（type 5/5/5 → PERM 槽）；附魔 B = 智/精（type 5/5/0 → TEMP 槽）
    -- 数值：tier1=20 tier2=40 tier3=60 tier4=80 tier5=100 tier6=120 tier7=120(封顶)
    TIER_ENCHANTS = {
        {80001, 80002},   -- I   : 20
        {80003, 80004},   -- II  : 40
        {80005, 80006},   -- III : 60
        {80007, 80008},   -- IV  : 80
        {80009, 80010},   -- V   : 100
        {80011, 80012},   -- VI  : 120
        {80013, 80014},   -- VII : 120（封顶）
    },
    MSG_REFRESH  = "|cff00ccff[新手衬衣]|r 已成长至第 %d 阶（5 属性，附魔 id %d/%d）！",
}
-- ============================================================================

local MAX_TIER = #CFG.TIER_STARTS  -- 7

-- 等级 -> 档位(1..7)
local function TierForLevel(level)
    local L = level or 1
    if L > CFG.MAX_LEVEL then L = CFG.MAX_LEVEL end
    if L < 1 then L = 1 end
    local t = 1
    for i = 1, MAX_TIER do
        if L >= CFG.TIER_STARTS[i] then t = i end
    end
    return t
end

-- 档位 -> 罗马数字（用于 DEBUG/日志）
local TIER_EXTRA = { 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII' }

-- bot 过滤（playerbots 不穿衬衣）：账号名前缀匹配
-- ⚠️ GetPlayerIP 恒非空，IP 判空无效——不做 IP 判空
local BOT_PREFIX = { 'rndbot', 'bot', 'playerbot', 'altbot', 'roster' }
local function IsRealPlayer(player)
    if not player then return false end
    local ok, acc = pcall(player.GetAccountName, player)
    if not (ok and acc) then return false end
    for _, p in ipairs(BOT_PREFIX) do
        if acc:sub(1, #p) == p then return false end
    end
    return true
end

-- 核心（幂等）：按等级刷新「已装备」的新手衬衣 PERM+TEMP 双槽附魔
-- 未装备 / 非 910000 / 非真实玩家 → 直接跳过，不自动发物品
local function ApplyShirtEnchant(player)
    if not player then return end

    local okLvl, level = pcall(player.GetLevel, player)
    if not (okLvl and level) then return end
    local tier = TierForLevel(level)
    local enchPair = CFG.TIER_ENCHANTS[tier]
    if not enchPair then
        if CFG.DEBUG then print('[growing_shirt_mvp] 无档位附魔 tier=' .. tostring(tier) .. '，跳过') end
        return
    end
    local enchA, enchB = enchPair[1], enchPair[2]

    -- 只处理「已装备在衬衫槽」的新手衬衣
    local okBody, body = pcall(player.GetEquippedItemBySlot, player, CFG.BODY_SLOT)
    if not (okBody and body) then
        if CFG.DEBUG then print('[growing_shirt_mvp] 衬衫槽未装备，跳过') end
        return
    end
    local okEntry, entry = pcall(body.GetEntry, body)
    if not (okEntry and entry == CFG.ENTRY) then
        if CFG.DEBUG then print('[growing_shirt_mvp] 衬衫槽非新手衬衣，跳过') end
        return
    end

    -- SetEnchantment(enchant, slot)：附魔 id 在前、slot 在后（引擎铁律！）
    -- 幂等：同值 early-return 天然防抖（Item.cpp:998-1002）
    -- duration/charges=0 → 不入时长列表，TEMP 槽等同永久（Player.cpp:14009）
    local okA, okValA = pcall(body.SetEnchantment, body, enchA, CFG.PERM_SLOT)
    if not (okA and okValA) then
        if CFG.DEBUG then print('[growing_shirt_mvp] SetEnchantment(A) 失败 entry=' .. entry .. ' ench=' .. enchA) end
        return
    end
    local okB, okValB = pcall(body.SetEnchantment, body, enchB, CFG.TEMP_SLOT)
    if not (okB and okValB) then
        if CFG.DEBUG then print('[growing_shirt_mvp] SetEnchantment(B) 失败 entry=' .. entry .. ' ench=' .. enchB) end
        return
    end

    if CFG.DEBUG then
        print('[growing_shirt_mvp] 刷新 lvl=' .. level .. ' tier=' .. tier
            .. ' enchA=' .. enchA .. ' enchB=' .. enchB .. ' (' .. TIER_EXTRA[tier] .. ')')
    end
end

-- ============ 事件入口（全部收敛到 ApplyShirtEnchant，幂等） ============
local function OnLogin(event, player)            -- 3
    if not player or not IsRealPlayer(player) then return end
    ApplyShirtEnchant(player)
end

local function OnFirstLogin(event, player)       -- 30
    if not player or not IsRealPlayer(player) then return end
    ApplyShirtEnchant(player)
end

local function OnLevelChange(event, player, oldLevel)  -- 13（升级事件内 GetLevel 已是新等级）
    if not player or not IsRealPlayer(player) then return end
    ApplyShirtEnchant(player)  -- SetEnchantment 后核心 ApplyEnchantment 即时刷面板
end

local function OnEquip(event, player, item, bag, slot)  -- 29（穿上即刷新，防呆）
    if not player or not IsRealPlayer(player) then return end
    if item then
        local ok, e = pcall(item.GetEntry, item)
        if ok and e == CFG.ENTRY then
            ApplyShirtEnchant(player)
        end
    end
end

RegisterPlayerEvent(3,  OnLogin)
RegisterPlayerEvent(30, OnFirstLogin)
RegisterPlayerEvent(13, OnLevelChange)
RegisterPlayerEvent(29, OnEquip)

if CFG.DEBUG then
    print('[growing_shirt_mvp] 已加载：新手衬衣（entry ' .. CFG.ENTRY .. '，全职业 5 属性双槽附魔 ' .. MAX_TIER .. ' 档）')
end
