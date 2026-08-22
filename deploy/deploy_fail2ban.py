# -*- coding: utf-8 -*-
"""在主服(运行PB服进程的 Ubuntu)上安装并配置 fail2ban：
规则：SSH 10分钟内登录失败5次 -> 封禁IP 3天(259200s)。
用法：python deploy_fail2ban.py [HOST] [PORT] [USER] [PASS]
默认 HOST=soulcore.asia PORT=56789 USER=administrator PASS=<env SOULCORE_SSH_PASS>（另可脚本第4参传入）
"""
import sys
import socket
import os
import paramiko

HOST = sys.argv[1] if len(sys.argv) > 1 else "soulcore.asia"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 56789
USER = sys.argv[3] if len(sys.argv) > 3 else "administrator"
PASS = sys.argv[4] if len(sys.argv) > 4 else os.environ.get("SOULCORE_SSH_PASS","")
SUDO = f"echo '{PASS}' | sudo -S"


def make_sock(host, port):
    addrs = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.settimeout(30)
    s.connect(addrs[0][4])
    return s


def run(c, cmd, timeout=120):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
    try:
        out = stdout.read().decode('utf-8', 'replace')
    except Exception:
        out = ""
    try:
        err = stderr.read().decode('utf-8', 'replace')
    except Exception:
        err = ""
    return out, err


def main():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, port=PORT, username=USER, password=PASS,
              sock=make_sock(HOST, PORT), timeout=30, banner_timeout=30)

    print("=== 1. 安装 fail2ban ===")
    out, err = run(c, f"{SUDO} apt-get update -qq 2>&1 | tail -3", timeout=300)
    print(out, err)
    out, err = run(c, f"{SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban 2>&1 | tail -15", timeout=600)
    print(out, err)

    print("=== 2. 写 jail.local ===")
    jail = r"""[DEFAULT]
# 永久放行本机与内网回环，避免误封
ignoreip = 127.0.0.1/8 ::1 127.0.0.2 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8
bantime.increment = true
bantime.factor = 1
bantime.formula = ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * ban.Multiplier

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 259200
"""
    # 用 base64 避免引号/换行转义问题
    import base64
    b64 = base64.b64encode(jail.encode()).decode()
    out, err = run(c, f"echo {b64} | base64 -d | {SUDO} tee /etc/fail2ban/jail.local >/dev/null")
    print(out, err)

    print("=== 3. 备份/清理旧 jail.d 默认(仅启用sshd) ===")
    out, err = run(c, f"{SUDO} grep -E '^#?' /etc/fail2ban/jail.conf >/dev/null 2>&1; echo done")
    print(out, err)

    print("=== 4. 启用并启动服务 ===")
    out, err = run(c, f"{SUDO} systemctl enable --now fail2ban 2>&1", timeout=120)
    print(out, err)

    print("=== 5. 等待并验证 ===")
    out, err = run(c, f"sleep 4; {SUDO} fail2ban-client status", timeout=60)
    print(out, err)
    out, err = run(c, f"sudo -n systemctl is-active fail2ban 2>&1; {SUDO} fail2ban-client get sshd bantime 2>&1; {SUDO} fail2ban-client get sshd maxretry 2>&1; {SUDO} fail2ban-client get sshd findtime 2>&1", timeout=60)
    print(out, err)

    c.close()
    print("\n=== DONE ===")


if __name__ == "__main__":
    main()
