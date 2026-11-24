# ghostty/

Ghostty 的配置、主题和光标拖尾着色器。

```bash
./install.sh --dry     # 打印将建立的链接/复制
./install.sh           # 备份旧配置 → 链接 config → 链接主题 → 复制着色器
./install.sh status    # 看生效文件、残留覆盖源、解析后的关键值
./verify-config.py     # 逐键对照「配置写的」与「Ghostty 实际解析的」
```

要点（都是实测踩过的）：

- **两份配置会合并**：`~/.config/ghostty/config` 与 `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`，**后者优先覆盖同名键**。`install.sh` 会把后者备份并移除。
- **`Bold` / `Italic` 是样式不是族名**：写 `font-family-bold = "… Bold"` 会静默回退；选样式请用 `font-style*`。
- **`+validate-config` 对未知键静默放行**，不能当唯一校验；用 `+show-config` 或 `verify-config.py`。
- `light:` / `dark:` 只对 `theme` 有效，且必须成对。
- **改 `background-opacity` 要完全退出 Ghostty** 再启动；改字体/字号需新窗口；其余可 `Cmd+Shift+,` 重载。
- 着色器编译失败不会报配置错误，只写日志；整窗变黑时注释掉 `custom-shader` 即可恢复。
- 部分外观键（`macos-glass-*`、`window-padding-balance`）需要较新的 macOS / Ghostty 1.4+，旧版本删掉对应行。
