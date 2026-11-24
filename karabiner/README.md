# karabiner/

一条 Karabiner-Elements complex modification，把 `Ctrl` 组合键变成「Vim 式导航」。

```bash
./install.sh --dry    # 打印合并后的规则列表，不写入
./install.sh          # 按 description 合并进当前选中的 profile（先备份）
```

覆盖的键（全局，除非注明）：

- `Ctrl + i/j/k/l` → 上/左/下/右
- `Ctrl + u/o` → Page Up / Page Down
- `Ctrl + n/m` → Home / End（**终端内除外**：终端里 `Ctrl+n` 保留原生 `^N`，`Ctrl+m` 改发回车）
- `Ctrl + Shift + i/j/k/l` → 带选择/移动
- 轻点左 Ctrl（`hold_down_milliseconds = 200`）→ Caps Lock

要点：

- **100ms 切不了 Caps**：这是 macOS 的防误触判定，必须 ≥200ms。
- `to_if_alone` 在**松开时**触发；按住超过 `to_if_alone_timeout_milliseconds` 即取消。
- 条件里的 `bundle_identifiers` 是正则，JSON 中写**单**反斜杠；写成双反斜杠会静默失效。
- 若你在系统设置里把 Caps Lock 重映射成了 Control，轻点 Ctrl 切 Caps 会失效。
- 仓库里存的是**单条规则对象**，不是可直接导入的资产文件；只能由 `install.sh` 按 `description` 合并。
