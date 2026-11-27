# shell-history-logger (PowerShell)
#
# 将每条交互执行的命令以“追加”方式写入日志文件（默认 $HOME\.history）。
#
# 特性（尽量不冲突）:
#   - 只包装 prompt 函数：若用户已有自定义 prompt，原样保存并调用，绝不覆盖
#   - 不修改 $PSHistoryOptions / PSReadLine 等任何内置设置
#   - 幂等：$global:__AppendHistoryPs_Registered 保证重复 dot-source 只注册一次
#   - 所有符号带 __AppendHistoryPs_ 前缀，避免命名冲突
#   - 仅用 Add-Content (>>) 追加写，从不截断或重写日志
#   - 日志写入的异常被静默吞掉，不影响正常使用
#
# 工作原理: prompt 在每条命令执行完、显示提示符前被调用，
# 此时 Get-History -Count 1 取回的就是刚执行的命令。
#
# 配置:
#   $env:APPEND_HIST_FILE = "D:\logs\history.log"   覆盖日志路径（默认 $HOME\.history）
#   $env:APPEND_HIST_SESSION_MARK = "0"             禁用会话开始标记行
#
# 日志行格式:
#   2026-11-12 17:07:00 +08:00 | powershell | pid=1234 | cwd=C:\Users\u | Get-ChildItem
#
# 用法（追加到 $PROFILE 末尾）:
#   . "$HOME\shell-history-logger\powershell\append-history.ps1"

function __AppendHistoryPs_Write {
    param([string]$Shell, [int]$Pid_, [string]$Cwd, [string]$Event)
    try {
        $file = $env:APPEND_HIST_FILE
        if (-not $file) { $file = [System.IO.Path]::Combine($HOME, ".history") }
        $dir = [System.IO.Path]::GetDirectoryName($file)
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
        Add-Content -Path $file -Value ("{0} | {1} | pid={2} | cwd={3} | {4}" -f $ts, $Shell, $Pid_, $Cwd, $Event) -Encoding UTF8
    } catch {
        # 日志失败绝不干扰正常使用
    }
}

if (-not $global:__AppendHistoryPs_Registered) {
    $global:__AppendHistoryPs_Registered = $true
    $global:__AppendHistoryPs_LastHistoryId = 0

    # 保存用户已有的 prompt（函数形式）：用 $function:prompt 捕获其定义文本
    # （5.1 与 7.x 都兼容；$cmd.ScriptBlock 在 5.1 上不可靠）。
    $script:__AppendHistoryPs_OrigPromptSrc = $null
    $cmd = Get-Command -Name prompt -CommandType Function -ErrorAction SilentlyContinue
    if ($cmd) {
        $script:__AppendHistoryPs_OrigPromptSrc = $function:prompt
    }

    function prompt {
        try {
            # 提示符在下条输入前显示，此时历史里最后一条即刚执行的命令。
            # Get-History 返回 HistoryInfo，命令文本在 CommandLine 属性（不是 Command）；
            # prompt 会被空回车 / Ctrl+C 等重复调用，用 Id 去重避免同一条命令反复写入。
            $last = Get-History -Count 1 -ErrorAction SilentlyContinue
            if ($last -and $last.CommandLine -and $last.Id -ne $global:__AppendHistoryPs_LastHistoryId) {
                $global:__AppendHistoryPs_LastHistoryId = $last.Id
                __AppendHistoryPs_Write 'powershell' $PID $PWD.Path ($last.CommandLine -replace "`n", ' ')
            }
        } catch {}
        # 原样调用用户的自定义 prompt；没有自定义时输出默认样式
        if ($script:__AppendHistoryPs_OrigPromptSrc) {
            [scriptblock]::Create($script:__AppendHistoryPs_OrigPromptSrc).Invoke()
        } else {
            "PS " + $PWD.Path + ">"
        }
    }

    # 会话开始标记（可用 $env:APPEND_HIST_SESSION_MARK = "0" 关闭）
    if ($env:APPEND_HIST_SESSION_MARK -ne '0') {
        __AppendHistoryPs_Write 'powershell' $PID $PWD.Path 'session-start'
    }
}
