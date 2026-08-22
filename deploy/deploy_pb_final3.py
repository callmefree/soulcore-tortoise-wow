# -*- coding: utf-8 -*-
"""deploy_pb_final3.py — 修正解包：zip 内是 tar.gz，需再解一层 tar。
直连取 Location、代理下 blob(已下载则复用)、python3 解 zip+tar.gz、替换并重启 PB。
不动生产 mangosd/realmd(8090/3724)。
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ssh_soulcore import connect

SCRIPT = r'''#!/bin/bash
LOG=/tmp/pb_deploy.log
exec > "$LOG" 2>&1
echo "[$(date +%T)] 启动 PB 部署(zip内是tar.gz,需两层解包)"
ART_ID=9171597591
PAT=__PAT__
PROXY=__PROXY__
REPO=callmefree/soulcore-tortoise-wow
BIN=/opt/soulcore-pb/server/bin
TMP=/tmp/pb_artifact
ZIP="$TMP/artifact.zip"
if [ -s "$ZIP" ] && [ "$(stat -c%s "$ZIP" 2>/dev/null||echo 0)" -gt 100000000 ]; then
  echo "[复用] 已有完整 artifact.zip ($(stat -c%s "$ZIP") bytes)，跳过下载"
else
  rm -rf "$TMP"; mkdir -p "$TMP"
  echo "[$(date +%T)] [1] 直连获取 artifact 重定向 Location(带auth)"
  LOC=$(curl -sS -m 60 -H "Authorization: Bearer $PAT" -D - -o /dev/null "https://api.github.com/repos/$REPO/actions/artifacts/$ART_ID/zip" | tr -d '\r' | awk -F': ' '/^[Ll]ocation:/{print $2}' | tail -1)
  echo "  Location=${LOC:0:80}..."
  if [ -z "$LOC" ]; then echo "!! 未取得 Location,中止"; exit 1; fi
  echo "[$(date +%T)] [2] 经代理下载 artifact"
  curl -sS -L -m 1200 -x "$PROXY" -o "$ZIP" "$LOC"
fi
ls -la "$ZIP"
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
restart_svc() {
  local pattern="$1" sess="$2" cmd="$3"
  echo "[$(date +%T)] [5] 重启 $sess"
  for p in $(pgrep -f "$pattern"); do echo "  kill -INT $p"; kill -INT "$p"; done
  for i in $(seq 1 12); do
    if pgrep -f "$pattern" >/dev/null; then sleep 5; else break; fi
  done
  if pgrep -f "$pattern" >/dev/null; then echo "  超时未退出,强制 KILL"; pkill -9 -f "$pattern"; sleep 3; fi
  tmux kill-session -t "$sess" 2>/dev/null; sleep 2
  tmux new-session -d -s "$sess" "$cmd"
}
restart_svc "soulcore-pb/server/etc/mangosd.conf" pbmangosd 'cd /opt/soulcore-pb/server/bin && ./mangosd -c /opt/soulcore-pb/server/etc/mangosd.conf'
sleep 10
restart_svc "soulcore-pb/server/etc/realmd.conf" pbrealmd 'cd /opt/soulcore-pb/server/bin && ./realmd -c /opt/soulcore-pb/server/etc/realmd.conf'
sleep 8
echo "[$(date +%T)] [6] 核对"
pgrep -af "soulcore-pb/server/etc/mangosd.conf" || echo "mangosd 未运行!"
pgrep -af "soulcore-pb/server/etc/realmd.conf" || echo "realmd 未运行!"
ss -ltn 2>/dev/null | grep -E ':8091|:3725' || echo "端口未监听"
echo "[$(date +%T)] DONE"
'''.replace("__PAT__", os.environ.get("GITHUB_PAT", "")).replace("__PROXY__", os.environ.get("SOULCORE_PROXY", ""))

def run(cmd, timeout=120):
    c = connect()
    try:
        stdin, stdout, stderr = c.exec_command(cmd, timeout=timeout, get_pty=True)
        return stdout.read().decode("utf-8", "replace")
    finally:
        c.close()

print("上传最终部署脚本(zip+tar双层解包)到服务器...", flush=True)
c = connect()
try:
    sftp = c.open_sftp()
    with sftp.open("/tmp/pb_deploy.sh", "w") as f:
        f.write(SCRIPT)
    sftp.chmod("/tmp/pb_deploy.sh", 0o755)
finally:
    sftp.close(); c.close()
print("OK 已上传 /tmp/pb_deploy.sh", flush=True)

print("setsid 后台启动(带 sleep 稳定)服务器部署...", flush=True)
print(run("setsid bash /tmp/pb_deploy.sh >/tmp/pb_deploy.log 2>&1 </dev/null & disown; sleep 4; echo launched"))

print("=== 轮询 /tmp/pb_deploy.log ===", flush=True)
deadline = time.time() + 1200
last = ""
while time.time() < deadline:
    time.sleep(15)
    out = run("tail -n 30 /tmp/pb_deploy.log")
    if out != last:
        print(out, flush=True)
        last = out
    if "DONE" in out or "中止" in out:
        print("=== 部署脚本结束 ===", flush=True)
        break
else:
    print("!! 轮询超时(1200s),最后日志:", flush=True)
    print(run("tail -n 40 /tmp/pb_deploy.log"), flush=True)

print("=== 最终完整日志 ===", flush=True)
print(run("cat /tmp/pb_deploy.log"))
