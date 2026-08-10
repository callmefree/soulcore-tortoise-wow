-- city_crier.lua — 1-3 主城喊话机器人（模拟玩家喊话，营造人气）
-- 阶段1 A级第3项 ｜ 依据：ARPG系统移植计划书.md 1-3
-- 实现：CreateLuaEvent 定时全服广播，台词池随机，每 4 分钟一条
-- 事件/API：CreateLuaEvent(func, delay_ms, repeats=0 无限)、SendWorldMessage
-- 注：聊天触发词禁用点前缀（阶段0落地报告坑2）；本脚本无玩家事件

local CRIER_DELAY = 240000  -- 4 分钟
local LINES = {
    "世界频道：新手求带血色，来个治疗~",
    "世界频道：出售大量符文布，价格好商量！",
    "世界频道：厄运贡品队，来强力法师，来的点我！",
    "世界频道：刚满级，求个公会收留，晚上在线！",
    "世界频道：钓鱼大师在此，想学钓鱼的密我~",
    "世界频道：谁看见我昨天掉线的法师了？在线等，挺急的",
    "世界频道：拍卖行扫了一圈，穷人表示买不起……",
    "世界频道：夜色镇又被亡灵偷袭了，守卫呢？！",
}

local function CrierTick()
    local line = LINES[math.random(#LINES)]
    SendWorldMessage(line)
end

-- 启动 30 秒后开始循环（等服务端完全就绪），之后每 4 分钟一条
CreateLuaEvent(CrierTick, 30000, 0)

print("[ARPG] city_crier.lua loaded — 主城喊话已启动")
