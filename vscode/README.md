# vscode/

VS Code 用户设置的版本化副本。

| 文件 | 作用 |
| --- | --- |
| `settings.json` | 权威副本（只改这里，再 push） |
| `sync.sh` | `push` / `pull` / `diff` 三个方向同步 |
| `extensions.txt` | 扩展清单（`code --list-extensions` 的结果） |
| `install-extensions.sh` | 按清单安装扩展 |
| `check-font.swift` | 用 CoreText 检查字体族是否存在、属于哪个样式 |

```bash
./sync.sh push     # 仓库 → VS Code（先备份现有 settings.json）
./sync.sh pull     # VS Code → 仓库（在界面里改完后回存）
./sync.sh diff
./install-extensions.sh
```

要点：

- VS Code 会**原子重写** `settings.json`，所以用复制而不是软链接。
- 主题名 `Light 2026` / `Dark 2026` 是 1.147 起的内置主题；旧版本请改成自带主题名，否则会回退默认。
- 字体 `Maple Mono NF CN` 不随仓库分发，缺失时静默回退；`xcrun swift check-font.swift` 可验证。
- 用 `jq` 改嵌套键要写扁平键名：`.["terminal.integrated.fontFamily"]`。
