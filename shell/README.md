# shell/

零插件 zsh 增强：PATH 去重、经典别名、历史搜索、提示符、外观切换。

| 文件 | 作用 |
| --- | --- |
| `env.zsh` | `typeset -U path fpath manpath`（PATH 永久去重） |
| `aliases.zsh` | 50+ 经典别名，只做纯增量（不覆盖 `rm`/`cp`/`mv`） |
| `interactive.zsh` | 历史搜索、`Ctrl+X h` 查 man、`Ctrl+X Ctrl+E` 编辑整行、`Ctrl+X a` 展开别名、`cmds` 总览、零插件提示符 |
| `appearance.sh` | `status\|light\|dark\|toggle` 切换系统外观（VS Code / Ghostty 自动跟随） |
| `cmds.sh` | `cmds` 子命令：列别名 / 函数 / 已装软件命令 |
| `px.zsh` | 快捷入口：`px dark\|light\|tog\|app`、`px term`、`px ds`（代理子命令只提示不可用） |

## px 快捷入口

| 命令 | 作用 |
| --- | --- |
| `px dark` / `px light` / `px tog` | 切换系统外观（VS Code / Ghostty 自动跟随） |
| `px app` | 当前外观 + 各应用跟随情况 |
| `px term` … | 终端主题，见下一节 |
| `px ds "问题"` | DeepSeek 一行问答（需 `DEEPSEEK_API_KEY` 或钥匙串 `deepseek-api`） |
| `px help` | 帮助 |

### 终端主题（Ghostty）

| 命令 | 作用 |
| --- | --- |
| `px term` / `px term now` | 看配置里的 `theme` + 当前系统外观 |
| `px term ls [关键字]` | 搜内置主题（820 个） |
| `px term dark` / `px term light` | 用深/浅色主题**开一个预览窗口**（独立实例，强制该主题、不跟随系统） |
| `px term open <主题名>` | 用指定主题开预览窗口 |
| `px term close` | 关掉所有预览窗口（普通窗口不动） |
| `px term set <主题名> [--dry]` | 写入 `~/.config/ghostty/config`（长期固定，按 `Cmd+Shift+,` 生效） |
| `px term follow [--dry]` | 恢复 `light:…,dark:…` 成对、跟随系统 |

默认深浅主题可用 `PX_TERM_DARK` / `PX_TERM_LIGHT` 覆盖；主题名带空格要加引号。
`px term ls` 输出末尾的 `(resources)` 只是来源标记，**不是主题名的一部分**；整行粘进去也行，px 会自动去掉。
成对写法同样支持：`px term set 'light:X,dark:Y'`，每段的后缀与多余空格都会被规范化。
`set` 写入前会校验主题名（不存在就列候选并拒绝），并**删除其它重复的 `theme` 行**，只保留一条。
`px term dark` 走的是 `open -na Ghostty.app --args --theme=…`——**macOS 上不能用 CLI 直接启动终端**，
所以「只换新窗口」只能这样开；要改当前窗口就 `px term set` + 按 `Cmd+Shift+,` 重载。

`px on` / `off` / `st` / `sys` / `k` / `socks` / `key` 属于**代理控制，不在本仓库内**：
它们依赖你自己的节点凭证与代理启动脚本。执行时会明确提示，不会静默失败。

`px.zsh` 由 `interactive.zsh` 在交互式 shell 里自动 source，不需要在 `~/.zshrc` 里额外加一行。

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
