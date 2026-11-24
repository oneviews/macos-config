#!/usr/bin/env bash
# 切换 macOS 外观（浅色 / 深色）。VS Code 与 Ghostty 会自动跟随。
#
#   ./appearance.sh status        当前外观 + 各应用跟随情况
#   ./appearance.sh light|dark    切换
#   ./appearance.sh toggle        取反
#   ./appearance.sh dark --dry    只看要做的事，不改
#
# 实现：写 System Events 的 appearance preferences（Automation 权限）。
#       首次可能弹「XX 想要控制 System Events」，拒绝会报 -1743；
#       没有该授权时只能手动改「系统设置 → 外观」。
set -euo pipefail

DRY=0
ARGS=()
for a in "$@"; do
    case "$a" in
        --dry|dry) DRY=1 ;;
        *) ARGS+=("$a") ;;
    esac
done
CMD="${ARGS[0]:-status}"

VSC_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"

osa_get() {
    osascript -e 'tell application "System Events" to get dark mode of appearance preferences' 2>&1
}

osa_set() {
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" 2>&1
}

label() {
    if [[ "$1" == dark ]]; then echo 深色; else echo 明亮; fi
}

# 输出 dark / light；osascript 不可用时退回 defaults 判断
current() {
    local out
    out="$(osa_get || true)"
    case "$out" in
        true)  echo dark ; return 0 ;;
        false) echo light; return 0 ;;
    esac
    if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
        echo dark
    else
        echo light
    fi
}

show_followers() {
    echo "跟随情况:"
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" ]]; then
        echo "  Ghostty : $(grep -m1 '^theme = ' "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo '未设置 theme')"
    fi
    if [[ -f "$VSC_SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
        local l d a
        l="$(jq -r '.["workbench.preferredLightColorTheme"] // "-"' "$VSC_SETTINGS")"
        d="$(jq -r '.["workbench.preferredDarkColorTheme"] // "-"' "$VSC_SETTINGS")"
        a="$(jq -r '.["window.autoDetectColorScheme"] // false' "$VSC_SETTINGS")"
        echo "  VS Code : 浅=${l}  深=${d}  跟随系统=${a}"
    fi
}

show_status() {
    local cur
    cur="$(current)"
    echo "当前外观: $(label "$cur") (${cur})"
    echo "  System Events（真值）  : dark mode = $(osa_get || echo '不可用')"
    echo "  AppleInterfaceStyle    : $(defaults read -g AppleInterfaceStyle 2>/dev/null || echo '未设置（浅色）')  （持久值，偶有滞后）"
    show_followers
    echo "· 切完不用重启：VS Code 即时跟随；Ghostty 若未变按 Cmd+Shift+, 重载"
    echo "· 注意：ghostty +show-config 在没有 Ghostty 进程时恒按浅色解析，不能用来判断当前明暗"
}

do_switch() {
    local want="$1" cur flag out after
    cur="$(current)"
    if [[ "$cur" == "$want" ]]; then
        echo "ℹ️ 已是$(label "$want")模式，无需切换"
        show_followers
        return 0
    fi
    if [[ $DRY -eq 1 ]]; then
        echo "· 将切换为$(label "$want")模式（${cur} -> ${want}）"
        return 0
    fi
    flag="false"
    [[ "$want" == dark ]] && flag="true"
    out="$(osa_set "$flag" || true)"
    after="$(current)"
    if [[ "$after" != "$want" ]]; then
        echo "❌ 切换失败${out:+：${out}}" >&2
        echo "   手动方式: 系统设置 → 外观 → $(label "$want")" >&2
        echo "   授权方式: 系统设置 → 隐私与安全性 → 自动化 → 勾选控制 System Events" >&2
        return 1
    fi
    echo "✅ 已切换为$(label "$want")模式"
    show_followers
    echo "· Ghostty 若未变按 Cmd+Shift+, 重载；VS Code 会即时跟随"
}

case "$CMD" in
    status|st) show_status ;;
    light)     do_switch light ;;
    dark)      do_switch dark ;;
    toggle|tog)
        case "$(current)" in
            dark) do_switch light ;;
            *)    do_switch dark ;;
        esac
        ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)
        echo "用法: $0 [status|light|dark|toggle] [--dry]" >&2
        exit 2
        ;;
esac
