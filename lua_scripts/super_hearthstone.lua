-- ============================================================
-- SuperHearthstone.lua — Soulcore 超级炉石
-- 适用: Turtle WoW 1.12 + WYTurtle Eluna 引擎 (Lua 5.2)
-- API 兼容性已逐项核对 TurtleLuaEngine 源码 (2026-08-09):
--   RegisterItemEvent(entry, 2=ITEM_EVENT_ON_USE, fn)        ✅ :17761
--   RegisterItemGossipEvent(entry, 2=GOSSIP_EVENT_ON_SELECT) ✅ :17765
--   GossipClearMenu / GossipMenuAddItem / GossipSendMenu     ✅ :18477-79
--   GossipComplete / TeleportTo                              ✅ :18480 / :18402
--   IsInCombat / IsDead / IsFalling                          ✅ :18041 / :17947 / :18315
--   GetMapId / GetX / GetY / GetZ / GetAccountId             ✅ :17931 / :17941-43 / :17930
--   CharDBQuery / CharDBExecute                              ✅ :17869 / :17879
--   QueryResult: GetRow / NextRow / GetUInt32 / GetFloat     ✅ :20145-20161
-- 功能:
--   1) 右键炉石 -> 弹出传送菜单(返回 false 阻止默认施法; 本引擎 item use 布尔语义
--      与官方 Eluna 相反: CallEntryEventForBoolean(expectedValue=false) @:25309)
--   2) 主城传送(联盟/部落)
--   3) 经典副本入口传送
--   4) 自定义传送点: 保存当前地点 / 传送至保存点 / 删除 (CharDB 持久化, 按账号)
--   5) 召唤机器人(PlayerBots): 仅限副本内, 每玩家最多 4 个
--      - 调 .bot add <角色> 让同账号角色上线为 bot, 再 .bot summon 拉到身边
--      - 数量统计: 在线玩家中同账号(GUID != 自己)的数量
--      - 依赖: mangosd 编译带 -DBUILD_PLAYERBOTS=ON 且 AiPlayerbot.Enabled=1
-- 部署: 拷贝到 server/bin/lua_scripts/ 后重启 mangosd 生效
--       (第二阶段实现 .reload eluna 后可热加载, 无需重启)
-- 注意: 坐标均为经典 1.12 常用值, 个别魔改地图位置可用 GM .go 实测后自行微调
-- ============================================================

local HEARTHSTONE = 6948                     -- 炉石 entry
local HS_DB_TABLE = "soulcore_hearthstone"   -- 自定义传送点表 (tw_char 库)

-- ============ 召唤机器人配置 ============
local MAX_BOTS = 4                          -- 每玩家最多召唤的机器人数量

-- ============ 传送点数据 (菜单内顺序 = 数组顺序) ============
-- 格式: { "显示名", map, x, y, z }

local CITY_POINTS = {
    { "暴风城",     0, -9065.0,   434.0,   93.5 },
    { "铁炉堡",     0, -4983.0,  -881.0,  501.7 },
    { "达纳苏斯",   1,  9951.5,  2280.3, 1341.4 },
    { "奥格瑞玛",   1,  1503.9, -4415.3,   21.8 },
    { "雷霆崖",     1, -1196.0,   129.0,  131.9 },
    { "幽暗城",     0,  1819.7,   238.8,   60.4 },
}

local DUNGEON_POINTS = {
    { "黑石山 (MC/BWL/黑石塔)",  0, -7534.0, -1190.0,  285.0 },
    { "祖尔格拉布",              1, -11916.5, -1216.0,   92.3 },
    { "安其拉 (神殿/废墟)",      1,  -8212.9,  2028.4, 1291.9 },
    { "纳克萨玛斯",              0,   3025.0, -3425.0,  294.0 },
    { "奥妮克希亚的巢穴",        1,  -4755.4, -3387.6,  309.6 },
    { "厄运之槌",                1,  -3527.0,  1095.0,  161.1 },
    { "通灵学院",                0,   1281.5, -2555.0,   95.5 },
    { "斯坦索姆",                0,   3358.0, -3379.0,  144.0 },
    { "血色修道院",              0,   2868.0,  -833.0,  160.0 },
    { "玛拉顿",                  1,  -1425.0,  2907.0,  103.0 },
}

-- ============ 菜单构建 ============

local function ShowMainMenu(player, item)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, "主城传送", 0, 1)
    player:GossipMenuAddItem(0, "副本与区域传送", 0, 2)
    player:GossipMenuAddItem(0, "自定义传送点", 0, 3)
    player:GossipMenuAddItem(0, "召唤机器人(副本内)", 0, 4)
    player:GossipMenuAddItem(0, "关闭菜单", 0, 9)
    player:GossipSendMenu(1, item)
end

local function ShowCityMenu(player, item)
    player:GossipClearMenu()
    for i, p in ipairs(CITY_POINTS) do
        player:GossipMenuAddItem(0, p[1], 1, i)
    end
    player:GossipMenuAddItem(0, "返回主菜单", 1, 0)
    player:GossipSendMenu(1, item)
end

