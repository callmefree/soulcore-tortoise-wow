# -*- coding: utf-8 -*-
"""
ssh_soulcore.py — SoulCore Ubuntu 服务器运维工具（paramiko，强制 IPv4）
用法：
  python ssh_soulcore.py <远程命令字符串>     # 执行单条命令（bash -lc）
  python ssh_soulcore.py --mysql <sql文件>   # 通过 stdin 执行 SQL 到 tw_world
  python ssh_soulcore.py --mysql-char <sql文件>
  python ssh_soulcore.py --mysql-all <sql文件>  # 逐库判断（文件内 USE 语句优先）
"""
import socket
import sys
import os
import paramiko

HOST = os.environ.get('SOULCORE_HOST', 'soulcore.asia')  # 强制 IPv4；域名解析随拨号变IP，避免硬编码失效
PORT = int(os.environ.get('SOULCORE_PORT', '56789'))
USER = os.environ.get('SOULCORE_USER', 'administrator')
PASS = os.environ.get('SOULCORE_SSH_PASS', '')
DBPASS = os.environ.get('SOULCORE_DB_PASS', '')


def get_sock():
    # 强制 IPv4 地址族
    addrs = socket.getaddrinfo(HOST, PORT, socket.AF_INET, socket.SOCK_STREAM)
    s = socket.socket(addrs[0][0], addrs[0][1], addrs[0][2])
    s.connect(addrs[0][4])
    return s


def connect():
    cli = paramiko.SSHClient()
    cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    cli.connect(HOST, port=PORT, username=USER, password=PASS,
                sock=get_sock(), timeout=30, banner_timeout=30)
    return cli


def run_cmd(cmd, timeout=120):
    cli = connect()
    try:
        stdin, stdout, stderr = cli.exec_command(cmd, timeout=timeout, get_pty=True)
        out = stdout.read().decode('utf-8', errors='replace')
        err = stderr.read().decode('utf-8', errors='replace')
        print('--- STDOUT ---')
        print(out)
        if err.strip():
            print('--- STDERR ---')
            print(err)
    finally:
        cli.close()


def run_mysql(sql_path, db='tw_world'):
    with open(sql_path, 'r', encoding='utf-8') as f:
        sql = f.read()
    cli = connect()
    try:
        # 上传到远端临时文件再导入，避免 stdin 编码问题
        sftp = cli.open_sftp()
        remote = '/tmp/import.sql'
        with sftp.open(remote, 'w') as rf:
            rf.write(sql)
        sftp.close()
        # root 直连 127.0.0.1（MariaDB 本地监听，无需 sudo）
        cmd = "mysql -uroot -p%s --default-character-set=utf8 %s < %s; RC=$?; rm -f %s; exit $RC" % (DBPASS, db, remote, remote)
        stdin, stdout, stderr = cli.exec_command(cmd, timeout=600, get_pty=True)
        out = stdout.read().decode('utf-8', errors='replace')
        err = stderr.read().decode('utf-8', errors='replace')
        print('--- STDOUT ---')
        print(out)
        if err.strip():
            print('--- STDERR ---')
            print(err)
    finally:
        cli.close()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == '--put':
        local = sys.argv[2]
        remote = sys.argv[3] if len(sys.argv) > 3 else (
            '/opt/soulcore-pb/server/bin/lua_scripts/' + os.path.basename(local))
        cli = connect()
        try:
            sftp = cli.open_sftp()
            sftp.put(local, remote)
            sftp.close()
            print('put %s -> %s' % (local, remote))
        finally:
            cli.close()
    elif sys.argv[1] == '--mysql':
        run_mysql(sys.argv[2], db='tw_world')
    elif sys.argv[1] == '--mysql-char':
        run_mysql(sys.argv[2], db='tw_char')
    elif sys.argv[1] == '--mysql-all':
        run_mysql(sys.argv[2], db='')  # 依赖文件内 USE
    else:
        run_cmd(' '.join(sys.argv[1:]))
