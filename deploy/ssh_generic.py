# -*- coding: utf-8 -*-
"""通用 paramiko SSH 执行器（强制 IPv4，避免 soulcore.asia 之类域名走 IPv6 卡死）。
用法：
   SOULCORE_SSH_PASS=<口令> python ssh_generic.py HOST PORT USER 'command'
口令走环境变量（不落 argv/ps），与 deploy/README.md 脱敏原则一致。
"""
import os
import sys
import socket
import paramiko


def make_sock(host, port):
    addrs = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.settimeout(30)
    s.connect(addrs[0][4])
    return s


def main():
    if len(sys.argv) < 4:
        print("usage: ssh_generic.py HOST PORT USER 'command'   (口令走环境变量 SOULCORE_SSH_PASS)")
        sys.exit(1)
    host, port, user = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    passwd = os.environ.get('SOULCORE_SSH_PASS', '')
    if not passwd:
        print("[ERR] 请先 export SOULCORE_SSH_PASS=（口令不落命令行/ps）")
        sys.exit(2)
    cmd = sys.argv[4] if len(sys.argv) > 4 else "echo ok"
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(host, port=port, username=user, password=passwd,
              sock=make_sock(host, port), timeout=30, banner_timeout=30)
    stdin, stdout, stderr = c.exec_command(cmd, timeout=60, get_pty=True)
    out = stdout.read().decode('utf-8', 'replace')
    err = stderr.read().decode('utf-8', 'replace')
    print(out)
    if err.strip():
        print("--- STDERR ---")
        print(err)
    c.close()


if __name__ == "__main__":
    main()
