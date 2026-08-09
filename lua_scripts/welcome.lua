-- Soulcore 正式版登录欢迎脚本 (Eluna)
-- 第二阶段修正: RegisterServerEvent(1) -> (14) (WORLD_EVENT_ON_STARTUP, 实测触发; 1 为 SERVER_EVENT_ON_NETWORK_START 启动期不触发)
-- 清理: 移除 elunatest 测试残留(任意玩家领炉石, 原 P2)

-- 1. 登录欢迎
local function OnLogin(event, player)
    player:SendBroadcastMessage("|cff00ff00[Eluna]|r 欢迎来到 Soulcore 私服！Lua 引擎工作正常。")
    local name = player:GetName()
    player:SendBroadcastMessage("[Eluna] 你好, " .. name .. " (level " .. player:GetLevel() .. ")")
end
RegisterPlayerEvent(3, OnLogin)  -- PLAYER_EVENT_ON_LOGIN

-- 2. 服务器启动事件
local function OnStartup(event)
    print("[Eluna] Server started, Eluna scripting layer loaded!")
end
RegisterServerEvent(14, OnStartup)  -- WORLD_EVENT_ON_STARTUP
