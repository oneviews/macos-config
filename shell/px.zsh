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
     dark | light               用深/浅色主题开一个新窗口
     open <主题名>              用指定主题开一个新窗口
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

# 只影响新开的窗口：命令行覆盖 theme，不动配置、不动系统外观
_px_term_open() {
    local theme
    theme="$(printf '%s' "$1" | sed -E 's/ \((resources|user)\)$//')"   # 允许直接粘贴 list-themes 的输出
    [[ -d /Applications/Ghostty.app ]] || { echo "❌ 未安装 Ghostty（brew install --cask ghostty）" >&2; return 1; }
    open -na Ghostty.app --args --theme="$theme" || return 1
    echo "✅ 已用「$theme」打开新窗口（其它窗口与系统外观不变）"
}

# 写进配置：改 theme 这一行（没有就追加），先备份，写完读回
_px_term_write() {
    local value dry="${2:-0}" cfg tmp
    value="$(printf '%s' "$1" | sed -E 's/ \((resources|user)\)$//')"   # 允许直接粘贴 list-themes 的输出
    cfg="$(_px_term_cfg)"
    [[ -f "$cfg" ]] || { echo "❌ 找不到 Ghostty 配置: $cfg" >&2; return 1; }
    if [[ "$dry" == 1 ]]; then
        echo "· 将把 $cfg 的 theme 改为: $value"
        return 0
    fi
    tmp="$(mktemp)"
    awk -v t="$value" '
        /^[[:space:]]*theme[[:space:]]*=/ && !done { print "theme = " t; done = 1; next }
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
