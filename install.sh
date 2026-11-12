#!/usr/bin/env bash
# shell-history-logger 安装脚本（Linux / macOS / WSL / Git-Bash）
#
# 用法:
#   bash install.sh                 按当前 shell 自动安装
#   bash install.sh bash|zsh|fish   指定 shell
#
# 原理: 在对应 rc 文件末尾追加 source 行（带标记块，幂等可重跑）。
# 日志文件默认 ~/.history，可用 APPEND_HIST_FILE 覆盖。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(basename "${SHELL:-/bin/bash}")}"
MARK_BEGIN="# >>> shell-history-logger >>>"
MARK_END="# <<< shell-history-logger <<<"

case "$TARGET" in
  bash)
    RC="$HOME/.bashrc"
    SNIPPET="$REPO_DIR/bash/append-history.bash"
    SOURCE_LINE="source $SNIPPET"
    ;;
  zsh)
    RC="$HOME/.zshrc"
    SNIPPET="$REPO_DIR/zsh/append-history.zsh"
    SOURCE_LINE="source $SNIPPET"
    ;;
  fish)
    RC="$HOME/.config/fish/config.fish"
    SNIPPET="$REPO_DIR/fish/append-history.fish"
    SOURCE_LINE="source $SNIPPET"
    ;;
  *)
    echo "不支持的 shell: $TARGET（支持 bash/zsh/fish）" >&2
    exit 1
    ;;
esac

[ -f "$SNIPPET" ] || { echo "找不到片段文件: $SNIPPET" >&2; exit 1; }
mkdir -p "$(dirname "$RC")"

if grep -qF "$MARK_BEGIN" "$RC" 2>/dev/null; then
  echo "已安装（$RC 已包含 shell-history-logger），跳过。"
  exit 0
fi

{
  echo ""
  echo "$MARK_BEGIN"
  echo "# 将每条命令追加记录到日志（默认 ~/.history），不影响 shell 自身历史"
  echo "$SOURCE_LINE"
  echo "$MARK_END"
} >> "$RC"

echo "已追加到 $RC："
sed -n "/$MARK_BEGIN/,/$MARK_END/p" "$RC" | cat -n
echo ""
echo "完成。重新打开终端（或 source $RC）后生效。"
echo "日志默认写入 ~/.history；可用环境变量 APPEND_HIST_FILE 改路径。"
