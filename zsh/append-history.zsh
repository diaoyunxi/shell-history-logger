# shell-history-logger (zsh)
#
# 将每条交互执行的命令以“追加”方式写入日志文件（默认 ~/.history）。
#
# 特性（尽量不冲突）:
#   - 不修改 HISTFILE / HISTSIZE / HISTCONTROL / HISTTIMEFORMAT
#   - 仅“追加” preexec_functions，绝不覆盖已有内容
#   - 幂等：重复 source 只注册一次
#   - 所有符号带 __append_history_zsh_ 前缀，避免命名冲突
#   - 仅用 >> 追加写，从不截断或重写日志
#
# 配置:
#   export APPEND_HIST_FILE=/path/to/file   覆盖日志路径（默认 ~/.history）
#   export APPEND_HIST_SESSION_MARK=0       禁用会话开始标记行
#
# 日志行格式:
#   2026-11-12 17:07:00 CST | zsh | pid=1234 | cwd=/home/u | ls -la
#
# 用法（追加到 ~/.zshrc 末尾）:
#   source /path/to/append-history.zsh

if [[ -z "${__APPEND_HISTORY_ZSH_LOADED:-}" ]]; then
  __APPEND_HISTORY_ZSH_LOADED=1

  # __append_history_zsh_write <shell标签> <pid> <cwd> <命令或事件>
  __append_history_zsh_write() {
    local file="${APPEND_HIST_FILE:-$HOME/.history}"
    printf '%s | %s | pid=%s | cwd=%s | %s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" \
      "$1" "$2" "$3" "$4" >> "$file" 2>/dev/null
    return 0
  }

  # preexec 回调：在每条命令“执行前”记录（此时 $1 是原始命令行）
  __append_history_zsh_preexec() {
    [[ -n "$1" ]] || return 0
    # 过滤对 logger 自身片段的 source，避免把配置本身记进日志（可选）
    case "$1" in
      *append-history.zsh*) return 0 ;;
    esac
    __append_history_zsh_write zsh "$$" "$PWD" "$1"
    return 0
  }

  # 注册进 preexec_functions（只追加，不覆盖；幂等）
  # 显式声明为全局数组：未定义时 ${preexec_functions[(I)...]} 展开为空字符串，
  # 原判断会误以为“已注册”而跳过，导致钩子完全不生效。
  typeset -ga preexec_functions
  if (( ${preexec_functions[(I)__append_history_zsh_preexec]} == 0 )); then
    preexec_functions+=(__append_history_zsh_preexec)
  fi

  # 会话开始标记（仅交互式 zsh；可用 APPEND_HIST_SESSION_MARK=0 关闭）
  if [[ -o interactive && "${APPEND_HIST_SESSION_MARK:-1}" != "0" ]]; then
    __append_history_zsh_write zsh "$$" "$PWD" "session-start"
  fi
fi
