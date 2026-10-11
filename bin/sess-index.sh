#!/bin/bash
# sess-index.sh — 生成/刷新会话产物索引 ~/会话产物/INDEX.md
#
# 为什么需要它：
#   文件夹名再准也只能概括主线（一个会话常有多个主题）。过一两个月回来，
#   光看名字还是可能有"这个到底做了什么"的空档。索引把每个会话的
#   **日期 / 名字 / 体积 / README 里的摘要** 汇到一页，一眼扫完。
#
# 用法：
#   bash sess-index.sh            # 刷新 INDEX.md
#   bash sess-index.sh --print    # 只打印，不写盘
#
# 依赖约定：每个会话文件夹里的 README.md 第二段（`>` 引用块）写一句话摘要。
# 没有 README 的会话会在索引里标 `（无 README）`，提醒补上。

set -uo pipefail

ROOT="${SESS_ROOT:-$HOME/会话产物}"
OUT="$ROOT/INDEX.md"
PRINT_ONLY=0
[ "${1:-}" = "--print" ] && PRINT_ONLY=1

[ -d "$ROOT" ] || { echo "（还没有会话产物目录：$ROOT）"; exit 0; }

tmp=$(mktemp)
{
  echo "# 会话产物索引"
  echo
  echo "> 由 \`sess-index.sh\` 自动生成，**不要手改**（改完下次刷新会被覆盖）。"
  echo "> 生成时间：$(date '+%Y-%m-%d %H:%M')"
  echo
  echo "| 日期 | 会话 | 体积 | 文件 | 摘要 |"
  echo "|---|---|---|---|---|"

  # 目录名形如 2026-10-11-主题，按日期倒序
  for d in $(ls -1d "$ROOT"/*/ 2>/dev/null | sort -r); do
    b=$(basename "$d")
    [ "$b" = "_归档" ] && continue
    [ -d "$d" ] || continue

    if [[ "$b" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.*)$ ]]; then
      date="${BASH_REMATCH[1]}"; theme="${BASH_REMATCH[2]}"
    else
      date="—"; theme="$b"
    fi

    sz=$(du -sh "$d" 2>/dev/null | cut -f1)
    n=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')

    # 摘要：README 里第一个 `>` 引用块的内容；没有就标出来
    sum=""
    if [ -f "$d/README.md" ]; then
      sum=$(grep -m1 '^>' "$d/README.md" 2>/dev/null | sed 's/^> *//' | cut -c1-56)
      [ -z "$sum" ] && sum=$(grep -vE '^#|^$|^>' "$d/README.md" 2>/dev/null | head -1 | cut -c1-56)
    fi
    [ -z "$sum" ] && sum="（无 README，建议补）"

    # 表格里的 | 会破坏列，替换掉
    theme=${theme//|/／}; sum=${sum//|/／}
    printf "| %s | %s | %s | %s | %s |\n" "$date" "$theme" "$sz" "$n" "$sum"
  done

  echo
  echo "---"
  echo
  echo "## 怎么用"
  echo
  echo '```bash'
  echo '# 建（会话首次存东西时）'
  echo 'DIR=$(bash ~/.dsh/skills/session-artifacts/sess.sh <主题简称>)'
  echo
  echo '# 收尾时按实际内容改名（AI 回顾会话后决定新名字）'
  echo 'bash ~/.dsh/skills/session-artifacts/sess-rename.sh --apply <旧名> <准确主题>'
  echo
  echo '# 列出现有会话 / 刷新本索引'
  echo 'bash ~/.dsh/skills/session-artifacts/sess-rename.sh --list'
  echo 'bash ~/.dsh/skills/session-artifacts/sess-index.sh'
  echo '```'
} > "$tmp"

if [ "$PRINT_ONLY" = "1" ]; then
  cat "$tmp"; rm -f "$tmp"; exit 0
fi
mv "$tmp" "$OUT"
echo "  ✅ 已刷新 $OUT"
echo "  会话数: $(grep -c '^| 20' "$OUT" 2>/dev/null || echo 0)"
