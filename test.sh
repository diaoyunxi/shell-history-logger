#!/usr/bin/env bash
# shell-history-logger 自测脚本：在临时 HOME 里模拟安装并验证追加行为。
# 用法: bash test.sh [bash|zsh|fish]

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
TARGET="${1:-bash}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

case "$TARGET" in
  bash) SHELL_BIN="$(command -v bash || echo /bin/bash)"
        SNIPPET="bash/append-history.bash";;
  zsh)  SHELL_BIN="$(command -v zsh  || true)"
        SNIPPET="zsh/append-history.zsh";;
  fish) SHELL_BIN="$(command -v fish || true)"
        SNIPPET="fish/append-history.fish";;
  *) echo "不支持: $TARGET" >&2; exit 1;;
esac

[ -n "$SHELL_BIN" ] || { echo "未找到 $TARGET，跳过" >&2; exit 0; }

export HOME="$TMP"
HIST="$TMP/.history"
[ -f "$SNIPPET" ] || { echo "缺少 $SNIPPET" >&2; exit 1; }

case "$TARGET" in
  bash) "$SHELL_BIN" -ic 'source ./'"$SNIPPET"'; ls; echo hello; pwd' >/dev/null ;;
  zsh)  "$SHELL_BIN" -i -c 'source ./'"$SNIPPET"'; ls; echo hello; pwd' >/dev/null ;;
  fish) "$SHELL_BIN" -i -c 'source ./'"$SNIPPET"'; ls; echo hello; pwd' >/dev/null ;;
esac

echo "=== 日志内容（$HIST）==="
[ -f "$HIST" ] || { echo "FAIL: 日志文件未生成" >&2; exit 1; }
cat "$HIST"
echo "======================="

# 验证：追加且包含命令记录
if grep -q 'session-start' "$HIST"; then echo "PASS: 含 session-start"; else echo "FAIL: 缺 session-start" >&2; exit 1; fi
if grep -q 'ls' "$HIST" && grep -q 'hello' "$HIST" && grep -q 'pwd' "$HIST"; then
  echo "PASS: 各条命令均已记录"
else
  echo "FAIL: 部分命令未被记录" >&2; exit 1
fi
echo "ALL PASS ($TARGET)"
