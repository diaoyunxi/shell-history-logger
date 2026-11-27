# shell-history-logger (fish)
#
# 将每条交互执行的命令以“追加”方式写入日志文件（默认 ~/.history）。
#
# 特性（尽量不冲突）:
#   - 不改动 fish 自身 history 机制（~/.local/share/fish/fish_history）
#   - 用 --on-event fish_preexec 注册（同名函数重定义不会重复触发，幂等）
#   - 所有符号带 __append_history_fish_ 前缀，避免命名冲突
#   - 仅用 >> 追加写，从不截断或重写日志；写失败静默
#
# 配置:
#   set -gx APPEND_HIST_FILE /path/to/file    覆盖日志路径（默认 ~/.history）
#   set -gx APPEND_HIST_SESSION_MARK 0        禁用会话开始标记行
#
# 日志行格式:
#   2026-11-12 17:07:00 CST | fish | pid=1234 | cwd=/home/u | ls -la
#
# 用法（追加到 ~/.config/fish/config.fish 末尾）:
#   source /path/to/append-history.fish

if not set -q __APPEND_HISTORY_FISH_LOADED
    set -g __APPEND_HISTORY_FISH_LOADED 1

    # __append_history_fish_write <shell标签> <pid> <cwd> <命令或事件>
    function __append_history_fish_write
        set -l file
        if set -q APPEND_HIST_FILE
            set file "$APPEND_HIST_FILE"
        else
            set file "$HOME/.history"
        end
        set -l ts (date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null; or date '+%Y-%m-%d %H:%M:%S')
        printf '%s | %s | pid=%s | cwd=%s | %s\n' \
            $ts $argv[1] $argv[2] $argv[3] $argv[4] >> $file 2>/dev/null
    end

    # 每条命令执行前被调用；fish_preexec 事件把完整命令行放在 $argv[1]
    function __append_history_fish_preexec --on-event fish_preexec
        set -l cmd "$argv[1]"
        if test -z "$cmd"
            set cmd (string join ' ' -- $argv)
        end
        if test -n "$cmd"
            # 过滤对 logger 自身片段的 source，避免把配置本身记进日志
            if not string match -q -- '*append-history.fish*' $cmd
                __append_history_fish_write fish (status pid) (pwd) "$cmd"
            end
        end
    end

    # 函数定义即完成事件注册；同名函数重定义不会累积多个处理器，
    # 配合文件开头的哨兵变量，重复 source 也保持幂等。

    # 会话开始标记（可用 APPEND_HIST_SESSION_MARK=0 关闭）
    if test "$APPEND_HIST_SESSION_MARK" != '0'
        __append_history_fish_write fish (status pid) (pwd) 'session-start'
    end
end
