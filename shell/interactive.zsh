#!/usr/bin/env zsh
# 交互式 zsh 的「零插件」增强（由 ~/.zshrc 的 `# >>> dotfiles` 标记块 source）
#
# 设计原则：核心只用 zsh 5.9 自带能力，不引入 oh-my-zsh / zinit / 主题框架；
# fzf / zoxide 这类「单文件二进制」只在检测到已安装时接入，缺失不影响任何功能。
# 本机基线：`/usr/bin/time -p zsh -i -c exit` ≈ 0.01s；改完应仍在 0.01~0.03s。
# 全部条目已于 2026-11-22 用 `zsh -fic 'source ~/.config/zsh/interactive.zsh'` 实跑验证。
# 回滚：注释掉 ~/.zshrc 里那行 source 即可（本文件留着无害）。

# 非交互式 shell（脚本、ssh 远端命令）直接跳过，避免污染环境
[[ -o interactive ]] || return 0

# --- 历史 ---
# 多窗口共享历史、相邻重复只留一条、去掉行尾空白、执行前确认 ! 展开
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY NO_BEEP
# AUTO_CD：输入目录名直接 cd；PUSHD_IGNORE_DUPS：pushd 不留重复项
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
# COMPLETE_IN_WORD：光标在词中间也能补全；ALWAYS_TO_END：补全后光标落在词尾
setopt COMPLETE_IN_WORD ALWAYS_TO_END
# 允许 # 注释；EXTENDED_GLOB 提供 ^ / ~ 排除语法（刻意**不开** GLOB_DOTS：
# 那会让 `*` 也匹配隐藏文件，`rm *` 会误伤 .git 之类）
setopt INTERACTIVE_COMMENTS EXTENDED_GLOB
# 提示符里允许展开 ${...}
setopt PROMPT_SUBST

# --- 补全 ---
# -C 跳过「补全目录是否可写」的安全检查（本机 zsh 目录都是 root 所有，安全）
if ! typeset -f compdef >/dev/null 2>&1; then
    autoload -Uz compinit && compinit -C
fi
zmodload zsh/complist
zstyle ':completion:*' menu select                       # 补全列表可用方向键选
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # 补全时大小写不敏感

# --- 上下键 = 按已输入前缀搜索历史（比逐条翻好用）---
# 为什么绑两组：xterm-256color 的 terminfo 把 kcuu1 定义成「应用模式」`^[OA`，
# 而终端默认发「普通模式」`^[[A`（Ghostty 也是）。只绑 terminfo 那组不会生效（实测）。
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^[OA' history-beginning-search-backward
bindkey '^[OB' history-beginning-search-forward

# --- 内置小工具 ---
autoload -Uz run-help          # 光标下命令的 man 页：Ctrl+X h（见下方说明）
bindkey '^Xh' run-help
autoload -Uz edit-command-line # Ctrl+X Ctrl+E：整行丢进编辑器（$EDITOR 未设置时用 vi）
zle -N edit-command-line
bindkey '^X^E' edit-command-line
autoload -Uz _expand_alias     # Ctrl+X a：把光标前的别名原地展开成真实命令
zle -N _expand_alias
bindkey '^Xa' _expand_alias

# --- 命名目录：cd ~cfg 进入 zsh 配置目录 ---
hash -d cfg=${HOME}/.config/zsh
# （代理相关命名目录不在公开版内）

# --- 备忘（zsh 自带，无需安装）---
#   zmv -n '(*).jpeg' '$1.jpg'          批量改名（-n 先演练，去掉 -n 才执行）
#   zcalc                               交互式计算器（管道喂入会挂住，别用 echo | zcalc）
#   zargs -- **/*.png -- sips -Z 1600   xargs 的 zsh 版
#   ls -lh *(om[1,5])                   最近修改的 5 个文件（glob qualifier）
#   print =python3                      =cmd 展开成绝对路径
#   ^foo^bar                            改正上一条命令里的词
#
# 注：Option/Alt 在 macOS 默认输入特殊字符（˙ 等），所以 run-help 绑在 Ctrl+X h；
#     若在 Ghostty 里设了 macos-option-as-alt = true，可再 `bindkey '^[h' run-help`。

# --- 外部单文件工具（可选；检测到才接入，缺失不影响任何功能）---
# fzf：Ctrl+R 搜历史、Ctrl+T 选文件、Alt+C 跳目录
#      ⚠️ Alt+C 需要 Ghostty 的 macos-option-as-alt = true（本机没开，所以不可用）
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
    # 装了 fd 才把它当遍历器（本机未装 fd → fzf 退回内建 find，Ctrl+T 仍可用）
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
fi
# zoxide：z <关键字> 按访问频率跳目录；zi 走 fzf 交互选择
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# --- 命令总览（cmds，只读）---
cmds() { "$HOME/.config/zsh/cmds.sh" "$@"; }

# --- 零插件提示符（vcs_info 查 git，不装 starship/p10k）---

# 想关掉：在 ~/.zshrc 的 `# >>> dotfiles` 块之前写 export WORK_PROMPT=0
: ${WORK_PROMPT:=1}
if (( WORK_PROMPT )); then
    autoload -Uz vcs_info
    zstyle ':vcs_info:git:*' formats '%F{magenta}%b%f'
    zstyle ':vcs_info:git:*' actionformats '%F{magenta}%b%f %F{yellow}(%a)%f'
    _work_vcs_precmd() { vcs_info }
    # 幂等：重复 source 不会把同一个 precmd 钩子加两次
    precmd_functions=(${precmd_functions:#_work_vcs_precmd} _work_vcs_precmd)
    PROMPT='%F{8}%1~%f %(?..%F{red}✗%? %f)%# '
    RPROMPT='${vcs_info_msg_0_}'
    # 回车后立刻擦掉右侧 git 分支，避免滚动时残留半行
    setopt TRANSIENT_RPROMPT
fi
