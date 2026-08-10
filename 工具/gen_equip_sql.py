#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_equip_sql.py — ARPG 远古/太古装备 SQL 生成器
================================================
依据：ARPG系统移植计划书.md 阶段 0-3
功能：从 tw_world.item_template 读原版紫装（quality=4, class IN(2,4), entry<50000）
      生成 远古(+910000) / 太古(+920000) 条目 INSERT SQL。
规则：
  - 属性 stat_value_N × 1.2（远古） / × 1.4（太古），四舍五入
  - 拷贝 RandomProperty（保词缀池引用）、spellid_N/spelltrigger_N（保装备特效）
  - 拷贝 set_id/max_durability/bonding 等关键字段
  - 名字追加颜色码：远古 `|cFF007FFF★远古★`，太古 `|Cffcc3299★太古★`
  - 其他字段（价格/等级等）沿用原版
用法：
  python gen_equip_sql.py [--entries 12345,67890] [--limit 50] [--out out.sql]
  不传 --entries 时按 --limit 取样；生成 INSERT 幂等（INSERT IGNORE）。
"""
import sys, argparse, pymysql

DB = dict(host="127.0.0.1", port=3306, user="root", password="soulcore2026",
          database="tw_world", charset="utf8mb4")

# item_template 需要"复制+改"的关键列（其余按 SELECT * 全列复制）
# stat_value1..10 属性递增；entry/name 重写；其余照抄
STAT_COLS = [f"stat_value{i}" for i in range(1, 11)]

def fetch_columns(cur):
    cur.execute("SHOW COLUMNS FROM item_template")
    return [r[0] for r in cur.fetchall()]

def gen(entries, limit, out_path):
    conn = pymysql.connect(**DB)
    cur = conn.cursor()
    cols = fetch_columns(cur)
    # 原版紫装清单
    sql = ("SELECT entry, name FROM item_template "
           "WHERE quality=4 AND class IN (2,4) AND entry<50000 ")
    if entries:
        sql += "AND entry IN (%s) " % ",".join(str(e) for e in entries)
    sql += "ORDER BY entry LIMIT %d" % limit
    cur.execute(sql)
    base_items = cur.fetchall()
    if not base_items:
        print("未找到符合条件的原版紫装"); return 0

    col_sql = ",".join("`%s`" % c for c in cols)
    rows = []
    for (base_entry, base_name) in base_items:
        cur.execute("SELECT %s FROM item_template WHERE entry=%%s" % col_sql, (base_entry,))
        row = dict(zip(cols, cur.fetchone()))
        for off, tag, color in ((910000, "★远古★", "cFF007FFF"), (920000, "★太古★", "Cffcc3299")):
            r = dict(row)
            new_entry = base_entry + off
            r["entry"] = new_entry
            mult = 1.2 if off == 910000 else 1.4
            for sc in STAT_COLS:
                v = r.get(sc) or 0
                if v:
                    r[sc] = int(round(v * mult))
            # 名字颜色码（在原名后，遵循 Turtle 物品名颜色码语法）
            r["name"] = "%s|%s%s" % (base_name, color, tag)
            # 保词缀与特效：RandomProperty/spellid_N/spelltrigger_N 已随全列复制
            vals = []
            for c in cols:
                v = r.get(c)
                if v is None:
                    vals.append("NULL")
                elif isinstance(v, (int, float)):
                    vals.append(str(int(v)))
                else:
                    vals.append("'%s'" % str(v).replace("'", "''"))
            rows.append("INSERT IGNORE INTO `item_template` (%s) VALUES (%s);"
                        % (col_sql, ",".join(vals)))
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("-- ARPG 远古/太古装备 SQL（gen_equip_sql.py 生成 %s 件，%d 条目）\n" % (len(base_items), len(rows)))
        f.write("-- 目标库: tw_world | 幂等: INSERT IGNORE\n\n")
        f.write("\n".join(rows))
    print("生成 %d 件原版紫装 → %d 条 INSERT（%s）" % (len(base_items), len(rows), out_path))
    conn.close()
    return len(rows)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--entries", default="", help="逗号分隔的原版紫装 entry 白名单")
    ap.add_argument("--limit", type=int, default=50)
    ap.add_argument("--out", default="gen_equip_out.sql")
    a = ap.parse_args()
    entries = [int(x) for x in a.entries.split(",") if x] if a.entries else []
    gen(entries, a.limit, a.out)
