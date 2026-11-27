# shell-history-logger (bash)
#
# 将每条交互执行的命令以“追加”方式写入日志文件（默认 ~/.history）。
#
# 特性（尽量不冲突）:
#   - 不修改 HISTFILE / HISTSIZE / HISTCONTROL / HISTTIMEFORMAT
#   - 仅“追加” PROMPT_COMMAND，绝不覆盖已有内容（兼容 bash>=4.4 的数组形式）
#   - 幂等：重复 source 只注册一次
#   - 所有符号带 __append_history_bash_ 前缀，避免命名冲突
#   - 仅用 >> 追加写，写入失败时静默，不影响正常使用
#
# 配置:
#   export APPEND_HIST_FILE=/path/to/file   覆盖日志路径（默认 ~/.history）
#   export APPEND_HIST_SESSION_MARK=0       禁用会话开始标记行
#
# 日志行格式:
#   2026-11-12 17:07:00 CST | bash | pid=1234 | cwd=/home/u | ls -la
#
# 用法（追加到 ~/.bashrc 末尾）:
#   source /path/to/append-history.bash

if [[ -z "${__APPEND_HISTORY_BASH_LOADED:-}" ]]; then
  __APPEND_HISTORY_BASH_LOADED=1

  # __append_history_bash_write <shell标签> <pid> <cwd> <命令或事件>
  __append_history_bash_write() {
    local file="${APPEND_HIST_FILE:-$HOME/.history}"
    printf '%s | %s | pid=%s | cwd=%s | %s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$1" "$2" "$3" "$4" >> "$file" 2>/dev/null
    return 0
  }

  # 由 PROMPT_COMMAND 调用：记录刚刚执行完的那条命令
  __append_history_bash_log() {
    local cmd
    # history 1 形如 "  42  ls -la"，去掉序号与前置空白，保留命令原文
    cmd="$(history 1 2>/dev/null | sed -e 's/^[[:space:]]*[0-9]*[[:space:]]*//')"
    [[ -n "$cmd" ]] || return 0
    __append_history_bash_write bash "$$" "$PWD" "$cmd"
    return 0
  }

  # 注册进 PROMPT_COMMAND（只追加，不覆盖；幂等；兼容 4.4+ 的数组形式）
  if [[ "${PROMPT_COMMAND[*]:-}" != *"__append_history_bash_log"* ]]; then
    if [[ "${BASH_VERSINFO[0]}" -gt 4 || "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]:-0}" -ge 4 ]]; then
      PROMPT_COMMAND+=('__append_history_bash_log')   # bash >= 4.4：数组追加，不影响既有元素
    elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
      PROMPT_COMMAND="${PROMPT_COMMAND}
__append_history_bash_log"          # 旧版：换行分隔追加，不影响既有命令
    else
      PROMPT_COMMAND="__append_history_bash_log"
    fi
  fi

  # 会话开始标记（仅交互式 shell；可用 APPEND_HIST_SESSION_MARK=0 关闭）
  # bash 没有名为 interactive 的 `set -o` 选项，[[ -o interactive ]] 在交互式
  # shell 中同样为假，会导致该标记永远不写入；改用 $- 判断交互状态。
  if [[ $- == *i* && "${APPEND_HIST_SESSION_MARK:-1}" != "0" ]]; then
    __append_history_bash_write bash "$$" "$PWD" "session-start"
  fi
fi
