#!/usr/bin/env zsh
# 交互式 shell 的环境修饰（由 ~/.zshrc 的 `# >>> work` 标记块 source）
#
# 为什么需要 PATH 去重：/etc/paths.d/homebrew 由 /etc/zprofile 的 path_helper 注入一次，
# ~/.zprofile 里的 `brew shellenv zsh` 又前置一次 → /opt/homebrew/bin 与 /opt/homebrew/sbin
# 在 $path 里各出现两次。用 zsh 内建的 `typeset -U` 让数组永久去重（之后再重复插入也会自动合并）。
#
# ⚠️ 不要为了去重删掉 ~/.zprofile 的 brew shellenv：/etc/manpaths.d 是空的，
#    MANPATH 只由它提供，删了 brew 装的 man 手册页就查不到。
#
# 已知的死路径：
#   /pkg/env/global/bin   ← 原 /etc/paths.d/10-pmk-global，**已在 2026-11-22 删除**（软链目标下没有 bin/）
#   /usr/local/bin        ← /etc/paths（本机没有 Intel Homebrew，目录不存在）
#   /var/run/com.apple.security.cryptexd/...  ← 系统注入，随 cryptex 挂载出现，属正常
#
# 注：path_helper 会把「已存在于 PATH 但不在 /etc/paths* 里」的目录追加回来，
#     所以删掉 /etc/paths.d 里的文件后，已运行的 App（VS Code / Ghostty）要重启才会消失；
#     `env -i zsh -lc 'print -l $path'` 才能看到真值。
typeset -U path fpath manpath
