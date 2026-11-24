# macOS 配置：可版本化、可回滚、可自检

把 macOS 上那些「点出来的设置」和「抄来的 dotfiles」变成一套脚本：能 `--dry` 预览、能 `status` 读回实际值、能一条命令回滚。

覆盖 5 块：**VS Code**、**Ghostty**、**Karabiner-Elements**、**系统偏好**、**zsh**。

> 本仓库**不含**任何密钥、订阅链接或代理/网络配置。
> `scripts/secret-scan.sh` 会在本地和 CI 里拦截 IP、个人路径、密钥样式与订阅链接样式。

## 要求

| 项 | 版本 | 说明 |
| --- | --- | --- |
| macOS | 26+ 推荐 | 部分 Ghostty 外观键（`macos-glass-*`）需要 26+；更早系统删掉那两行即可 |
| Homebrew | 任意 | 脚本不写死前缀，arm64 / Intel 都能用 |
| Ghostty | 1.4.0+ | 可选；`brew install --cask ghostty` |
| Karabiner-Elements | 16.3+ | 可选；规则按 `description` 合并进当前 profile |
| VS Code | 1.147+ | 主题名 `Light 2026` / `Dark 2026` 是 1.147 起才有的内置主题 |
| jq / python3 | 任意 | 脚本依赖；`xcrun swift` 仅自检脚本用 |
| 字体 Maple Mono NF CN | — | 可选；缺失时 VS Code / Ghostty 会静默回退到系统等宽字体 |

## 快速开始

```bash
# 0) 前置：Homebrew（新机器才有这一步；已装可跳过）
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(brew shellenv)"          # Apple Silicon 通常已自动写入 ~/.zprofile

# 1) 拿仓库（HTTPS 即可，不需要配 SSH key）
git clone https://github.com/oneviews/macos-config.git ~/macos-config
cd ~/macos-config

# 2) 自检 → 预览 → 执行
./scripts/secret-scan.sh     # 离线、只读，确认没有密钥 / IP 泄漏
./bootstrap.sh --dry         # 看它准备做什么，不改任何文件
./bootstrap.sh               # 执行（缺什么只提示，不会静默安装）
```

想连 `~/.zshrc` 一起配好（会先备份）：

```bash
./bootstrap.sh --write-zshrc
```

只想改一块：

```bash
./vscode/sync.sh push        # settings.json → VS Code 用户设置（先备份）
./ghostty/install.sh --dry   # 看 Ghostty 会改哪些文件
./ghostty/install.sh         # 建立 ~/.config/ghostty 链接
./karabiner/install.sh --dry # 看规则会合并成什么
./macos/settings.sh --status # 19 项系统偏好当前值
```

## 每个子目录都有同一套入口

| 目录 | 内容 | 入口 |
| --- | --- | --- |
| `vscode/` | 用户设置、扩展清单、字体检查 | `./vscode/sync.sh [push\|pull\|diff]` |
| `ghostty/` | 终端配置、主题、光标拖尾着色器、逐键校验 | `./ghostty/install.sh [--dry\|status]`、`./ghostty/verify-config.py` |
| `karabiner/` | 单条 complex modification（按 description 合并） | `./karabiner/install.sh [--dry]` |
| `macos/` | Dock / Finder / 键盘 / 截图等系统偏好 | `./macos/settings.sh [list\|diff\|apply\|restore]` |
| `shell/` | PATH 去重、经典别名、零插件交互增强、外观切换 | 由 `~/.zshrc` 的 `# >>> dotfiles` 块 source |
| `git/` | 全局 git 配置：按目录分配身份（`includeIf`）+ 全局忽略 | `./git/git.sh` |
| `scripts/` | 泄漏自检 | `./scripts/secret-scan.sh` |

## 设计取舍

1. **不覆盖破坏性命令**：不改 `rm` / `cp` / `mv`，别名只做纯增量。
2. **不引入框架**：不用 oh-my-zsh / zinit / 主题框架，交互增强只用 zsh 5.9 自带能力；`fzf`、`zoxide` 检测到才接入。
3. **先备份再写**：所有写入都留 `<file>.bak.<时间戳>`，输出里给回滚命令。
4. **读回自检**：不信任「命令返回 0」，写完后读实际值（Ghostty 用 `+show-config`，系统偏好用 `defaults read`）。
5. **幂等**：重复执行不产生重复配置；Ghostty 用符号链接（它只读配置，不会重写），VS Code 用复制（它会原子重写，软链会断）。

## 已知限制

- **字体缺失不会报错**：Ghostty / VS Code 会静默回退，看起来「配置没生效」。
- **`background-opacity` 要完全退出 Ghostty** 再启动，`Cmd+Shift+,` 重载无效。
- **Karabiner 的 Caps 切换**依赖 `hold_down_milliseconds ≥ 200`（100ms 会被系统防误触吃掉），且假定系统没有把 Caps Lock 重映射成 Control。
- **外观切换**走 System Events，需要「自动化」权限；被拒时报 `-1743`，只能手动改系统设置。
- **只面向 macOS**，脚本里的 `defaults` / `networksetup` / `osascript` 在 Linux 上不可用。

## 许可

MIT（见 `LICENSE`）。第三方资源各自保留许可，清单见 `THIRD-PARTY.md`；Maple Mono 字体不随仓库分发（SIL OFL 1.1，请自行安装）。
