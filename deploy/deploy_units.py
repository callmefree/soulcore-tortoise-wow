# -*- coding: utf-8 -*-
"""部署 3 个 systemd unit 到游戏服并 enable 开机自启。"""
import socket, sys, base64, paramiko, os

HOST = 'soulcore.asia'
PORT = 56789
USER = 'administrator'
PASS = os.environ.get('SOULCORE_SSH_PASS','')
SUDO = os.environ.get('SOULCORE_SSH_PASS','')
TOOL_DIR = r"E:\11111\soulcore tortoise wow\工具"
FILES = ['pb-tunnel.service', 'pbrealmd.service', 'pbmangosd.service']


def get_sock():
    addrs = socket.getaddrinfo(HOST, PORT, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.connect(addrs[0][4])
    return s


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, port=PORT, username=USER, password=PASS,
              sock=get_sock(), timeout=30, banner_timeout=30)
    return c


def sh(c, cmd, timeout=120):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
    return stdout.read().decode('utf-8', 'replace'), stderr.read().decode('utf-8', 'replace')


c = connect()
try:
    for fn in FILES:
        with open(os.path.join(TOOL_DIR, fn), 'rb') as f:
            data = f.read()
        b64 = base64.b64encode(data).decode()
        out, err = sh(c, "echo '%s' | base64 -d > /home/administrator/%s && echo WROTE_%s" % (b64, fn, fn))
        print('[%s write] %s %s' % (fn, out.strip(), err.strip()))
        out2, err2 = sh(c, "echo '%s' | sudo -S mv /home/administrator/%s /etc/systemd/system/%s && echo MOVED_%s" % (SUDO, fn, fn, fn))
        print('[%s mv]   %s %s' % (fn, out2.strip(), err2.strip()))
    out, err = sh(c, "echo '%s' | sudo -S systemctl daemon-reload && echo RELOADED" % SUDO)
    print('[daemon-reload]', out.strip(), err.strip())
    out3, err3 = sh(c, "echo '%s' | sudo -S systemctl enable pb-tunnel pbrealmd pbmangosd && echo ENABLED" % SUDO)
    print('[enable]', out3.strip(), err3.strip())
    out4, err4 = sh(c, "echo '%s' | sudo -S systemctl is-enabled pb-tunnel pbrealmd pbmangosd" % SUDO)
    print('[is-enabled]', out4.strip(), err4.strip())
finally:
    c.close()
