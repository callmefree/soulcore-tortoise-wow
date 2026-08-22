# -*- coding: utf-8 -*-
"""本地端口转发：将本机 LOCAL_PORT 映射到游戏服务器的 127.0.0.1:3306 (MariaDB)。
用于本地开发时让注册页能真实连接 PB 账号库做端到端验证。
用法： python 工具/tunnel_3306.py [LOCAL_PORT]
"""
import os
import sys
import socket
import threading

import paramiko

HOST = os.environ.get("SOULCORE_HOST", "125.110.90.129")
PORT = int(os.environ.get("SOULCORE_PORT", "56789"))
USER = os.environ.get("SOULCORE_USER", "administrator")
PASS = os.environ.get("SOULCORE_SSH_PASS", "")
LOCAL_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 13306
REMOTE_HOST = "127.0.0.1"
REMOTE_PORT = 3306


def get_sock():
    addrs = socket.getaddrinfo(HOST, PORT, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.connect(addrs[0][4])
    return s


def forward(local: socket.socket, transport: paramiko.Transport, rhost: str, rport: int):
    try:
        remote = transport.open_channel("direct-tcpip", (rhost, rport), ("127.0.0.1", 0))
    except Exception:
        local.close()
        return

    def pump(a: socket.socket, b):
        try:
            while True:
                data = a.recv(65536)
                if not data:
                    break
                b.sendall(data)
        except Exception:
            pass
        for sock in (a, b):
            try:
                sock.close()
            except Exception:
                pass

    t1 = threading.Thread(target=pump, args=(local, remote), daemon=True)
    t2 = threading.Thread(target=pump, args=(remote, local), daemon=True)
    t1.start()
    t2.start()


def main():
    cli = paramiko.SSHClient()
    cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    cli.connect(HOST, port=PORT, username=USER, password=PASS, sock=get_sock(), timeout=30)
    transport = cli.get_transport()

    ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    ls.bind(("127.0.0.1", LOCAL_PORT))
    ls.listen(50)
    print(f"tunnel listening on 127.0.0.1:{LOCAL_PORT} -> {REMOTE_HOST}:{REMOTE_PORT}")
    sys.stdout.flush()

    while True:
        conn, _ = ls.accept()
        threading.Thread(
            target=forward, args=(conn, transport, REMOTE_HOST, REMOTE_PORT), daemon=True
        ).start()


if __name__ == "__main__":
    main()
