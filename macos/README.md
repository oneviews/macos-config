# macos/

系统偏好（Dock / Finder / 键盘 / 截图 / 触控板）的脚本化版本。

```bash
./settings.sh list        # 列出期望值
./settings.sh diff        # 与当前系统值对比（只读）
./settings.sh apply       # 写入并读回自检（先自动 backup）
./settings.sh restore     # 从 backups/ 里选一份回滚
```

要点：

- `defaults read` 的布尔值返回 `1` / `0`，脚本内部已归一化。
- `diff` 输出「✅ 全部与期望值一致」即表示当前系统与仓库一致。
- 部分键（如键盘重复率、Dock 位置）可能需要注销后生效；`cfprefsd` 有缓存。
- 截图默认保存到 `~/Pictures/Screenshots`，需要该目录存在（脚本会创建）。
- 不涉及任何网络/代理设置。
