# -*- coding: utf-8 -*-
"""run_backup.py v2 — 用 SFTP 把备份脚本原样写到游戏服 /opt/run_backup.sh（绕开内联引号转义），
再以 setsid 后台启动，断点续传，日志 /opt/backup_to_fn.log。"""
import paramiko, sys, socket, base64
import os

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))

SCRIPT = r'''#!/bin/bash
export LC_ALL=C.UTF-8
BN="/vol1/1000/魔兽世界/1.18冷备"
RKEY="-i /home/administrator/.ssh/id_ed25519_fn -o StrictHostKeyChecking=no -p 22"
FN="__FNUSER__@192.168.1.2"
LOG=/home/administrator/backup_to_fn.log
echo "[$(date "+%F %T")] BACKUP START" >> "$LOG"
mkdir -p /tmp/bkstub/主服/db /tmp/bkstub/PB服/db
rsync -a -e "ssh $RKEY" /tmp/bkstub/ "$FN:$BN/" >> "$LOG" 2>&1
echo "[$(date "+%F %T")] stub dirs ready" >> "$LOG"
echo "[$(date "+%F %T")] MAIN rsync begin" >> "$LOG"
rsync -azL -e "ssh $RKEY" --stats /opt/soulcore/server/ "$FN:$BN/主服/" >> "$LOG" 2>&1 && echo "[$(date "+%F %T")] MAIN_OK" >> "$LOG" || echo "[$(date "+%F %T")] MAIN_FAIL rc=$?" >> "$LOG"
echo "[$(date "+%F %T")] PB rsync begin" >> "$LOG"
rsync -az -e "ssh $RKEY" --exclude=/data --stats /opt/soulcore-pb/server/ "$FN:$BN/PB服/" >> "$LOG" 2>&1 && echo "[$(date "+%F %T")] PB_OK" >> "$LOG" || echo "[$(date "+%F %T")] PB_FAIL rc=$?" >> "$LOG"
for db in tw_logon tw_world tw_char tw_logs; do
  mysqldump -uroot -p__DBPASS__ --single-transaction --routines --triggers "$db" | gzip | ssh $RKEY "$FN" "cat > \"$BN/主服/db/$db.sql.gz\""
  echo "[$(date "+%F %T")] dump MAIN $db rc=${PIPESTATUS[0]}" >> "$LOG"
done
for db in tw_pb_logon tw_pb_world tw_pb_char tw_pb_logs; do
  mysqldump -uroot -p__DBPASS__ --single-transaction --routines --triggers "$db" | gzip | ssh $RKEY "$FN" "cat > \"$BN/PB服/db/$db.sql.gz\""
  echo "[$(date "+%F %T")] dump PB $db rc=${PIPESTATUS[0]}" >> "$LOG"
done
echo "[$(date "+%F %T")] ALL_DONE" >> "$LOG"
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
    out = stdout.read().decode('utf-8', 'replace').strip()
    err = stderr.read().decode('utf-8', 'replace').strip()
    return out, err


def main():
    c = connect(GAME)
    # base64 写文件（绕过 SFTP 子系统与引号转义）
    b64 = base64.b64encode(SCRIPT.replace('__DBPASS__', os.environ.get('SOULCORE_DB_PASS', '')).replace('__FNUSER__', os.environ.get('SOULCORE_FN_USER', '')).encode('utf-8')).decode('ascii')
    out, err = sh(c, "echo %s | base64 -d > /home/administrator/run_backup.sh && chmod 755 /home/administrator/run_backup.sh && echo WROTE_OK" % b64)
    print('[write]', out, err)
    if 'WROTE_OK' not in out:
        print('[ERR] 脚本写文件失败'); c.close(); sys.exit(1)
    # 校验行数
    out2, _ = sh(c, "wc -l /home/administrator/run_backup.sh; head -3 /home/administrator/run_backup.sh")
    print('[verify]', out2.replace(chr(10), ' | '))
    # setsid 后台启动
    out3, err3 = sh(c, "setsid bash /home/administrator/run_backup.sh >/home/administrator/backup_to_fn.log 2>&1 </dev/null & echo LAUNCHED_PID=$!")
    print('[launch]', out3, err3)
    c.close()
    print('[ok] 已 setsid 后台启动，日志 /opt/backup_to_fn.log')


if __name__ == '__main__':
    main()
