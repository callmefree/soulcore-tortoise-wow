-- ============================================================
-- titan_grip.lua —— 泰坦之握（Titan's Grip）Lua 辅助守护脚本
-- 适用: Turtle WoW 1.12 + WYTurtle Eluna 引擎 (Lua 5.2)
-- 部署: 拷贝到 server/bin/lua_scripts/ 后重启 mangosd 生效
--
-- 职责（C++ 核心为主，本脚本为防御性守护 + 扩展接口）:
--   1) 装备合法性守护: PLAYER_EVENT_ON_EQUIP(29) 检测装备变化，
--      若玩家未学习泰坦之握但副手(槽16)出现双手武器，则移除并提示。
--      （正常流程下 C++ 的 CanEquipItem 已拦截，本守护覆盖"学习后
--        技能被移除"等边缘场景，属纵深防御。）
--   2) 奖励接口预留: 成就达标 / 特殊任务奖励方式留扩展点，
--      后续接入时在 GrantTitanGripByAchievement / GrantTitanGripByQuest
--      中实现即可，无需改动核心。
--
-- 依赖: 服务端已编译含 Player::CanTitanGrip() 的核心，
--       并已绑定 player:CanTitanGrip()（TurtleLuaEngine.cpp）。
-- ============================================================

-- ============ CFG 配置区 ============
local TITAN_GRIP_SPELL_ID = 908001   -- 泰坦之握被动技能（与 SQL 一致）
local OFFHAND_SLOT        = 16       -- EQUIPMENT_SLOT_OFFHAND
local INVTYPE_2HWEAPON    = 17       -- 双手武器装备类型
local ITEM_CLASS_WEAPON   = 2        -- 武器物品类

-- 是否启用装备合法性守护（生产默认 true）
local ENABLE_EQUIP_GUARD = true

-- ============ 工具函数 ============

-- 判断物品是否为双手武器（按装备类型，与 C++ 核心一致）
local function IsTwoHandWeapon(item)
    if not item then return false end
    local proto = item:GetProto()
    if not proto then return false end
    return proto:GetClass() == ITEM_CLASS_WEAPON
        and proto:GetInventoryType() == INVTYPE_2HWEAPON
end

-- 玩家是否已学习泰坦之握
local function HasTitanGrip(player)
    return player:CanTitanGrip() or player:HasSpell(TITAN_GRIP_SPELL_ID)
end

-- ============ 装备合法性守护 ============

-- PLAYER_EVENT_ON_EQUIP(29) 回调: (event, player, item, bag, slot)
-- 检测副手是否出现双手武器且玩家未学习泰坦之握 -> 移除并提示
local function OnEquip(event, player, item, bag, slot)
    if not ENABLE_EQUIP_GUARD then return end
    if not player or not player:IsInWorld() then return end

    -- 仅检查副手槽
    if slot ~= OFFHAND_SLOT then return end

    -- 副手当前装备的物品
    local offItem = player:GetEquippedItemBySlot(OFFHAND_SLOT)
    if not IsTwoHandWeapon(offItem) then return end

    -- 已学习泰坦之握 -> 合法，放行
    if HasTitanGrip(player) then return end

    -- 未学习 -> 非法状态，移除副手双手武器
    local entry = offItem:GetEntry()
    local name = offItem:GetName() or ("#" .. entry)
    player:RemoveItem(entry, 1)
    player:SendBroadcastMessage("|cffff0000[泰坦之握]|r 你尚未学习泰坦之握，无法在副手装备双手武器。")
    player:SendBroadcastMessage("|cffff0000[泰坦之握]|r 已移除副手的 " .. name .. "。请先学习泰坦之握。")
end

-- ============ 奖励接口预留（后续接入） ============

-- 预留: 成就达标奖励泰坦之握
-- 接入方式: 在成就达成事件中调用 GrantTitanGrip(player)
local function GrantTitanGripByAchievement(player, achievementId)
    -- TODO: 接入成就系统后实现
    -- 示例: if player:HasAchievement(achievementId) then GrantTitanGrip(player) end
    return false
end

-- 预留: 特殊任务奖励泰坦之握
-- 接入方式: 在任务完成事件中调用 GrantTitanGrip(player)
local function GrantTitanGripByQuest(player, questId)
    -- TODO: 接入任务系统后实现
    -- 示例: if player:HasQuest(questId) then GrantTitanGrip(player) end
    return false
end

-- 统一发放入口（预留，供上述奖励方式调用）
local function GrantTitanGrip(player)
    if not player then return false end
    if HasTitanGrip(player) then
        player:SendBroadcastMessage("|cff00ff00[泰坦之握]|r 你已掌握泰坦之握。")
        return false
    end
    -- 通过学习法术 908002 学习被动技能 908001
    player:CastSpell(player, 908002, true)
    player:SendBroadcastMessage("|cff00ff00[泰坦之握]|r 你学会了泰坦之握！现在可以在副手装备双手武器。")
    return true
end

-- ============ 事件注册 ============

-- 装备合法性守护
RegisterPlayerEvent(29, OnEquip)  -- 29 = PLAYER_EVENT_ON_EQUIP

print("[TitanGrip] 泰坦之握 Lua 守护已加载 (spell " .. TITAN_GRIP_SPELL_ID .. ")")
