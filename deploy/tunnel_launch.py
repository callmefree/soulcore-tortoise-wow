# -*- coding: utf-8 -*-
"""在游戏服以 setsid 常驻反向隧道（脚本文件方式，避内联 -c 不稳）。
游戏服 administrator 无免密 sudo，故不装 autossh，用自带 ssh + while 守护循环。
隧道：本地 3725/8091 -> HK(8.218.198.169) 反向转发，断线自动重连。
"""
import base64
import os
import sys
import socket
import paramiko

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))

SCRIPT = """#!/bin/bash
# PB reverse tunnel to HK (autossh-equivalent via ssh + restart loop)
while true; do
  ssh -i /home/administrator/.ssh/id_ed25519_hk \\
    -o StrictHostKeyChecking=no \\
    -o ServerAliveInterval=30 \\
    -o ServerAliveCountMax=3 \\
    -N \\
    -R 3725:localhost:3725 \\
    -R 8091:localhost:8091 \\
    root@8.218.198.169
  sleep 10
done
"""


def make_sock(host, port):
    addrs = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.settimeout(30)
    s.connect(addrs[0][4])
    return s


def sh(c, cmd, timeout=60):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
    out = stdout.read().decode('utf-8', 'replace')
    err = stderr.read().decode('utf-8', 'replace')
    return out, err


def main():
    b64 = base64.b64encode(SCRIPT.encode('utf-8')).decode('ascii')
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(GAME['host'], port=GAME['port'], username=GAME['user'], password=GAME['passwd'],
              sock=make_sock(GAME['host'], GAME['port']), timeout=30, banner_timeout=30)

    # 写脚本文件（base64 绕过引号问题）
    out, err = sh(c, "echo %s | base64 -d > /home/administrator/pb-tunnel.sh && chmod 755 /home/administrator/pb-tunnel.sh && echo WROTE_OK" % b64)
    print('[write]', out.strip(), err.strip())
    if 'WROTE_OK' not in out:
        print('[ERR] 脚本写文件失败'); c.close(); sys.exit(1)

    # 校验行数 + 内容
    out2, _ = sh(c, "wc -l /home/administrator/pb-tunnel.sh; head -3 /home/administrator/pb-tunnel.sh")
    print('[verify]', out2.replace(chr(10), ' | '))

    # setsid 常驻启动（已验证抗 SSH 断连）
    out3, err3 = sh(c, "setsid bash /home/administrator/pb-tunnel.sh >/dev/null 2>&1 </dev/null & echo LAUNCHED_PID=$!")
    print('[launch]', out3.strip(), err3.strip())
    c.close()
    print('[ok] 隧道脚本已写 /home/administrator/pb-tunnel.sh 并以 setsid 后台启动')


if __name__ == '__main__':
    main()
