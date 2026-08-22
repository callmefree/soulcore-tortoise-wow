# -*- coding: utf-8 -*-
"""通用 paramiko SSH 执行器（强制 IPv4，避免 soulcore.asia 之类域名走 IPv6 卡死）。
用法：
   python 工具/ssh_generic.py HOST PORT USER PASS 'command'
密码含特殊字符时务必用单引号包住整个命令串。
"""
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
    if len(sys.argv) < 5:
        print("usage: ssh_generic.py HOST PORT USER PASS 'command'")
        sys.exit(1)
    host, port, user, passwd = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    cmd = sys.argv[5] if len(sys.argv) > 5 else "echo ok"
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
