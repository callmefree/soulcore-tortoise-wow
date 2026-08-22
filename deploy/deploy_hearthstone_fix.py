# -*- coding: utf-8 -*-
"""deploy_hearthstone_fix.py
把本地修复版 super_hearthstone.lua 部署到 PB 服(并同步主服文件)，重启 PB mangosd。
- PB 服(/opt/soulcore-pb): 部署 + 重启 mangosd(tmux session pbmangosd)
- 主服(/opt/soulcore): 仅同步文件，不重启(避免影响主服在线玩家)
"""
import os, time, sys
sys.path.insert(0, r"E:\11111\soulcore tortoise wow\工具")
from ssh_soulcore import connect

LOCAL = r"E:\11111\soulcore tortoise wow\super_hearthstone.lua"
TS = time.strftime("%Y%m%d-%H%M%S")

PB_BIN = "/opt/soulcore-pb/server/bin/lua_scripts/super_hearthstone.lua"
MAIN_BIN = "/opt/soulcore/server/bin/lua_scripts/super_hearthstone.lua"

PB_MANGOSD_PATTERN = "soulcore-pb/server/etc/mangosd.conf"
PB_MANGOSD_CMD = "cd /opt/soulcore-pb/server/bin && ./mangosd -c /opt/soulcore-pb/server/etc/mangosd.conf"
PB_SESS = "pbmangosd"
PB_PORT = "8091"


def log(m):
    print(m, flush=True)


def run_remote(cmd, timeout=120):
    c = connect()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
        return out, err
    finally:
        c.close()


def sftp_put(local, remote):
    c = connect()
    try:
        sftp = c.open_sftp()
        # 备份旧文件
        bak = remote + ".bak-" + TS
        try:
            sftp.posix_rename(remote, bak)
            log(f"  备份 {remote} -> {bak}")
        except Exception as e:
            log(f"  (备份跳过: {e})")
        sftp.put(local, remote)
        sftp.chmod(remote, 0o644)
        log(f"  上传 {local} -> {remote}")
        sftp.close()
    finally:
        c.close()


def main():
    if not os.path.exists(LOCAL):
        log("!! 本地文件缺失: " + LOCAL)
        sys.exit(1)

    # 1) 备份 + 上传 PB 和 主服
    log("=== [1] 备份并上传 ===")
    sftp_put(LOCAL, PB_BIN)
    sftp_put(LOCAL, MAIN_BIN)

    # 2) 校验文件已到位
    log("=== [2] 校验远端文件行数 ===")
    out, _ = run_remote(f"wc -l {PB_BIN} {MAIN_BIN}")
    log(out.strip())

    # 3) 重启 PB mangosd
    log("=== [3] 重启 PB mangosd ===")
    out, _ = run_remote(f"pgrep -f '{PB_MANGOSD_PATTERN}'")
    pids = [x for x in out.split() if x.strip().isdigit()]
    log(f"  当前 PB mangosd pid: {pids or '(无)'}")
    if pids:
        for pid in pids:
            log(f"  kill -INT {pid} (优雅退出)")
            run_remote(f"kill -INT {pid}")
        # 等待优雅退出
        for i in range(20):
            time.sleep(3)
            out, _ = run_remote(f"pgrep -f '{PB_MANGOSD_PATTERN}'")
            left = [x for x in out.split() if x.strip().isdigit()]
            if not left:
                log(f"  已优雅退出 (等待 {(i+1)*3}s)")
                break
            log(f"  ... 仍在退出中 ({left})")
        else:
            out, _ = run_remote(f"pgrep -f '{PB_MANGOSD_PATTERN}'")
            left = [x for x in out.split() if x.strip().isdigit()]
            if left:
                log(f"  仍未退出，强制 kill -KILL {left}")
                run_remote("kill -KILL " + " ".join(left))
                time.sleep(5)
    else:
        log("  (未发现运行中的 PB mangosd，直接启动)")

    # 销毁旧 tmux session
    run_remote(f"tmux kill-session -t {PB_SESS} 2>/dev/null")
    time.sleep(2)
    # 新建 session 拉起 (提供 pty)
    out, err = run_remote(f"tmux new-session -d -s {PB_SESS} '{PB_MANGOSD_CMD}'")
    if err.strip():
        log(f"  new-session stderr: {err.strip()}")
    time.sleep(10)

    # 4) 验证
    log("=== [4] 重启后验证 ===")
    out, _ = run_remote(f"pgrep -af '{PB_MANGOSD_PATTERN}'")
    log(f"  进程: {out.strip() or '(无)'}")
    out, _ = run_remote(f"ss -ltn 2>/dev/null | grep ':{PB_PORT}'")
    log(f"  端口 {PB_PORT}: {out.strip() or '(未监听)'}")
    # 日志路径探测 + 检查 lua 加载错误
    out, _ = run_remote("ls -t /opt/soulcore-pb/server/logs/*.log 2>/dev/null | head -1")
    logpath = out.strip()
    log(f"  最新日志: {logpath or '(未找到)'}")
    if logpath:
        out, _ = run_remote(f"tail -n 40 '{logpath}' | grep -iE 'lua|eluna|error|SuperHearthstone|script' | tail -n 20")
        log(f"  日志相关行:\n{out.strip() or '(无 lua/error 关键字)'}")

    log("=== DONE ===")


if __name__ == "__main__":
    main()
