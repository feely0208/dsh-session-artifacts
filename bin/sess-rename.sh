#!/bin/bash
# sess-rename.sh — 按会话**实际内容**重命名会话文件夹
#
# 为什么需要它：
#   会话开干时你我都忙着干活，没空想名字；而且一个会话常有多个主题。
#   等收尾或交接时再回头看文件夹名（当时随手起的关键词），
#   已经想不起来里面到底是什么了。
#
#   解决：**两段式命名** —— 开干时用临时名，收尾时由 AI 回顾整个会话的实际内容，
#   用本脚本改名。名字反映的是"真的做了什么"，不是"当时猜的"。
#
# 用法：
#   bash sess-rename.sh --list                      # 列出所有会话文件夹（含日期/体积/内容提示）
#   bash sess-rename.sh --apply <旧名或路径> <新主题>   # 改名
#   bash sess-rename.sh --apply <旧名> <新主题> --dry   # 只看会改成什么
#
# 新主题里不要带日期 —— 脚本自动保留原日期前缀（日期是"会话发生的时间"，不该被改名弄丢）。

set -uo pipefail

ROOT="${SESS_ROOT:-$HOME/会话产物}"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# —— 列出 ——
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  [ -d "$ROOT" ] || { echo "（还没有会话产物目录：$ROOT）"; exit 0; }
  echo "== 会话产物 =="
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    b=$(basename "$d")
    [ "$b" = "_归档" ] && continue
    sz=$(du -sh "$d" 2>/dev/null | cut -f1)
    n=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    # 内容提示：README 首行标题（> 之后的第一行正文）或前几个文件名
    hint=""
    if [ -f "$d/README.md" ]; then
      # 优先取 `>` 摘要行（约定：README 用引用块写一句话摘要）
      hint=$(grep -m1 '^>' "$d/README.md" 2>/dev/null | sed 's/^> *//')
      # 退而求其次：第一条正文
      [ -z "$hint" ] && hint=$(grep -vE '^#|^$|^>' "$d/README.md" 2>/dev/null | head -1)
      hint=$(printf '%s' "$hint" | cut -c1-40)
    fi
    [ -z "$hint" ] && hint=$(find "$d" -maxdepth 1 -type f 2>/dev/null | head -3 | xargs -n1 basename 2>/dev/null | tr '\n' ' ' | cut -c1-40)
    printf "  %-40s %6s %4s 个文件  %s\n" "$b" "$sz" "$n" "$hint"
  done
  exit 0
fi

# —— 改名 ——
if [ "${1:-}" = "--apply" ]; then
  OLD="${2:?--apply 需要 <旧名或路径>}"
  NEW_TOPIC="${3:?--apply 需要 <新主题>}"
  DRY=0
  [ "${4:-}" = "--dry" ] && DRY=1

  # 解析旧路径：支持「完整路径」「目录名」「目录名的一部分」
  if [ -d "$OLD" ]; then
    OLDP="$OLD"
  elif [ -d "$ROOT/$OLD" ]; then
    OLDP="$ROOT/$OLD"
  else
    # 模糊匹配（唯一命中才认）
    hits=()
    for d in "$ROOT"/*/; do
      [ -d "$d" ] || continue
      case "$(basename "$d")" in *"$OLD"*) hits+=("$d") ;; esac
    done
    if [ "${#hits[@]}" -eq 1 ]; then OLDP="${hits[0]}"
    elif [ "${#hits[@]}" -eq 0 ]; then echo "❌ 找不到会话文件夹: $OLD" >&2; exit 1
    else echo "❌ 匹配到多个，请给更精确的名字：" >&2; printf '   %s\n' "${hits[@]}" >&2; exit 1
    fi
  fi

  BASE=$(basename "$OLDP"); DIR=$(dirname "$OLDP")
  # 保留原日期前缀（YYYY-MM-DD[-N]），只换后面的主题
  if [[ "$BASE" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?)-(.*)$ ]]; then
    PREFIX="${BASH_REMATCH[1]}"; OLDTHEME="${BASH_REMATCH[3]}"
  else
    PREFIX="$(date +%Y-%m-%d)"; OLDTHEME="$BASE"
  fi

  SAFE=$(printf '%s' "$NEW_TOPIC" | tr -d ' /\\' | tr -s ' ')
  [ -n "$SAFE" ] || { echo "❌ 新主题为空" >&2; exit 1; }
  NEWP="$DIR/$PREFIX-$SAFE"

  echo "  旧: $(basename "$OLDP")"
  echo "  新: $(basename "$NEWP")"
  if [ "$OLDP" = "$NEWP" ]; then echo "  （名字没变）"; exit 0; fi
  if [ -e "$NEWP" ]; then echo "❌ 目标已存在: $NEWP" >&2; exit 1; fi
  [ "$DRY" = "1" ] && { echo "  （--dry：未改名）"; exit 0; }

  mv -- "$OLDP" "$NEWP" && echo "  ✅ 已改名" && echo "$NEWP"
  exit 0
fi

usage 0
