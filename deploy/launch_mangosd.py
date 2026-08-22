import paramiko, sys, socket, io, base64, time
import os

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))

SCRIPT = """#!/bin/bash
cd /opt/soulcore-pb/server/bin
/opt/soulcore-pb/server/bin/mangosd -c /opt/soulcore-pb/server/etc/mangosd.conf > /home/administrator/mangosd_start.log 2>&1
"""

def make_sock(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect((host, port))
    return s

def connect(p):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(p['host'], port=p['port'], username=p['user'], password=p['passwd'],
              sock=make_sock(p['host'], p['port']), timeout=30, banner_timeout=30)
    return c

def sh(c, cmd, timeout=60):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
    out = stdout.read().decode('utf-8', 'replace')
    err = stderr.read().decode('utf-8', 'replace')
    return out, err

def main():
    c = connect(GAME)
    b64 = base64.b64encode(SCRIPT.encode()).decode()
    out, err = sh(c, "echo %s | base64 -d > /home/administrator/start_mangosd.sh && chmod 755 /home/administrator/start_mangosd.sh && echo WROTE_OK" % b64)
    print('[write]', out.strip(), err.strip())
    if 'WROTE_OK' not in out:
        print('[ERR] script write failed'); c.close(); sys.exit(1)
    sh(c, "tmux kill-session -t pbmangosd 2>/dev/null; rm -f /home/administrator/mangosd_start.log")
    out2, err2 = sh(c, 'tmux new-session -d -s pbmangosd "/home/administrator/start_mangosd.sh" && echo TMUX_OK')
    print('[tmux]', out2.strip(), err2.strip())
    time.sleep(12)
    out3, _ = sh(c, "echo '=== start log (tail) ==='; tail -45 /home/administrator/mangosd_start.log 2>/dev/null; echo '=== 8091 ==='; (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep ':8091' || echo NOT_LISTENING; echo '=== proc ==='; pgrep -af mangosd | head")
    print('[result]')
    print(out3)
    c.close()

if __name__ == '__main__':
    main()