local function ShowDungeonMenu(player, item)
    player:GossipClearMenu()
    for i, p in ipairs(DUNGEON_POINTS) do
        player:GossipMenuAddItem(0, p[1], 2, i)
    end
    player:GossipMenuAddItem(0, "返回主菜单", 2, 0)
    player:GossipSendMenu(1, item)
end

local function ShowCustomMenu(player, item)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, "保存当前地点", 3, 1)
    player:GossipMenuAddItem(0, "传送到保存点", 3, 2)
    player:GossipMenuAddItem(0, "删除保存点", 3, 3)
    player:GossipMenuAddItem(0, "返回主菜单", 3, 0)
    player:GossipSendMenu(1, item)
end

-- ============ 自定义传送点 (tw_char 库, 按账号一条) ============

local function GetCustomPoint(account)
    local q = CharDBQuery("SELECT map, x, y, z FROM " .. HS_DB_TABLE .. " WHERE account = " .. account)
    if q then
        local row = q:GetRow()
        return row[1], row[2], row[3], row[4]
    end
    return nil
end

local function SaveCustomPoint(player)
    local acct = player:GetAccountId()
    local map = player:GetMapId()
    local x, y, z = player:GetX(), player:GetY(), player:GetZ()
    CharDBExecute("INSERT INTO " .. HS_DB_TABLE ..
        " (account, map, x, y, z) VALUES (" .. acct .. ", " .. map .. ", " ..
        x .. ", " .. y .. ", " .. z ..
        ") ON DUPLICATE KEY UPDATE map = VALUES(map), x = VALUES(x), y = VALUES(y), z = VALUES(z)")
    player:SendBroadcastMessage("已保存当前位置作为自定义传送点。")
end

local function HandleCustom(player, item, action)
    local acct = player:GetAccountId()
    if action == 1 then
        SaveCustomPoint(player)
        player:GossipComplete()
    elseif action == 2 then
        local map, x, y, z = GetCustomPoint(acct)
        if map then
            player:TeleportTo(map, x, y, z, 0)
            player:GossipComplete()
        else
            player:SendBroadcastMessage("你还没有保存任何自定义传送点。")
            ShowCustomMenu(player, item)
        end
    elseif action == 3 then
        CharDBExecute("DELETE FROM " .. HS_DB_TABLE .. " WHERE account = " .. acct)
        player:SendBroadcastMessage("自定义传送点已删除。")
        player:GossipComplete()
    elseif action == 0 then
        ShowMainMenu(player, item)
    end
end

-- ============ 传送 (带战斗/死亡/坠落保护) ============

local function TeleportPlayer(player, p)
    if player:IsInCombat() or player:IsDead() or player:IsFalling() then
        player:SendBroadcastMessage("战斗中/死亡/坠落状态下无法传送。")
        player:GossipComplete()
        return
    end
    player:TeleportTo(p[2], p[3], p[4], p[5], 0)
    player:GossipComplete()
end

-- ============ 召唤机器人 (PlayerBots) ============
-- 规则: 仅限副本内(IsDungeon 含 5人本+团本), 每玩家最多 MAX_BOTS 个
-- 实现: player:RunCommand(".bot add <角色名>") 让同账号角色上线为 bot,
--       再 .bot summon <角色名> 拉到身边。
-- 数量统计: 遍历在线玩家, 统计同账号(GUID != 自己)的在线角色数。

local function GetSummonedBotCount(player)
    local acct = player:GetAccountId()
    local selfGuid = player:GetGUIDLow()
    local count = 0
    local players = GetPlayersInWorld()
    for i = 1, #players do
        local p = players[i]
        if p and p:GetAccountId() == acct and p:GetGUIDLow() ~= selfGuid then
            count = count + 1
        end
    end
    return count
end

local function GetAccountAltNames(player)
    -- 返回同账号下其他角色名列表 (排除当前角色)
    local acct = player:GetAccountId()
    local selfGuid = player:GetGUIDLow()
    local names = {}
    local q = CharDBQuery("SELECT name, guid FROM characters WHERE account = " .. acct)
    if q then
        local row = q:GetRow()
        while row do
            local guid = row[2]
            if guid and guid ~= selfGuid then
                table.insert(names, row[1])
            end
            if not q:NextRow() then break end
            row = q:GetRow()
        end
    end
    return names
end

local function IsOnlineByName(name)
    local players = GetPlayersInWorld()
    for i = 1, #players do
        local p = players[i]
        if p and p:GetName() == name then
            return true
        end
    end
    return false
end

local function ShowBotMenu(player, item)
    player:GossipClearMenu()
    local count = GetSummonedBotCount(player)
    player:GossipMenuAddItem(0, string.format("当前已召唤: %d/%d", count, MAX_BOTS), 4, 0)
    local alts = GetAccountAltNames(player)
    if #alts == 0 then
        player:GossipMenuAddItem(0, "该账号没有其他角色可用", 4, 0)
    else
        for i, name in ipairs(alts) do
            local suffix = IsOnlineByName(name) and " (已上线)" or ""
            player:GossipMenuAddItem(0, "召唤 " .. name .. suffix, 4, 100 + i)
        end
    end
    player:GossipMenuAddItem(0, "返回主菜单", 4, 0)
    player:GossipSendMenu(1, item)
