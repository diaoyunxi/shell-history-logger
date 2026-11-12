# shell-history-logger 安装脚本（Windows PowerShell / pwsh）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#
# 原理: 在 $PROFILE 末尾追加 dot-source 行（带标记块，幂等可重跑）。
# 日志文件默认 $HOME\.history，可用 APPEND_HIST_FILE 覆盖。

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Snippet = Join-Path $RepoDir 'powershell\append-history.ps1'
if (-not (Test-Path $Snippet)) { $Snippet = "$PSScriptRoot\powershell\append-history.ps1" }
if (-not (Test-Path $Snippet)) { throw "找不到片段文件: $Snippet" }

$Profile = $PROFILE
if (-not $Profile) { throw "未找到 \$PROFILE" }
$ProfileDir = Split-Path -Parent $Profile
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null }
if (-not (Test-Path $Profile)) { New-Item -ItemType File -Path $Profile -Force | Out-Null }

$MarkBegin = '# >>> shell-history-logger >>>'
$MarkEnd   = '# <<< shell-history-logger <<<'
$content = Get-Content $Profile -Raw
if ($content -and $content.Contains($MarkBegin)) {
    Write-Host "已安装（$Profile 已包含 shell-history-logger），跳过。"
    exit 0
}

$block = @'

# >>> shell-history-logger >>>
# 将每条命令追加记录到日志（默认 \$HOME\.history），不影响 PowerShell 自身历史
. "PLACEHOLDER"
# <<< shell-history-logger <<<
'@
$block = $block.Replace('PLACEHOLDER', $Snippet)
Add-Content -Path $Profile -Value $block -Encoding UTF8

Write-Host "已追加到 $Profile："
Select-String -Path $Profile -Pattern 'shell-history-logger' | ForEach-Object { $_.Line }
Write-Host ""
Write-Host "完成。重新打开 PowerShell 后生效。"
Write-Host "日志默认写入 \$HOME\.history；可用环境变量 APPEND_HIST_FILE 改路径。"
