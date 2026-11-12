# shell-history-logger

为 **bash / zsh / fish / PowerShell** 提供一段“即贴即用”的终端配置片段：
把**每一条实际执行的命令**以**追加（append-only）**方式记录到日志文件，
默认 `~/.history`（Windows 下为 `$HOME\.history`），**绝不改动**各 shell
自身的历史机制，**绝不覆盖**你已有的自定义配置。

## 为什么默认写 `~/.history`？

- bash/zsh 的 `HISTFILE` 通常已指向 `~/.bash_history`、`~/.zsh_history`，
  它们由 shell 以“重写/截断”方式维护（受 `HISTSIZE`、`HISTFILESIZE` 限制）。
- 本项目写的是**独立**的 `~/.history` 文件：只 `>>` 追加，永不截断、
  永不按条数丢弃，形成一份**完整的、带时间戳与上下文的审计日志**。
- 两条历史线互不干扰：shell 自己的历史（可编辑、去重、限长）照常工作。

## 日志行格式

```
2026-11-12 17:07:00 CST | bash | pid=1234 | cwd=/home/u | ls -la
2026-11-12 17:07:02 CST | bash | pid=1234 | cwd=/home/u | session-start
```

字段：`时间戳 | shell 名 | 进程号 | 当时工作目录 | 命令（或事件）`。

## 快速开始

### bash（Linux / macOS / WSL / Git-Bash）

```sh
git clone <repo-url> && cd shell-history-logger
bash install.sh            # 自动检测当前 shell
# 或
bash install.sh bash      # 在 ~/.bashrc 末尾追加标记块（幂等，可重复执行）
```

手动方式：把下面两行追加到 `~/.bashrc` 末尾，然后 `source ~/.bashrc`：

```sh
# >>> shell-history-logger >>>
source /绝对路径/shell-history-logger/bash/append-history.bash
# <<< shell-history-logger <<<
```

### zsh

```sh
bash install.sh zsh        # 在 ~/.zshrc 末尾追加标记块
```

### fish

```sh
bash install.sh fish       # 在 ~/.config/fish/config.fish 末尾追加标记块
```

### PowerShell（Windows / pwsh）

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
# 在 $PROFILE 末尾追加标记块（幂等，可重复执行）
```

安装完成后**重新打开终端**即生效。

## 可配置项（环境变量，不写死）

| 变量 | 默认值 | 说明 |
|---|---|---|
| `APPEND_HIST_FILE` | `~/.history` | 日志文件路径（目录不存在会自动创建） |
| `APPEND_HIST_SESSION_MARK` | `1` | 置 `0` 后不再写入 `session-start` 行 |

示例（Linux）：

```sh
export APPEND_HIST_FILE=~/shell-logs/history.log
```

## “不冲突”是如何保证的

| 机制 | bash | zsh | fish | PowerShell |
|---|---|---|---|---|
| 钩子方式 | 只向 `PROMPT_COMMAND` **追加**（4.4+ 用数组追加），不覆盖已有内容 | 只向 `preexec_functions` **追加** | 用官方 `fish_add_guard` 注册（自带幂等去重） | 只包装 `prompt` 函数：检测到已有自定义 prompt 时原样保存并调用 |
| 幂等 | `$__APPEND_HISTORY_BASH_LOADED` 等哨兵变量，重复 `source` 只注册一次 | 同左 + 数组去重 | `set -q` 哨兵 | `$global:__AppendHistoryPs_Registered` |
| 命名冲突 | 所有符号带 `__append_history_bash_` 前缀 | `__append_history_zsh_` | `__append_history_fish_` | `__AppendHistoryPs_` |
| 内置历史 | 不动 `HISTFILE`/`HISTSIZE`/`HISTCONTROL`/`HISTTIMEFORMAT` | 不动 | 不动 | 不动 `$PSHistoryOptions`/PSReadLine |
| 写入方式 | 一律 `>>` 追加；写失败 `2>/dev/null` 静默，绝不打断 shell | 同左 | 同左 | 异常被 try/catch 吞掉 |
| 安装方式 | rc 文件末尾加**标记块**，重跑脚本直接跳过，不会叠加 | 同左 | 同左 | 同左 |

## 自测

```sh
bash test.sh bash     # 在临时 HOME 中实测：生成 ~/.history、记录各条命令、追加成功
bash test.sh zsh      # 需已安装 zsh
bash test.sh fish    # 需已安装 fish
```

## 目录结构

```
shell-history-logger/
├── bash/append-history.bash      # bash 片段（PROMPT_COMMAND 追加）
├── zsh/append-history.zsh        # zsh 片段（preexec_functions 追加）
├── fish/append-history.fish     # fish 片段（fish_add_guard 幂等注册）
├── powershell/append-history.ps1 # PowerShell 片段（prompt 包装 + Get-History）
├── install.sh                    # Linux/macOS 安装（bash/zsh/fish）
├── install.ps1                   # Windows 安装（PowerShell）
└── test.sh                       # 自动化自测
```

## 隐私提示

- 日志是**明文追加**文件，包含完整命令行（可能含敏感参数）。
  请自行控制 `~/.history` 的权限：`chmod 600 ~/.history`。
- 本项目不做任何自动加密、轮转或上传。
