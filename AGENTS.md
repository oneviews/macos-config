# AGENTS.md — 给 AI 协作助手的约定与踩坑记录

本仓库是「单机 macOS 配置」的版本化副本。每条配置都有 `--dry` / `status` 入口，改动前先看差异，改动后读回实际值。

## 1. 改这个仓库的规则

- 脚本：`#!/usr/bin/env bash` + `set -euo pipefail`；中文输出统一前缀 `✅ ❌ ⚠️ ℹ️ ⏪`。
- **变量紧邻全角标点必须写 `${var}`**：`$var）`、`$var，` 在 `set -u` 下会直接 `unbound variable`（本项目已踩两次）。
- `grep` 无匹配返回 1：`set -e` 下必须 `|| true`；不要把 `grep` 放在函数/脚本末尾，否则退出码污染调用方。
- 幂等：重复执行不产生重复配置或多余备份；**不要**在提示里报一个并不存在的备份路径。
- 写入前支持 `--dry`；写入后**读回实际值**自检，不信任退出码。
- 子命令约定：默认 `apply` / `--dry` / `status`（生效文件 + 解析后的关键值 + 回滚提示）。
- 多行 python / shell 逻辑**写成文件再执行**，不要用 `python3 - <<'PY'`（交互式 shell 会吃掉 heredoc）。
- 提交信息用 Conventional Commits + 中文正文；交互式 zsh 里 heredoc 会挂住 → 先写 `/tmp/msg.txt` 再 `git commit -F`。

## 2. Ghostty（踩坑最密集）

- **两份配置会合并加载**：`~/.config/ghostty/config` 与 `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`，**后者优先覆盖同名键** → 必须只保留一份。
- **`Bold` / `Italic` 是同族样式，不是族名**：写 `font-family-bold = "… Bold"` 会静默失效（回退到别的字体）。选样式用 `font-style*`。
- **`+validate-config` 对未知键静默放行**（故意写错键名仍 exit 0）→ 不能作为唯一校验；用 `+show-config` 读生效值，或 `./ghostty/verify-config.py` 逐键对照。
- **`+show-config` 不能判断当前明暗**：进程未运行时它恒按浅色解析；只能确认「配置被正确解析」。
- **`light:` / `dark:` 前缀只对 `theme` 有效**，且必须成对给出，缺一不生效。
- **`background-opacity` 在 macOS 上必须完全退出应用**再启动；`Cmd+Shift+,` 重载无效。
- **`adjust-*` 是增量**（`2` = +2px），不是「设为 2」。
- **`background-blur` 已取代 `background-blur-radius`**，值是整数强度；`scrollback-limit` 已改名 `scrollback-limit-bytes`。
- **自定义 shader 编译失败不进配置校验**，只写日志；无效 shader 可能让整窗变黑 → 注释掉 `custom-shader` 即可恢复。
- 路径类键（`custom-shader`、`background-image`）会被展开成绝对路径输出，比对时先 `expanduser`。

## 3. Karabiner-Elements

- `to_if_alone` **在松开时**触发；按住超过 `basic.to_if_alone_timeout_milliseconds`（默认 1000ms）即取消。
- **`hold_down_milliseconds` 是 caps_lock 的虚拟按住时长**：官方示例 200。实测 **100ms 切不了 Caps**（图标闪一下回弹），这是系统的防误触判定。
- `mandatory` 修饰键在输出中**被移除**，`optional: ["any"]` 的**被保留**。
- 条件里的 `bundle_identifiers` 是正则：JSON 里写**单**反斜杠（`\\.` → 正则 `\.`），写成双反斜杠永远匹配不上，规则静默失效。
- live 配置是完整 profile，仓库里只存**单条 rule 对象**（`description` + `manipulators`），只能按 `description` 合并，不能当 complex_modifications 资产直接导入。
- 改完 live 文件是 600 权限；Karabiner 会自动重载，若没生效点一次 profile。

## 4. macOS 系统偏好

- `defaults read` 的布尔值返回 `1` / `0`（不是 `true` / `false`），比较与显示前要归一化。
- 改 plist 前先备份；`cfprefsd` 有内存缓存，改完可能要 `killall cfprefsd` 才生效（Dock 则 `killall Dock`）。
- 明暗外观的真值用 `osascript -e 'tell application "System Events" to get dark mode of appearance preferences'`；`defaults read -g AppleInterfaceStyle` 连续快速切换时会滞后一拍。
- 系统设置优先走 `defaults` 的用户态路径，能不用 sudo 就不用。

## 5. VS Code

- 生效路径：`~/Library/Application Support/Code/User/settings.json`；**VS Code 会原子写 → 用复制，不要软链接**。
- 用 `jq` 改嵌套键必须写扁平形式：`.["terminal.integrated.fontFamily"]`，否则会插成嵌套对象而不生效。
- 明暗跟随系统：`window.autoDetectColorScheme: true` + `workbench.preferredLightColorTheme` / `preferredDarkColorTheme`；开启后 `workbench.colorTheme` 不再决定实际主题。
- `settings.json` 里的字体族必须与已安装字体一致，否则静默回退；`vscode/check-font.swift` 可验证。

## 6. zsh

- `↑/↓` 绑历史搜索时，**必须同时绑 `^[[A` 与 `^[OA`** —— `xterm-256color` 的 terminfo 用应用模式 `\EOA`，只绑一个方向键完全不生效。
- 刻意**不开 `GLOB_DOTS`**：会让 `*` 匹配隐藏文件，`rm *` 会误伤 `.git`。
- `..` 不是 `AUTO_CD` 自带的，会被当命令执行 → 必须显式 alias。
- PATH 去重用 `typeset -U path fpath manpath`（zsh 内建，属性持久）；**不要**为了去重删掉 `~/.zprofile` 里的 `brew shellenv`（`MANPATH` 只由它提供）。
- `alias sudo='sudo '`（末尾空格）让 `sudo ll` 也能展开；`command -v` 守卫外部工具（fzf / zoxide），缺失不影响任何功能。

## 7. 验证顺序

```bash
./scripts/secret-scan.sh          # 1. 先确认没泄漏
./ghostty/verify-config.py        # 2. 逐键对照生效值（-q 只报问题）
./macos/settings.sh --status      # 3. 19 项偏好实际值
./vscode/sync.sh diff             # 4. 仓库与生效文件的差异
./karabiner/install.sh --dry      # 5. 规则合并后的效果
```
