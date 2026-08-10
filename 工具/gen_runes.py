# -*- coding: utf-8 -*-
"""生成 33 号符文条目（阶段1 1-4）"""
import pymysql

conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='soulcore2026',
                       database='tw_world', charset='utf8mb4')
cur = conn.cursor()
cur.execute('SELECT * FROM item_template WHERE entry=7910')
cols = [d[0] for d in cur.description]
base = dict(zip(cols, cur.fetchone()))

runes = [
    ('El 艾尔 1', '力量 +1', 2), ('Eld 艾德 2', '力量 +2', 2), ('Tir 特尔 3', '力量 +3', 2),
    ('Nef 那夫 4', '力量 +4', 2), ('Eth 爱斯 5', '力量 +5', 2), ('Ith 伊司 6', '敏捷 +1', 2),
    ('Tal 塔尔 7', '敏捷 +2', 2), ('Ral 拉尔 8', '敏捷 +3', 2), ('Ort 欧特 9', '敏捷 +4', 2),
    ('Thul 书尔 10', '敏捷 +5', 2), ('Amn 安姆 11', '智力 +1', 3), ('Sol 索尔 12', '智力 +2', 3),
    ('Shael 沙尔 13', '智力 +3', 3), ('Dol 多尔 14', '智力 +4', 3), ('Hel 海尔 15', '智力 +5', 3),
    ('Io 埃欧 16', '耐力 +1', 3), ('Lum 卢姆 17', '耐力 +2', 3), ('Ko 科 18', '耐力 +3', 3),
    ('Fal 法尔 19', '耐力 +4', 3), ('Lem 蓝姆 20', '耐力 +5', 3), ('Pul 普尔 21', '精神 +1', 3),
    ('Um 乌姆 22', '精神 +2', 3), ('Mal 马尔 23', '精神 +3', 3), ('Ist 伊司特 24', '精神 +4', 3),
    ('Gul 古尔 25', '精神 +5', 4), ('Vex 伐克斯 26', '防御 +1', 4), ('Ohm 欧姆 27', '防御 +3', 4),
    ('Lo 罗 28', '防御 +5', 4), ('Sur 瑟 29', '暴击 +1%', 4), ('Ber 贝 30', '暴击 +2%', 4),
    ('Jah 乔 31', '暴击 +3%', 5), ('Cham 查姆 32', '被击 10% 暗影箭(50伤)', 5),
    ('Zod 萨德 33', '被击 10% 暗影箭(70伤)', 6),
]
colsql = ','.join('`%s`' % c for c in cols)
for i, (name, dsc, q) in enumerate(runes, start=1):
    r = dict(base)
    r['entry'] = 900000 + i
    r['name'] = name
    r['description'] = '右键镶嵌到装备：' + dsc
    r['quality'] = q
    r['max_count'] = 10
    r['spellid_1'] = 8690
    r['spelltrigger_1'] = 0
    r['spellcooldown_1'] = 3600000
    vals = []
    for c in cols:
        v = r.get(c)
        if v is None:
            vals.append('NULL')
        elif isinstance(v, (int, float)):
            vals.append(str(int(v)))
        else:
            vals.append("'%s'" % str(v).replace("'", "''"))
    cur.execute('REPLACE INTO item_template (%s) VALUES (%s)' % (colsql, ','.join(vals)))
conn.commit()
cur.execute('SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 900001 AND 900033')
print('符文总数:', cur.fetchone()[0])
cur.execute('SELECT entry,name,quality FROM item_template WHERE entry BETWEEN 900001 AND 900033 ORDER BY entry LIMIT 6')
for r in cur.fetchall():
    print(r)
conn.close()

# ===== 905010 拉玛兰迪打孔器 =====
conn2 = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='soulcore2026',
                        database='tw_world', charset='utf8mb4')
cur2 = conn2.cursor()
cur2.execute('SELECT * FROM item_template WHERE entry=7910')
cols2 = [d[0] for d in cur2.description]
base2 = dict(zip(cols2, cur2.fetchone()))
r = dict(base2)
r['entry'] = 905010
r['name'] = '拉玛兰迪的礼物'
r['description'] = '右键为一件装备打孔，增加 1 个宝石槽（每件装备最多 2 孔）'
r['quality'] = 5
r['max_count'] = 10
r['spellid_1'] = 8690
r['spelltrigger_1'] = 0
r['spellcooldown_1'] = 3600000
colsql2 = ','.join('`%s`' % c for c in cols2)
vals = []
for c in cols2:
    v = r.get(c)
    if v is None:
        vals.append('NULL')
    elif isinstance(v, (int, float)):
        vals.append(str(int(v)))
    else:
        vals.append("'%s'" % str(v).replace("'", "''"))
cur2.execute('REPLACE INTO item_template (%s) VALUES (%s)' % (colsql2, ','.join(vals)))
conn2.commit()
cur2.execute('SELECT entry,name,quality FROM item_template WHERE entry=905010')
print('905010:', cur2.fetchone())
conn2.close()
