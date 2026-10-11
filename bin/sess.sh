#!/bin/bash
# sess.sh — 会话产物文件夹的建 / 查 / 清
#
# 配合 session-artifacts skill 使用。目的：让「建会话专属文件夹」变成一条命令，
# 而不是每次靠人记着写 date + 拼路径（记不住就不会做，做了也会写错）。
#
# 用法：
#   DIR=$(bash sess.sh 律师端辉光)        # 建（或复用今天的）并打印绝对路径
#   bash sess.sh --list                   # 列出所有会话文件夹
#   bash sess.sh --size                   # 各文件夹体积，按大到小
#   bash sess.sh --path 律师端辉光        # 只打印路径，不创建
#
# 约定（详见 SKILL.md）：临时产物只往这个目录写；交付物移走之后，整个目录可删。

set -uo pipefail

ROOT="${SESS_ROOT:-$HOME/会话产物}"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# —— 参数解析 ——
case "${1:-}" in
  ""|-h|--help) usage 0 ;;
  --list)
    [ -d "$ROOT" ] || { echo "（还没有会话产物目录：$ROOT）"; exit 0; }
    ls -1 "$ROOT" | grep -v '^_归档$' | sed 's/^/  /'
    exit 0 ;;
  --size)
    [ -d "$ROOT" ] || { echo "（还没有会话产物目录：$ROOT）"; exit 0; }
    du -sh "$ROOT"/* 2>/dev/null | sort -rh | sed 's/^/  /'
    echo "  ── 合计 $(du -sh "$ROOT" 2>/dev/null | cut -f1)"
    exit 0 ;;
  --path)
    TOPIC="${2:?--path 需要一个主题名}"
    echo "$ROOT/$(date +%Y-%m-%d)-$TOPIC"
    exit 0 ;;
  --*) usage 1 ;;
esac

TOPIC="$*"

# —— 主题名清洗：去掉空格与路径分隔符，避免拼出意外路径 ——
SAFE=$(printf '%s' "$TOPIC" | tr -d ' /\\' | tr -s ' ')
[ -n "$SAFE" ] || { echo "❌ 主题名为空" >&2; exit 1; }

BASE="$ROOT/$(date +%Y-%m-%d)-$SAFE"

mkdir -p "$ROOT"

# 同一天同主题重复调用 → 复用同一个文件夹（幂等：脚本被调用多次不该产生一堆目录）
# 同名但属于「另一个会话」时，加 -2 / -3 …（用 --new 强制新开一个）
if [ "${SESS_NEW:-}" = "1" ]; then
  DIR="$BASE"; i=2
  while [ -e "$DIR" ]; do DIR="$BASE-$i"; i=$((i+1)); done
  mkdir -p "$DIR"
else
  DIR="$BASE"
  mkdir -p "$DIR"
fi

echo "$DIR"
