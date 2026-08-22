# -*- coding: utf-8 -*-
"""sync_server_baseline.py — 只读探针 + 拉取活服务器状态，对比仓库基线（版本化事实来源）。

解决"服务器真身 vs git 基线漂移无人知晓"的缺口：
 1. 只读探针（不写服务器）：systemd 服务状态、DB 库/关键表行数；
 2. 拉取（只读 SFTP GET）：PB 服 `lua_scripts/`、`data/dbc` 回本地 `server_baseline/`；
 3. 对比仓库 `lua_scripts/` 与拉取副本，报告漂移；
 4. 生成 `docs/服务器现状_快照_<时间>.md`（事实快照，建议提交归档）。

漂移检查（`--check`，供本地/CI 定期执行）：
   探针 DB 事实 → 与 `docs/server_baseline_expected.json`（提交进库的期望值）比对，
   任何指标漂移 → 非零退出并打印 diff；另拉取 Lua 与仓库 diff，一并计入结果。

用法（需 python + paramiko；口令走环境变量，详见 deploy/README.md）：
  export SOULCORE_SSH_PASS=... SOULCORE_DB_PASS=...
  python deploy/sync_server_baseline.py                # 完整：探针+拉取+对比+快照
  python deploy/sync_server_baseline.py --no-pull      # 只探针+快照，不下载
  python deploy/sync_server_baseline.py --check        # 漂移检查（非零=漂移）；加 --no-pull 跳过 Lua 拉取
  python deploy/sync_server_baseline.py --store-expected # 把当前 DB 事实写为期望基线（迁移落地后跑）

输出：
  docs/服务器现状_快照_<YYYYmmdd_HHMM>.md   # 建议 git 提交
  docs/server_baseline_expected.json       # 期望值基线（--store-expected 生成，入库）
  server_baseline/                         # 活服文件留存（git 忽略，仅本地比对用）
"""
import os
import sys
import json
import socket
import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(BASE)                        # 仓库根
LIVE_DIR = os.path.join(REPO, "server_baseline")    # 拉取文件临时存放（不入库）
EXPECTED_FILE = os.path.join(REPO, "docs", "server_baseline_expected.json")

HOST = os.environ.get('SOULCORE_HOST', 'soulcore.asia')
PORT = int(os.environ.get('SOULCORE_PORT', '56789'))
USER = os.environ.get('SOULCORE_USER', 'administrator')
PASS = os.environ.get('SOULCORE_SSH_PASS', '')
DBPASS = os.environ.get('SOULCORE_DB_PASS', '')

PB_LUA = '/opt/soulcore-pb/server/bin/lua_scripts'
PB_DBC = '/opt/soulcore-pb/server/data/dbc'


