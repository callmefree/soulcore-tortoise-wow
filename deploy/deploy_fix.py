import paramiko, sys, socket, io, base64
import os

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))
SUDO = os.environ.get('SOULCORE_SSH_PASS','')

def make_sock():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(30)
    s.connect((GAME['host'], GAME['port']))
    return s

def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(GAME['host'], port=GAME['port'], username=GAME['user'],
              password=GAME['passwd'], timeout=30, banner_timeout=30, sock=make_sock())
    return c

def sh(c, cmd, timeout=120):
    stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
    out = stdout.read().decode('utf-8', 'replace')
    err = stderr.read().decode('utf-8', 'replace')
    return out, err

UNITS = {
    'pbmangosd.service': r'''[Unit]
Description=PB WoW mangosd (world server)
After=network-online.target pbrealmd.service
Wants=network-online.target

[Service]
Type=simple
User=administrator
WorkingDirectory=/opt/soulcore-pb/server/bin
ExecStart=/opt/soulcore-pb/server/bin/mangosd -c /opt/soulcore-pb/server/etc/mangosd.conf
# tty-force 分配伪终端，避免 stdin EOF 导致 mangosd 优雅 halt（systemd 默认 stdin=/dev/null）
StandardInput=tty-force
TTYReset=yes
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
''',
    'pbrealmd.service': r'''[Unit]
Description=PB WoW realmd (auth server)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=administrator
WorkingDirectory=/opt/soulcore-pb/server/bin
ExecStart=/opt/soulcore-pb/server/bin/realmd -c /opt/soulcore-pb/server/etc/realmd.conf
# tty-force 分配伪终端，防止 stdin EOF 让控制台程序自行退出（与 mangosd 同源风险）
StandardInput=tty-force
TTYReset=yes
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
''',
}

def main():
    c = connect()
    for name, content in UNITS.items():
        b64 = base64.b64encode(content.encode('utf-8')).decode('ascii')
        # 写家目录，sudo mv 到 systemd 目录，再 chown root
        out, err = sh(c, "echo %s | base64 -d > /home/administrator/%s && echo WROTE_%s" % (b64, name, name))
        print('[write %s]' % name, out.strip(), err.strip())
        out2, err2 = sh(c, "echo '%s' | sudo -S mv -f /home/administrator/%s /etc/systemd/system/%s && sudo chown root:root /etc/systemd/system/%s && echo MOVED_%s" % (SUDO, name, name, name, name))
        print('[mv %s]' % name, out2.strip(), err2.strip())
    out3, err3 = sh(c, "echo '%s' | sudo -S systemctl daemon-reload && echo RELOADED" % SUDO)
    print('[daemon-reload]', out3.strip(), err3.strip())
    print('[done] unit files redeployed')
    c.close()

if __name__ == '__main__':
    main()
