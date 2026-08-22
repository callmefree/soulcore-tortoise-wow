# -*- coding: utf-8 -*-
"""deploy_pb_ci.py — CI 产物部署到 PB 服（systemd 版）
服务器端直连取 GitHub artifact Location、经代理下载 blob、
python3 解 zip+tar.gz、替换 /opt/soulcore-pb/server/bin/{mangosd,realmd}、
systemctl restart pbmangosd/pbrealmd。
不涉及主服生产(8090/3724)与随机附魔 DBC。
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ssh_soulcore import connect

ART_ID = "9354039592"
GIT_SHA = "ebc2fda"

SCRIPT = r'''#!/bin/bash
set -u
LOG=/tmp/pb_ci_deploy.log
exec > "$LOG" 2>&1
echo "[$(date +%T)] 启动 PB CI 部署 (systemd)"
ART_ID=__ART__
PAT=__PAT__
PROXY=__PROXY__
REPO=callmefree/soulcore-tortoise-wow
BIN=/opt/soulcore-pb/server/bin
TMP=/tmp/pb_ci_artifact
ZIP="$TMP/artifact.zip"
rm -rf "$TMP"; mkdir -p "$TMP"

echo "[$(date +%T)] [1] 直连获取 artifact 重定向 Location(带auth)"
LOC=$(curl -sS -m 60 -H "Authorization: Bearer $PAT" -D - -o /dev/null "https://api.github.com/repos/$REPO/actions/artifacts/$ART_ID/zip" | tr -d '\r' | awk -F': ' '/^[Ll]ocation:/{print $2}' | tail -1)
echo "  Location=${LOC:0:80}..."
if [ -z "$LOC" ]; then echo "!! 未取得 Location,中止"; exit 1; fi

echo "[$(date +%T)] [2] 经代理下载 artifact"
curl -sS -L -m 600 -x "$PROXY" -o "$ZIP" "$LOC"
sz=$(stat -c%s "$ZIP" 2>/dev/null || echo 0)
echo "  artifact.zip size=$sz"
if [ "$sz" -lt 30000000 ]; then echo "!! 下载异常(过小),中止"; exit 1; fi

echo "[$(date +%T)] [3] 解包(zip -> tar.gz -> 文件, python3)"
cd "$TMP" && python3 -c "import zipfile; zipfile.ZipFile('artifact.zip').extractall('extracted')"
TGZ=$(find "$TMP/extracted" -name "*.tar.gz" | head -1)
echo "  tar.gz: ${TGZ##*/}"
cd "$TMP/extracted" && python3 -c "import tarfile,sys; tarfile.open(sys.argv[1]).extractall('.')" "$TGZ"
echo "  解压出的二进制:"; find "$TMP/extracted" \( -name mangosd -o -name realmd \) | head

echo "[$(date +%T)] [4] 备份并替换二进制"
TS=$(date +%Y%m%d-%H%M%S)
for b in mangosd realmd; do
  f=$(find "$TMP/extracted" -name "$b" -type f | head -1)
  echo "  找到 $b: $f"
  if [ -z "$f" ]; then echo "!! 未找到 $b,中止"; exit 1; fi
  cp -f "$BIN/$b" "$BIN/$b.bak-$TS" 2>/dev/null || true
  cp -f "$f" "$BIN/$b"
  chmod 755 "$BIN/$b"
  echo "  已替换 $b ($(stat -c%s "$BIN/$b") bytes)"
done

echo "[$(date +%T)] [5] systemd 重启 PB 服务"
systemctl restart pbrealmd 2>&1; sleep 3
systemctl restart pbmangosd 2>&1
sleep 15
echo "[$(date +%T)] [6] 核对"
systemctl is-active pbmangosd pbrealmd pb-tunnel
pgrep -af "soulcore-pb/server/etc/mangosd.conf" || echo "mangosd 未运行!"
pgrep -af "soulcore-pb/server/etc/realmd.conf" || echo "realmd 未运行!"
ss -ltn 2>/dev/null | grep -E ':8091|:3725' || echo "端口未监听"
echo "[$(date +%T)] DONE"
'''.replace("__ART__", ART_ID).replace("__PAT__", os.environ.get("GITHUB_PAT", "")).replace("__PROXY__", os.environ.get("SOULCORE_PROXY", ""))


def run(cmd, timeout=120):
    c = connect()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
        return stdout.read().decode("utf-8", "replace")
    finally:
        c.close()


print("上传 CI 部署脚本到服务器...", flush=True)
c = connect()
try:
    sftp = c.open_sftp()
    with sftp.open("/tmp/pb_ci_deploy.sh", "w") as f:
        f.write(SCRIPT)
    sftp.chmod("/tmp/pb_ci_deploy.sh", 0o755)
finally:
    sftp.close(); c.close()
print("OK 已上传 /tmp/pb_ci_deploy.sh", flush=True)

print("setsid 后台启动服务器部署...", flush=True)
print(run("setsid bash /tmp/pb_ci_deploy.sh >/tmp/pb_ci_deploy.log 2>&1 </dev/null & disown; sleep 4; echo launched"))

print("=== 轮询 /tmp/pb_ci_deploy.log ===", flush=True)
deadline = time.time() + 900
last = ""
while time.time() < deadline:
    time.sleep(15)
    out = run("tail -n 30 /tmp/pb_ci_deploy.log")
    if out != last:
        print(out, flush=True)
        last = out
    if "DONE" in out or "中止" in out:
        print("=== 部署脚本结束 ===", flush=True)
        break
else:
    print("!! 轮询超时(900s),最后日志:", flush=True)
    print(run("tail -n 40 /tmp/pb_ci_deploy.log"), flush=True)

print("=== 最终完整日志 ===", flush=True)
print(run("cat /tmp/pb_ci_deploy.log"))
