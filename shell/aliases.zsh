#!/usr/bin/env zsh
# 经典命令行缩写（由 ~/.zshrc 的 `# >>> work` 标记块 source）
#
# 三条原则：
#   1) 只做「纯增量」：不覆盖 rm / cp / mv 这类有破坏性的命令
#      （`cp -i` / `rm -i` 会让批量操作变成问答，也改变脚本行为；想要可自行加）
#   2) macOS 是 BSD 工具：ls 上色用 -G（已在 ~/.zshrc 里），没有 GNU 的 --color
#   3) 别名只在交互式 shell 生效，不影响脚本和非交互式 ssh 命令
#
# 回滚：注释掉 ~/.zshrc 里那行 source；或单独删掉不想用的 alias。

# --- ls 家族 ---
alias l='ls -CF'        # 分栏 + 类型标记（目录带 /）
alias ll='ls -lh'       # 长格式 + 人类可读大小（你的例子）
alias la='ls -lAh'      # 长格式 + 含隐藏文件（不含 . 与 ..）
alias lt='ls -lht'      # 按修改时间倒序
alias ltr='ls -lhtr'    # 按修改时间正序
alias lsd='ls -d */'    # 只看目录

# --- 目录跳转 ---
# 注：AUTO_CD 只能让「目录名」直接 cd，`..` 仍然会被当成命令执行（实测 permission denied）
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'                 # `-` 回到上一个目录
alias root='cd /'                 # 回根目录
alias groot='cd "$(git rev-parse --show-toplevel)"'   # 跳到 git 仓库根

# --- 文件 / 磁盘 ---
alias md='mkdir -p'                   # 建多级目录
alias dus='du -sh *'                  # 当前目录各项大小
alias ducks='du -sh * | sort -h'      # 按大小排序（经典名字 ducks）
alias df='df -h'
alias du='du -h'

# --- 进程 / 端口 / 网络 ---
alias psg='ps aux | grep -i'          # 用法：psg nginx
alias ports='lsof -iTCP -sTCP:LISTEN -P -n'   # 本机监听端口
alias myip='curl -s https://ifconfig.me; echo'

# --- git（只设只读/低风险命令；本仓库按约定不配远端，所以没有 push 别名）---
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -30'
alias gb='git branch -vv'
alias gco='git checkout'
alias gsw='git switch'
alias gstash='git stash'

# --- 杂项 ---
alias h='history'
alias c='clear'
alias q='exit'
alias reload='exec zsh'                       # 改完配置重载当前 shell
alias now='date "+%Y-%m-%d %H:%M:%S"'
alias week='date +%V'                         # ISO 周数
alias json='jq .'                             # 格式化 JSON（jq 已装）
alias serve='python3 -m http.server'          # 当前目录起静态服务（默认 8000）
# sudo 后面允许继续展开别名：`sudo ll` 等价于 `sudo ls -lh`
alias sudo='sudo '

# --- 全局别名（zsh 特色：放在命令任意位置都生效）---
# 例：`ping -c3 example.com NUL`（丢弃输出）、`git log L`（分页看）
alias -g L='| less -R'
alias -g H='| head'
alias -g T='| tail'
alias -g G='| grep'
alias -g W='| wc -l'
alias -g NUL='>/dev/null 2>&1'
