# shell/

零插件 zsh 增强：PATH 去重、经典别名、历史搜索、提示符、外观切换。

| 文件 | 作用 |
| --- | --- |
| `env.zsh` | `typeset -U path fpath manpath`（PATH 永久去重） |
| `aliases.zsh` | 50+ 经典别名，只做纯增量（不覆盖 `rm`/`cp`/`mv`） |
| `interactive.zsh` | 历史搜索、`Ctrl+X h` 查 man、`Ctrl+X Ctrl+E` 编辑整行、`Ctrl+X a` 展开别名、`cmds` 总览、零插件提示符 |
| `appearance.sh` | `status\|light\|dark\|toggle` 切换系统外观（VS Code / Ghostty 自动跟随） |
| `cmds.sh` | `cmds` 子命令：列别名 / 函数 / 已装软件命令 |

安装：`./bootstrap.sh --write-zshrc`（把 `# >>> dotfiles` 块追加进 `~/.zshrc`），或手动加：

```zsh
# >>> dotfiles
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/env.zsh"
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.zsh"
source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/interactive.zsh"
# <<< dotfiles
```

要点：

- 方向键要**同时绑 `^[[A` 与 `^[OA`**（xterm-256color 用应用模式，只绑一个完全不生效）。
- 刻意不开 `GLOB_DOTS`：`*` 不匹配隐藏文件，避免 `rm *` 误伤 `.git`。
- `..` 不是 `AUTO_CD` 自带的，必须显式 alias。
- `fzf` / `zoxide` 检测到才接入；缺失不影响任何功能。
- `WORK_PROMPT=0` 可关掉提示符；`Ctrl+X h` 查 man 是因为 macOS 的 Option 默认输入特殊字符。
- 外观切换走 System Events，需要「自动化」权限；被拒时报 `-1743`。