def get_sock():
    addrs = socket.getaddrinfo(HOST, PORT, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.connect(addrs[0][4])
    return s


def connect():
    import paramiko
    cli = paramiko.SSHClient()
    cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    cli.connect(HOST, port=PORT, username=USER, password=PASS,
                sock=get_sock(), timeout=30, banner_timeout=30)
    return cli


def run(cli, cmd, timeout=60):
    stdin, stdout, stderr = cli.exec_command(cmd, timeout=timeout, get_pty=True)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    return (out or '').strip(), (err or '').strip()


def probe_services(cli):
    """systemd 服务是否 active（只读）。"""
    svcs = ["pbmangosd", "pbrealmd", "pb-tunnel", "mariadb"]
    states = {}
    for s in svcs:
        o, _ = run(cli, "systemctl is-active %s 2>/dev/null" % s)
        states[s] = o.strip() or "unknown"
    return states


def probe_dbs(cli):
    """只读：列出数据库 + PB 世界库关键表的终态校验数（keys 与期望 JSON 对齐）。"""
    if not DBPASS:
        return {"error": "未设 SOULCORE_DB_PASS，跳过 DB 探针"}
    rows = {}
    o, _ = run(cli, "mysql -uroot -p%s -N -e 'SHOW DATABASES' 2>/dev/null" % DBPASS)
    rows["databases"] = sorted(x for x in o.splitlines() if x.strip())
    checks = {
        "item_enchantment_template.50001": "SELECT COUNT(*) FROM tw_pb_world.item_enchantment_template WHERE entry=50001",
        "item_enchantment_template.52001": "SELECT COUNT(*) FROM tw_pb_world.item_enchantment_template WHERE entry=52001",
        "item_enchantment_template.52001_weight": "SELECT ROUND(SUM(chance),6) FROM tw_pb_world.item_enchantment_template WHERE entry=52001",
        "spell_proc_event.baseline": "SELECT COUNT(*) FROM tw_pb_world.spell_proc_event",
        "item_template.random=52001": "SELECT COUNT(*) FROM tw_pb_world.item_template WHERE random_property=52001",
    }
    for k, sqlstmt in checks.items():
        o, _ = run(cli, "mysql -uroot -p%s -N -e \"%s\" 2>/dev/null" % (DBPASS, sqlstmt))
        rows[k] = (o or "ERR")
    return rows


def _num(v):
    if v is None:
        return None
    try:
        return int(str(v))
    except (TypeError, ValueError):
        try:
            return float(str(v))
        except (TypeError, ValueError):
            return None


def run_check(dbs):
    """比对 DB 事实与期望基线；漂移则返回非零。"""
    if "error" in dbs:
        print("[ERR] %s" % dbs["error"])
        return 1
    if not os.path.isfile(EXPECTED_FILE):
        print("[ERR] 缺 %s；先跑 --store-expected 生成期望基线（入库）" % EXPECTED_FILE)
        return 1
    with open(EXPECTED_FILE, encoding='utf-8') as f:
        exp = json.load(f)
    fails = []
    rows = []
    for k in sorted(exp):
        if k.endswith("_tol"):
            continue
        want = exp[k]
        live = dbs.get(k)
        live_n = _num(live)
        if want is None or live_n is None:
            rows.append((k, want, live, "info"))
            continue
        tol = exp.get(k + "_tol", 0)
        ok = abs(live_n - want) <= tol
        rows.append((k, want, live, "OK" if ok else "DRIFT"))
        if not ok:
            fails.append(k)
    w = max((len(str(r[0])) for r in rows), default=20)
    print("%-*s  %-14s %-14s %s" % (w, "key", "expect", "live", "result"))
    for r in rows:
        print("%-*s  %-14s %-14s %s" % (w, r[0], r[1], r[2], r[3]))
    if fails:
        print("== DRIFT %d 项: %s ==" % (len(fails), ", ".join(fails)))
        return 1
    print("== OK：DB 事实与期望基线一致 ==")
    return 0


def store_expected(dbs):
    """把当前 DB 事实写为期望基线（迁移落地后再跑，结果入库随 git）。"""
    if "error" in dbs:
        print("[ERR] %s" % dbs["error"])
        return 1
    exp = {}
    for k in sorted(dbs):
        if k in ("databases", "error"):
            continue
        v = _num(dbs[k])
        exp[k] = v  # None 值视为「信息项」不参与严格比对
    # 为权重和加小容差（浮点 round 微差）
    if "item_enchantment_template.52001_weight" in exp:
        exp["item_enchantment_template.52001_weight_tol"] = 0.01
    os.makedirs(os.path.dirname(EXPECTED_FILE), exist_ok=True)
    with open(EXPECTED_FILE, "w", encoding="utf-8") as f:
        json.dump(exp, f, ensure_ascii=False, indent=2)
    print("== 期望基线已写入 %s（请 git 提交）==" % EXPECTED_FILE)
    return 0


def pull_dir(cli, remote, local_sub):
    """只读 SFTP 拉取目录树到 server_baseline/<local_sub>/（供比对）。"""
    sftp = cli.open_sftp()
    out = []
    try:
        for n in sftp.listdir(remote):
            out += _pull_rec(sftp, "%s/%s" % (remote, n), n, local_sub)
    except IOError as e:
        out.append("[listdir 失败] %s (%s)" % (remote, e))
    finally:
        sftp.close()
    return out


def _pull_rec(sftp, rp, name, local_sub):
    dst = os.path.join(REPO, "server_baseline", local_sub)
    os.makedirs(dst, exist_ok=True)
    out = []
    lp = os.path.join(dst, name)
    try:
        st = sftp.stat(rp)
        if st.st_mode & 0o40000:  # 目录 → 递归
            sub = os.path.join(local_sub, name)
            for n in sftp.listdir(rp):
                out += _pull_rec(sftp, "%s/%s" % (rp, n), n, sub)
            return out
    except IOError:
        pass
    try:
        sftp.get(rp, lp)
        out.append("%s -> %s" % (rp, lp))
    except IOError as e:
        out.append("[get 失败] %s (%s)" % (rp, e))
    return out


def md5file(p):
    import hashlib
    h = hashlib.md5()
    try:
        with open(p, 'rb') as f:
            for chunk in iter(lambda: f.read(65536), b''):
                h.update(chunk)
        return h.hexdigest()
    except IOError:
        return None


def compare_drift(repo_sub, live_sub):
    """对比仓库 <repo_sub> 与拉取副本 <live_sub>，返回漂移描述列表。"""
    repo_dir = os.path.join(REPO, repo_sub)
    live_dir = os.path.join(LIVE_DIR, live_sub)
    drift = []
    if not os.path.isdir(repo_dir) or not os.path.isdir(live_dir):
        return ["[跳过对比] 缺 %s 或 %s" % (repo_sub, live_sub)]
    local_map = {}
    for root, _d, files in os.walk(live_dir):
        for fn in files:
            lp = os.path.join(root, fn)
            local_map[os.path.relpath(lp, live_dir)] = md5file(lp)
    for root, _d, files in os.walk(repo_dir):
        for fn in files:
            if fn.startswith("README"):
                continue
            rp = os.path.join(root, fn)
            rel = os.path.relpath(rp, repo_dir)
            lm = md5file(rp)
            if rel not in local_map:
                drift.append("[仓库有/活服无] %s" % rel)
            elif local_map[rel] != lm:
                drift.append("[内容漂移]   %s" % rel)
    for rel in local_map:
        if not os.path.exists(os.path.join(repo_dir, rel)):
            drift.append("[活服有/仓库无] %s" % rel)
    return drift


def gen_snapshot(services, dbs, pulls, drifts):
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M")
    lines = []
    lines.append("# 服务器现状快照 %s" % ts)
    lines.append("")
    lines.append("> 由 `deploy/sync_server_baseline.py` 只读生成；口令不落盘。建议随 git 提交。")
    lines.append("")
    lines.append("## 服务状态")
    for s, st in services.items():
        lines.append("- `%s`: **%s**" % (s, st))
    lines.append("")
    if "error" in dbs:
        lines.append("## DB（跳过）")
        lines.append("- %s" % dbs["error"])
    else:
        lines.append("## DB 事实")
        lines.append("- 数据库: " + ", ".join(dbs.get("databases", [])))
        for k in dbs:
            if k == "databases":
                continue
            lines.append("- `%s` = %s" % (k, dbs[k]))
    lines.append("")
    lines.append("## 拉取（server_baseline/，不入库）")
    lines.append("```")
    lines.extend(pulls[:60])
    if len(pulls) > 60:
        lines.append("  … (共 %d 条)" % len(pulls))
    lines.append("```")
    lines.append("")
    lines.append("## 与仓库基线差异（lua_scripts 等）")
    if not drifts:
        lines.append("- ✅ 无漂移")
    else:
        for d in drifts:
            lines.append("- %s" % d)
    lines.append("")
    out = os.path.join(REPO, "docs", "服务器现状_快照_%s.md" % ts)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return out


def main():
    if not PASS:
        print("[ERR] 请先 export SOULCORE_SSH_PASS=（见 deploy/README.md）")
        return 1
    args = set(sys.argv[1:])
    check_mode = "--check" in args
    store_mode = "--store-expected" in args
    do_pull = "--no-pull" not in args and not store_mode
    cli = connect()
    try:
        print("== 探针: services ==")
        services = probe_services(cli)
        for s, st in services.items():
            print("  %-12s %s" % (s, st))
        print("== 探针: DB ==")
        dbs = probe_dbs(cli)
        for k, v in dbs.items():
            print("  %-42s %s" % (k, v))

        if check_mode:
            rc = run_check(dbs)
            if do_pull:
                print("== 拉取 lua_scripts 并比对 ==")
                pulls = pull_dir(cli, PB_LUA, "lua")
                drifts = compare_drift("lua_scripts", "lua")
                for d in drifts:
                    print("  " + d)
                if drifts:
                    rc = rc or 1
            return rc
        if store_mode:
            return store_expected(dbs)

        pulls = []
        drifts = []
        if do_pull:
            print("== 拉取 lua_scripts ==")
            pulls += pull_dir(cli, PB_LUA, "lua")
            print("== 拉取 dbc ==")
            pulls += pull_dir(cli, PB_DBC, "dbc")
            print("== 对比漂移 ==")
            drifts = compare_drift("lua_scripts", "lua")
            for d in drifts:
                print("  " + d)
        out = gen_snapshot(services, dbs, pulls, drifts)
        print("== 快照已生成: %s ==" % out)
        return 0
    finally:
        cli.close()


if __name__ == "__main__":
    sys.exit(main())