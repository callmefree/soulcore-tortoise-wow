#!/bin/bash
# analyze_core.sh — 机器人服崩溃 core 分析（先提 backtrace，再决定是否删大 core）
# 服务器侧使用：bash analyze_core.sh <core文件>
# 依赖：/usr/bin/gdb（Ubuntu 已装 12.1）、/opt/soulcore-pb/server/bin/mangosd
# 用法示例：
#   bash analyze_core.sh /opt/soulcore-pb/core-70599-World
# 效果：把调用栈 + 内存映射提取成 <core>.backtrace.txt（小文件），
#        之后即可安全 rm 掉几 GB 的大 core，诊断信息不丢。

set -u
CORE="${1:-}"
if [ -z "$CORE" ]; then
  echo "用法: $0 <core文件>  例: $0 /opt/soulcore-pb/core-70599-World"
  exit 1
fi
if [ ! -f "$CORE" ]; then
  echo "找不到 core 文件: $CORE"
  exit 1
fi

BIN=/opt/soulcore-pb/server/bin/mangosd
OUT="${CORE}.backtrace.txt"

echo ">>> [1/2] gdb 提取 backtrace + 内存映射 -> $OUT"
gdb -batch \
    -ex "set pagination off" \
    -ex "bt" \
    -ex "bt full" \
    -ex "info proc mappings" \
    -ex "info threads" \
    "$BIN" "$CORE" > "$OUT" 2>&1

echo ">>> [2/2] 完成。backtrace 大小: $(du -h "$OUT" | cut -f1)"
echo ">>> 诊断信息已保留，现在可安全删除大 core:"
echo "        rm -f '$CORE'"
echo ">>> 查看 backtrace: less '$OUT'"
