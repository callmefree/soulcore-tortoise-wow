# -*- coding: utf-8 -*-
"""修复：正确写入 /etc/fail2ban/jail.local（固定 bantime=259200s=3天）。
并 reload fail2ban 验证。用法同 deploy_fail2ban.py。
"""
import sys
import socket
import base64
import paramiko

HOST = sys.argv[1] if len(sys.argv) > 1 else "soulcore.asia"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 56789
USER = sys.argv[3] if len(sys.argv) > 3 else "administrator"
PASS = sys.argv[4] if len(sys.argv) > 4 else os.environ.get("SOULCORE_SSH_PASS","")

jail = r"""[DEFAULT]
# 永久放行本机回环与内网，避免误封自己
ignoreip = 127.0.0.1/8 ::1 127.0.0.2 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8
# 固定封禁时长，不启用递增（保证每次都是3天）
bantime.increment = false

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 259200
"""


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
    b64 = base64.b64encode(jail.encode()).decode()
    # 密码放最前，管道只给 sudo 传密码；base64 用 bash -c 解码写文件
    cmd = (f"echo '{PASS}' | sudo -S bash -c \"echo '{b64}' | base64 -d "
           f"> /etc/fail2ban/jail.local\" 2>&1")
    print("=== 写入 jail.local ===")
    out, err = run(c, cmd, timeout=60)
    print(out, err)

    print("=== 校验文件内容 ===")
    out, err = run(c, "cat /etc/fail2ban/jail.local")
    print(out, err)

    print("=== reload + 验证参数 ===")
    out, err = run(c, "echo '%s' | sudo -S fail2ban-client reload 2>&1 && sleep 2; echo '%s' | sudo -S fail2ban-client get sshd bantime 2>&1; echo '%s' | sudo -S fail2ban-client get sshd maxretry 2>&1; echo '%s' | sudo -S fail2ban-client get sshd findtime 2>&1; echo '%s' | sudo -S fail2ban-client get sshd enabled 2>&1" % (PASS, PASS, PASS, PASS, PASS), timeout=90)
    print(out, err)
    c.close()
    print("=== DONE ===")


if __name__ == "__main__":
    main()