end

-- action: 100+i -> 召唤第 i 个角色
local function HandleBotSelect(player, item, action)
    local map = player:GetMap()
    if not map or not map:IsDungeon() then
        player:SendBroadcastMessage("只能在副本内召唤机器人。")
        ShowMainMenu(player, item)
        return
    end

    if GetSummonedBotCount(player) >= MAX_BOTS then
        player:SendBroadcastMessage("最多只能召唤 " .. MAX_BOTS .. " 个机器人。")
        ShowMainMenu(player, item)
        return
    end

    local alts = GetAccountAltNames(player)
    local idx = action - 100
    if not alts[idx] then
        player:SendBroadcastMessage("角色不存在。")
        ShowMainMenu(player, item)
        return
    end

    local name = alts[idx]
    player:RunCommand(".bot add " .. name)
    player:RunCommand(".bot summon " .. name)
    player:SendBroadcastMessage("正在召唤 " .. name .. " ...")
    player:GossipComplete()
end

-- ============ 全局命令拦截: 机器人只能在副本内召唤 ============
-- Chat.cpp:1755 在 ExecuteCommand 前调用 sTurtleLuaEngine.OnPlayerCommand(player, text),
-- 返回 false 即阻止该命令。因此玩家直接敲 `.bot add` / `.rndbot add` 在野外也会被拦,
-- 无法绕过炉石菜单的副本限制。(事件 42 = PLAYER_EVENT_ON_COMMAND)
local BOT_BLOCK_SUBS = {
    add = true, login = true, always = true,
    summon = true, recall = true, come = true,
}

local function OnPlayerCommand(event, player, command, chatHandler)
    if not player then return true end

    -- 副本内放行 (lua 菜单召唤也走这里, 副本内正常通过)
    local map = player:GetMap()
    if map and map:IsDungeon() then return true end

    local cmd, sub = command:match("^(%S+)%s+(%S+)")
    if (cmd == "bot" or cmd == "rndbot") and sub and BOT_BLOCK_SUBS[sub] then
        player:SendBroadcastMessage("只能在副本内召唤机器人。")
        return false
    end
    return true
end
RegisterPlayerEvent(42, OnPlayerCommand)

-- ============ 事件注册 ============

-- 右键炉石 -> 弹菜单并阻止默认回城
-- 注意: 本引擎 CallEntryEventForBoolean 对 item use 事件传入 expectedValue=false
--       (TurtleLuaEngine.cpp:25309), 因此 handler 返回 FALSE 才命中"阻止施法";
--       return true 反而等于不干预, 炉石施法会照常进行。与官方 Eluna 语义相反。
local function OnHearthstoneUse(event, player, item, targets)
    if player:IsInCombat() or player:IsDead() or player:IsFalling() then
        player:SendBroadcastMessage("战斗中/死亡/坠落状态下无法使用超级炉石。")
        return false  -- 阻止施法
    end
    ShowMainMenu(player, item)
    return false  -- 关键: 返回 false 阻止炉石默认施法, 改用我们的菜单
end
RegisterItemEvent(HEARTHSTONE, 2, OnHearthstoneUse)  -- 2 = ITEM_EVENT_ON_USE

-- 菜单选项点击 -> 分发 (参数: event, player, item, sender, action, code)
local function OnHearthstoneGossipSelect(event, player, item, sender, action, code)
    if sender == 0 then
        if action == 1 then
            ShowCityMenu(player, item)
        elseif action == 2 then
            ShowDungeonMenu(player, item)
        elseif action == 3 then
            ShowCustomMenu(player, item)
        elseif action == 4 then
            ShowBotMenu(player, item)
        elseif action == 9 then
            player:GossipComplete()
        end
        return
    end

    if action == 0 then
        ShowMainMenu(player, item)   -- 各子菜单的"返回主菜单"
        return
    end

    if sender == 1 then
        local p = CITY_POINTS[action]
        if p then TeleportPlayer(player, p) end
    elseif sender == 2 then
        local p = DUNGEON_POINTS[action]
        if p then TeleportPlayer(player, p) end
    elseif sender == 3 then
        HandleCustom(player, item, action)
    elseif sender == 4 then
        if action == 0 then
            ShowMainMenu(player, item)
        elseif action >= 100 then
            HandleBotSelect(player, item, action)
        end
    end
end
RegisterItemGossipEvent(HEARTHSTONE, 2, OnHearthstoneGossipSelect)  -- 2 = GOSSIP_EVENT_ON_SELECT

-- 启动时确保自定义传送点表存在
CharDBExecute("CREATE TABLE IF NOT EXISTS " .. HS_DB_TABLE ..
    " (account INT UNSIGNED NOT NULL PRIMARY KEY, map SMALLINT UNSIGNED NOT NULL, " ..
    "x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL)")

print("[SuperHearthstone] 超级炉石已加载 — 右键炉石打开传送菜单 (entry " .. HEARTHSTONE .. ")")
