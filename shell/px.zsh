#!/usr/bin/env bash
# px —— 快捷入口（本仓库的公开版）
#
# 由 ~/.config/zsh/interactive.zsh 在交互式 shell 里自动 source，不需要手动改 .zshrc。
#
#   px dark | light | tog   切换系统外观（VS Code / Ghostty 自动跟随）
#   px app                  查看当前外观与各应用跟随情况
#   px term …               终端主题（Ghostty）：now / ls / dark / light / open / set / follow
#   px ds "问题"            DeepSeek 一行问答（需 DEEPSEEK_API_KEY 或钥匙串）
#   px help                 帮助
#
# 代理控制（on / off / st / sys / k / socks / key）不在本仓库内：
# 它依赖各人自己的节点凭证与代理脚本，属于本机网络环境。

typeset -g _PX_DIR=${0:A:h}

_px_usage() {
    cat <<'EOF'
用法: px <命令> [参数]
  dark | light | tog | toggle   切换系统外观
  app | appearance | status     查看当前外观 + 各应用跟随情况
  term [子命令]                 终端主题（Ghostty），只影响终端：
     now | status               看配置里当前的 theme
     ls [关键字]                搜内置主题
     dark | light               用深/浅色主题开一个预览窗口
     open <主题名>              用指定主题开预览窗口
     close                      关掉所有预览窗口（不影响普通窗口）
     set <主题名> [--dry]       写入配置（长期固定，按 Cmd+Shift+, 生效）
     follow [--dry]             恢复 light/dark 成对、跟随系统
  ds <问题>                     DeepSeek 一行问答（--pro / --think / --dry，或 ds status）
  help                          显示本帮助

代理控制（on / off / st / sys / k / socks / key）不包含在本仓库：
它需要你自己的节点凭证与代理启动脚本。请使用自己的 VPN 或自建代理配置。
EOF
}

# ---------------- 终端主题（Ghostty） ----------------
_px_ghostty_bin() {
    if command -v ghostty >/dev/null 2>&1; then
        command -v ghostty
    elif [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
        echo /Applications/Ghostty.app/Contents/MacOS/ghostty
    else
        return 1
    fi
}

_px_term_cfg() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
}

# 规范化：支持 light:X,dark:Y；逐段去掉 (resources)/(user) 与多余空格
_px_term_normalize() {
    local raw="$1" out="" part pre
    for part in ${(s:,:)raw}; do
        part="$(printf '%s' "$part" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        pre=""
        case "$part" in
            light:*) pre="light:"; part="${part#light:}" ;;
            dark:*)  pre="dark:";  part="${part#dark:}" ;;
        esac
        part="$(printf '%s' "$part" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+\((resources|user)\)$//; s/[[:space:]]+$//')"
        out="${out:+$out,}${pre}${part}"
    done
    printf '%s' "$out"
}

# 可用主题名（去掉 list-themes 的 "(resources)"/"(user)" 标记）
_px_term_names() {
    local bin
    bin="$(_px_ghostty_bin)" || return 1
    "$bin" +list-themes 2>/dev/null | sed -E 's/ \((resources|user)\)$//'
}

# 校验主题名（支持 light:X,dark:Y 成对写法）；不存在就列候选并返回 1
_px_term_validate() {
    local value="$1" names part name
    names="$(_px_term_names)" || return 0      # 拿不到清单就跳过校验
    local bad=0
    for part in ${(s:,:)value}; do
        name="${${part#light:}#dark:}"
        [[ -z "$name" ]] && continue
        if ! printf '%s\n' "$names" | grep -qxF -- "$name"; then
            echo "❌ 主题不存在: $name" >&2
            printf '%s\n' "$names" | grep -iF -- "${name%% *}" | head -5 | sed 's/^/   候选: /' >&2
            bad=1
        fi
    done
    return "$bad"
}

# 只影响新开的窗口：命令行覆盖 theme，不动配置、不动系统外观
_px_term_open() {
    local theme
    theme="$(_px_term_normalize "$1")"   # 允许直接粘贴 list-themes 的输出（含成对写法）
    _px_term_validate "$theme" || return 1
    [[ -d /Applications/Ghostty.app ]] || { echo "❌ 未安装 Ghostty（brew install --cask ghostty）" >&2; return 1; }
    open -na Ghostty.app --args --theme="$theme" || return 1
    echo "✅ 已用「$theme」打开预览窗口（该实例强制此主题、不跟随系统；看完用 Cmd+Q 或 px term close）"
}

