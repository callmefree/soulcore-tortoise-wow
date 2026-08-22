# -*- coding: utf-8 -*-
"""setup_fn_key.py — 在游戏服(administrator)生成 ed25519 key，并把公钥塞进 FN NAS(<FN用户>，见环境变量) 的 authorized_keys，
使得游戏服可免密 rsync/scp 到 FN NAS(192.168.1.2:2222)。仅建通道，不做传输。"""
import paramiko, sys, socket
import os

GAME = dict(host='soulcore.asia', port=56789, user='administrator', passwd=os.environ.get('SOULCORE_SSH_PASS',''))
FN = dict(host='soulcore.asia', port=2222, user=os.environ.get('SOULCORE_FN_USER',''), passwd=os.environ.get('SOULCORE_FN_PASS',''))  # 公网入口；游戏服侧实际走 192.168.1.2 局域网
KEY_PATH = '/home/administrator/.ssh/id_ed25519_fn'


def make_sock(host, port):
    # 强制 IPv4（soulcore.asia 可能解析出 IPv6 导致 paramiko 卡死）
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


def connect(p):
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(p['host'], port=p['port'], username=p['user'], password=p['passwd'],
              sock=make_sock(p['host'], p['port']), timeout=30, banner_timeout=30)
    return c


def main():
    # 1) 游戏服：确保 .ssh，生成 key（若不存在）
    g = connect(GAME)
    sh(g, 'mkdir -p /home/administrator/.ssh && chmod 700 /home/administrator/.ssh')
    o, e = sh(g, 'test -f %s.pub || ssh-keygen -t ed25519 -f %s -N "" -q' % (KEY_PATH, KEY_PATH))
    pub, _ = sh(g, 'cat %s.pub' % KEY_PATH)
    pub = pub.strip()
    print('[game] pubkey:', pub[:60], '...' if len(pub) > 60 else '')
    if not pub:
        print('[ERR] 无法读取游戏服公钥'); sys.exit(1)

    # 2) FN NAS（公网入口）：确保 .ssh，去重追加公钥（用 $HOME 兼容 FNOS 家目录）
    f = connect(FN)
    home, _ = sh(f, 'echo $HOME')
    home = home.strip()
    ak_path = home + '/.ssh/authorized_keys'
    sh(f, 'mkdir -p %s/.ssh && chmod 700 %s/.ssh' % (home, home))
    ak, _ = sh(f, 'cat %s 2>/dev/null' % ak_path)
    if pub not in ak:
        sh(f, "echo '%s' >> %s" % (pub, ak_path))
        sh(f, 'chmod 600 %s' % ak_path)
        print('[fn] 公钥已追加 (%s)' % ak_path)
    else:
        print('[fn] 公钥已存在，跳过')
    f.close(); g.close()

    # 3) 测试：游戏服用 key 免密连 FN NAS
    test = ("ssh -i %s -o StrictHostKeyChecking=no -o BatchMode=yes -p 2222 %s@192.168.1.2 "
            "'echo FN_REACH_OK; mkdir -p \"/vol1/1000/魔兽世界/1.18冷备\"; df -h /vol1 | tail -1'") % (KEY_PATH, FN['user'])
    g2 = connect(GAME)
    o, e = sh(g2, test, timeout=40)
    print('--- test output ---')
    print(o)
    if e.strip(): print('--- test err ---\n' + e)
    g2.close()
    print('FN_REACH_OK' in o and 'OK' or 'DONE')

if __name__ == '__main__':
    main()
