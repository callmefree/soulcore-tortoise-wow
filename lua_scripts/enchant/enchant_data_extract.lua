-- enchant_data_extract.lua
-- 提取自 teleport_stone.lua 的 ENCMENU（16 个装备部位子菜单）
-- 目标：为 PB 服 super_hearthstone.lua 新增「装备附魔菜单（单一·覆盖式）」提供数据
--
-- 提取规则：
--   - 原格式 {ENC, "名称", enchantId, EQUIPMENT_SLOT_xxx}，第3字段即 spell_item_enchantment.id
--   - 已剔除：-1 清除项(13条) + 注释掉的旧id(1597/2661/1603/3834/3833)
--   - 按 enchantId 去重 → 共 69 个：weapon 16 + armor 53
--   - kind 为推断值（依据该 id 在原脚本出现的装备部位），最终以测试服 .lookup enchant 结果为准
--
-- ⚠️ 硬前置：每个 enchantId 必须在测试服 `.lookup enchant <id>` 实测存在于 spell_item_enchantment
--    无效 id 剔除后再写入 ENCHANTS；SetEnchantment 返回 false 仅作运行时兜底，不应依赖
-- ⚠️ 原脚本含肩(2)/衬衣(3)附魔数据，本方案白名单暂排除肩/衬衣，若实测有效可补回 ENCHANT_SLOTS
-- ⚠️ 盾牌用 EQUIPMENT_SLOT_OFFHAND(16)，已含在 weapon 白名单内

-- ===== 编码用 ENCHANTS 草稿（id 以实测为准）=====
local ENCHANTS = {
    -- ---------- weapon (16) ----------
    {name="增加耐力",                enchantId=3851, kind="weapon"},
    {name="命中等级，爆击等级",      enchantId=3788, kind="weapon"},
    {name="狂暴",                    enchantId=3789, kind="weapon"},
    {name="黑魔法",                  enchantId=3790, kind="weapon"},
    {name="破冰武器",                enchantId=3239, kind="weapon"},
    {name="生命护卫",                enchantId=3241, kind="weapon"},
    {name="吸血[75]",                enchantId=3870, kind="weapon"},
    {name="利刃防护[75]",            enchantId=3869, kind="weapon"},
    {name="增加敏捷",                enchantId=1103, kind="weapon"},
    {name="增加精神",                enchantId=3844, kind="weapon"},
    {name="斩杀",                    enchantId=3225, kind="weapon"},
    {name="猫鼬",                    enchantId=2673, kind="weapon"},
    {name="攻击强度",                enchantId=3827, kind="weapon"},
    {name="法术强度",                enchantId=3854, kind="weapon"},
    {name="亡灵伤害",                enchantId=3247, kind="weapon"},
    {name="巨人杀手",                enchantId=3251, kind="weapon"},

    -- ---------- armor (53) ----------
    {name="增加全属性",              enchantId=3832, kind="armor"},
    {name="法术强度，爆击等级[80]",  enchantId=3820, kind="armor"},
    {name="法术强度，法力回复[80]",  enchantId=3819, kind="armor"},
    {name="增加耐力，防御等级[80]",  enchantId=3818, kind="armor"},
    {name="攻击强度，爆击等级[80]",  enchantId=3817, kind="armor"},
    {name="增加耐力，韧性等级[80]",  enchantId=3842, kind="armor"},
    {name="攻击强度，韧性等级[80]",  enchantId=3795, kind="armor"},
    {name="法术强度，韧性等级[80]",  enchantId=3797, kind="armor"},
    {name="攻击强度，韧性等级[80]",  enchantId=3793, kind="armor"},
    {name="攻击强度",                enchantId=3845, kind="armor"},
    {name="法术强度，韧性等级[80]",  enchantId=3794, kind="armor"},
    {name="增加耐力，韧性等级[80]",  enchantId=3852, kind="armor"},
    {name="攻击强度，爆击等级[80]",  enchantId=3808, kind="armor"},
    {name="法术强度，法力回复[80]",  enchantId=3809, kind="armor"},
    {name="闪避等级，防御等级[80]",  enchantId=3811, kind="armor"},
    {name="法术强度，爆击等级[80]",  enchantId=3810, kind="armor"},
    {name="增加生命",                enchantId=3297, kind="armor"},
    {name="法力回复",                enchantId=2381, kind="armor"},
    {name="韧性等级",                enchantId=3245, kind="armor"},
    {name="防御等级",                enchantId=1953, kind="armor"},
    {name="增加精神，法术强度[70]",  enchantId=3719, kind="armor"},
    {name="增加耐力，法术强度[70]",  enchantId=3721, kind="armor"},
    {name="增加耐力，韧性等级[80]",  enchantId=3853, kind="armor"},
    {name="增加耐力，敏捷[80]",      enchantId=3822, kind="armor"},
    {name="攻击强度，爆击等级[80]",  enchantId=3823, kind="armor"},
    {name="法术强度",                enchantId=2332, kind="armor"},
    {name="增加耐力，移动速度",      enchantId=3232, kind="armor"},
    {name="增加敏捷",                enchantId=983,  kind="armor"},
    {name="增加精神",                enchantId=1147, kind="armor"},
    {name="增加生命，生命回复",      enchantId=3244, kind="armor"},
    {name="命中等级，爆击等级",      enchantId=3826, kind="armor"},
    {name="增加耐力",                enchantId=1075, kind="armor"},
    {name="增加耐力",                enchantId=3850, kind="armor"},
    {name="精准等级",                enchantId=3231, kind="armor"},
    {name="增加智力",                enchantId=1119, kind="armor"},
    {name="爆击等级",                enchantId=3249, kind="armor"},
    {name="增加威胁，招架等级",      enchantId=3253, kind="armor"},
    {name="增加敏捷",                enchantId=3222, kind="armor"},
    {name="命中等级",                enchantId=3234, kind="armor"},
    {name="法术强度",                enchantId=3246, kind="armor"},
    {name="强化潜行，增加敏捷",      enchantId=3256, kind="armor"},
    {name="增加精神，减少威胁",      enchantId=3296, kind="armor"},
    {name="防御等级",                enchantId=1951, kind="armor"},
    {name="急速等级",                enchantId=3831, kind="armor"},
    {name="增加护甲",                enchantId=3294, kind="armor"},
    {name="增加敏捷",                enchantId=1099, kind="armor"},
    {name="奥术抗性",                enchantId=1262, kind="armor"},
    {name="防御等级",                enchantId=1952, kind="armor"},
    {name="增加智力",                enchantId=1128, kind="armor"},
    {name="盾牌格挡",                enchantId=2655, kind="armor"},
    {name="韧性等级",                enchantId=3229, kind="armor"},
    {name="增加耐力",                enchantId=1071, kind="armor"},
    {name="格挡值",                  enchantId=2653, kind="armor"},
}

-- ===== 纯 id 实测清单（复制去测试服逐条 .lookup enchant）=====
-- weapon(16): 3851,3788,3789,3790,3239,3241,3870,3869,1103,3844,3225,2673,3827,3854,3247,3251
-- armor(53):  3832,3820,3819,3818,3817,3842,3795,3797,3793,3845,3794,3852,3808,3809,3811,3810,3297,2381,3245,1953,3719,3721,3853,3822,3823,2332,3232,983,1147,3244,3826,1075,3850,3231,1119,3249,3253,3222,3234,3246,3256,3296,1951,3831,3294,1099,1262,1952,1128,2655,3229,1071,2653
