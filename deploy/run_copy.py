# -*- coding: utf-8 -*-
"""run_copy.py — 用 base64 写脚本到游戏服家目录，再 setsid 启动，把主服 data 复制到 PB 独立 data_real。"""
import paramiko, sys, socket, base64
import os

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))

SCRIPT = r'''#!/bin/bash
SRC=/opt/soulcore/server/data/
DST=/opt/soulcore-pb/server/data_real/
LOG=/home/administrator/pb_data_copy.log
echo "[$(date "+%F %T")] COPY START" >> "$LOG"
mkdir -p "$DST"
rsync -a "$SRC" "$DST" >> "$LOG" 2>&1
echo "[$(date "+%F %T")] COPY_DONE rc=$?" >> "$LOG"
'''


def make_sock(host, port):
    addrs = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.settimeout(30)
    s.connect(addrs[0][4])
    return s


def connect(p):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(p['host'], port=p['port'], username=p['user'], password=p['passwd'],
              sock=make_sock(p['host'], p['port']), timeout=30, banner_timeout=30)
    return c


def sh(c, cmd, timeout=60):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=False)
    return stdout.read().decode('utf-8', 'replace').strip(), stderr.read().decode('utf-8', 'replace').strip()


def main():
    c = connect(GAME)
    b64 = base64.b64encode(SCRIPT.encode('utf-8')).decode('ascii')
    out, err = sh(c, "echo %s | base64 -d > /home/administrator/copy_data.sh && chmod 755 /home/administrator/copy_data.sh && echo WROTE_OK" % b64)
    print('[write]', out, err)
    if 'WROTE_OK' not in out:
        print('[ERR] write failed'); c.close(); sys.exit(1)
    out3, err3 = sh(c, "setsid bash /home/administrator/copy_data.sh >/dev/null 2>&1 </dev/null & echo LAUNCHED_PID=$!")
    print('[launch]', out3, err3)
    c.close()
    print('[ok] 地图复制已在游戏服本地后台启动（setsid），日志 /home/administrator/pb_data_copy.log')


if __name__ == '__main__':
    main()
