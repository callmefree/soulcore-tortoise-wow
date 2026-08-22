# -*- coding: utf-8 -*-
"""pb_deploy_exec.py — 服务器端完整部署：解 zip→tar.gz→替换→systemd重启
一次性执行，输出全程日志。
"""
import sys, time
sys.path.insert(0, r"E:\11111\soulcore tortoise wow\工具")
from ssh_soulcore import connect

SCRIPT = r'''#!/bin/bash
set -u
BIN=/opt/soulcore-pb/server/bin
cd "$BIN" || exit 1
echo "[$(date +%T)] === 部署开始 ==="
# 1) 解 zip -> tar.gz
rm -rf /tmp/pbd; mkdir -p /tmp/pbd
python3 -c "import zipfile; zipfile.ZipFile('$BIN/soulcore-pb-linux.zip').extractall('/tmp/pbd')" || { echo "!! zip 解压失败"; exit 1; }
echo "[$(date +%T)] zip 解出:"; ls -la /tmp/pbd
# 2) 解 tar.gz -> 二进制
TGZ=$(find /tmp/pbd -name '*.tar.gz' | head -1)
[ -n "$TGZ" ] || { echo "!! 未找到 tar.gz"; exit 1; }
echo "[$(date +%T)] 解 tar.gz: ${TGZ##*/}"
(cd /tmp/pbd && python3 -c "import tarfile,sys; tarfile.open(sys.argv[1]).extractall('.')" "$TGZ") || { echo "!! tar 解压失败"; exit 1; }
echo "[$(date +%T)] 解出的二进制:"
find /tmp/pbd -type f \( -name mangosd -o -name realmd \) -exec stat -c "%n %s" {} \;
BINNEW=$(find /tmp/pbd -type f -name mangosd | head -1)
REALNEW=$(find /tmp/pbd -type f -name realmd | head -1)
[ -n "$BINNEW" ] && [ -n "$REALNEW" ] || { echo "!! 未找到 mangosd/realmd"; exit 1; }
# 3) 备份 + 替换
TS=$(date +%Y%m%d-%H%M%S)
for pair in "mangosd:$BINNEW" "realmd:$REALNEW"; do
  b="${pair%%:*}"; src="${pair#*:}"
  cp -f "$BIN/$b" "$BIN/$b.bak-$TS" 2>/dev/null && echo "备份 $b -> $b.bak-$TS" || echo "（无旧版，跳过备份 $b）"
  cp -f "$src" "$BIN/$b"
  chmod 755 "$BIN/$b"
  echo "替换 $b: $(stat -c%s "$BIN/$b") bytes"
done
echo "$TS" > /tmp/pb_ts
echo "[$(date +%T)] === 二进制就绪，准备重启 ==="
'''

def run(cmd, timeout=120):
    c = connect()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
        return stdout.read().decode("utf-8", "replace") + stderr.read().decode("utf-8", "replace")
    finally:
        c.close()

print("上传部署脚本...", flush=True)
c = connect()
try:
    sftp = c.open_sftp()
    with sftp.open("/tmp/pb_exec.sh", "w") as f:
        f.write(SCRIPT)
    sftp.chmod("/tmp/pb_exec.sh", 0o755)
finally:
    sftp.close(); c.close()
print("=== 执行（解压+替换） ===", flush=True)
out = run("bash /tmp/pb_exec.sh 2>&1", timeout=180)
print(out)
if "=== 二进制就绪" not in out:
    print("!! 准备阶段未完成，不重启", flush=True)
    sys.exit(1)

print("=== systemd 重启 PB 服务 ===", flush=True)
out2 = run("systemctl restart pbrealmd; sleep 3; systemctl restart pbmangosd; sleep 15; systemctl is-active pbmangosd pbrealmd pb-tunnel; echo ---PORTS---; ss -ltn | grep -E ':8091|:3725' || echo NO_PORTS; echo ---PROC---; pgrep -af 'soulcore-pb/server/etc' | head", timeout=120)
print(out2)
print("=== DONE ===", flush=True)