# 写进配置：改 theme 这一行（没有就追加），先备份，写完读回
_px_term_write() {
    local value dry="${2:-0}" cfg tmp
    value="$(_px_term_normalize "$1")"   # 允许直接粘贴 list-themes 的输出（含成对写法）
    _px_term_validate "$value" || return 1
    cfg="$(_px_term_cfg)"
    [[ -f "$cfg" ]] || { echo "❌ 找不到 Ghostty 配置: $cfg" >&2; return 1; }
    if [[ "$dry" == 1 ]]; then
        echo "· 将把 $cfg 的 theme 改为: $value"
        echo "  （会删掉其它重复的 theme 行，改动前先备份）"
        return 0
    fi
    tmp="$(mktemp)"
    awk -v t="$value" '
        /^[[:space:]]*theme[[:space:]]*=/ {
            if (!done) { print "theme = " t; done = 1 }
            next
        }
        { print }
        END { if (!done) print "theme = " t }
    ' "$cfg" > "$tmp" || { rm -f "$tmp"; return 1; }
    cp -p "$cfg" "$cfg.bak.$(date +%Y%m%d-%H%M%S)"
    cat "$tmp" > "$cfg"        # 重定向写入：保留权限，不破坏符号链接
    rm -f "$tmp"
    echo "✅ 已写入: $(grep -m1 '^theme' "$cfg")"
    echo "   在 Ghostty 里按 Cmd+Shift+, 重载（新窗口自动生效）"
}

_px_term() {
    local sub="${1:-now}"
    local dark="${PX_TERM_DARK:-0x96f}"
    local light="${PX_TERM_LIGHT:-Catppuccin Latte}"
    local cfg bin dry=0
    cfg="$(_px_term_cfg)"
    case "$sub" in
        now|status)
            echo "配置: $cfg"
            grep -m1 '^theme' "$cfg" 2>/dev/null || echo "theme = （未设置，使用默认配色）"
            echo "系统外观: $("$_PX_DIR/appearance.sh" status 2>/dev/null | head -1 | sed 's/^当前外观: //')"
            ;;
        ls|list)
            shift
            bin="$(_px_ghostty_bin)" || { echo "❌ 找不到 Ghostty" >&2; return 1; }
            "$bin" +list-themes 2>/dev/null | grep -i -- "${1:-}" | head -40
            ;;
        dark)  _px_term_open "$dark" ;;
        light) _px_term_open "$light" ;;
        close)
            local n
            n="$(pgrep -f 'Ghostty.app/Contents/MacOS/ghostty --theme=' | wc -l | tr -d ' ')"
            if [[ "$n" == 0 ]]; then
                echo "ℹ️  没有主题预览实例（普通窗口不受影响）"
                return 0
            fi
            pkill -f 'Ghostty.app/Contents/MacOS/ghostty --theme=' || true
            echo "✅ 已关闭 ${n} 个主题预览实例；普通窗口保持不动"
            ;;
        open)
            shift
            [[ -n "${1:-}" ]] || { echo "用法: px term open <主题名>" >&2; return 1; }
            _px_term_open "$1"
            ;;
        set)
            shift
            [[ -n "${1:-}" ]] || { echo "用法: px term set <主题名> [--dry]" >&2; return 1; }
            [[ "${2:-}" == "--dry" ]] && dry=1
            _px_term_write "$1" "$dry"
            ;;
        follow)
            [[ "${2:-}" == "--dry" ]] && dry=1
            _px_term_write "light:${light},dark:${dark}" "$dry"
            ;;
        *) echo "❌ 未知 term 子命令: $sub（now|ls|dark|light|open|set|follow）" >&2; return 1 ;;
    esac
}

px() {
    local sh="$_PX_DIR"
    local cmd="${1:-help}"
    case "$cmd" in
        dark)  "$sh/appearance.sh" dark ;;
        light) "$sh/appearance.sh" light ;;
        tog|toggle) "$sh/appearance.sh" toggle ;;
        app|appearance|status) "$sh/appearance.sh" status ;;
        term|t) shift; _px_term "$@" ;;
        ds)    shift; "$sh/ds.sh" "$@" ;;
        help|-h|--help) _px_usage ;;
        on|off|st|sys|k|socks|key)
            echo "ℹ️  代理部分不在本仓库内（需要你自己的节点配置与代理脚本）。" >&2
            echo "    外观：px dark|light|tog|app    终端：px term    更多：px help" >&2
            return 1 ;;
        *)     _px_usage; echo "❌ 未知命令: $cmd" >&2; return 1 ;;
    esac
}
