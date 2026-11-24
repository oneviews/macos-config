#!/usr/bin/env bash
# macOS 系统设置：脚本化 + 可回滚
#
#   ./settings.sh list            列出受管项与当前值
#   ./settings.sh diff            只显示与期望值不一致的项
#   ./settings.sh backup          把当前值导出到 backups/defaults-<时间戳>.tsv
#   ./settings.sh apply           应用期望值（会先自动 backup）
#   ./settings.sh restore [file]  回滚到某个备份（默认最近一次）
#
# 说明：Dock / Finder 相关设置应用后会重启对应进程（Dock 图标会闪一下、Finder 窗口会重开）。
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$DIR/backups"
mkdir -p "$BACKUP_DIR" "$HOME/Pictures/Screenshots"

# domain|key|type|value
SETTINGS=(
    "com.apple.dock|autohide|bool|true"
    "com.apple.dock|show-recents|bool|false"
    "com.apple.dock|mru-spaces|bool|false"
    "com.apple.finder|ShowPathbar|bool|true"
    "com.apple.finder|ShowStatusBar|bool|true"
    "com.apple.finder|_FXShowPosixPathInTitle|bool|true"
    "com.apple.finder|_FXSortFoldersFirst|bool|true"
    "com.apple.finder|FXPreferredViewStyle|string|Nlsv"
    "com.apple.finder|AppleShowAllFiles|bool|true"
    "NSGlobalDomain|KeyRepeat|int|2"
    "NSGlobalDomain|InitialKeyRepeat|int|15"
    "NSGlobalDomain|ApplePressAndHoldEnabled|bool|false"
    "NSGlobalDomain|NSAutomaticCapitalizationEnabled|bool|false"
    "NSGlobalDomain|NSAutomaticPeriodSubstitutionEnabled|bool|false"
    "NSGlobalDomain|NSAutomaticQuoteSubstitutionEnabled|bool|false"
    "NSGlobalDomain|NSAutomaticDashSubstitutionEnabled|bool|false"
    "NSGlobalDomain|NSAutomaticSpellingCorrectionEnabled|bool|false"
    "com.apple.screencapture|location|string|$HOME/Pictures/Screenshots"
    "com.apple.screencapture|type|string|png"
)

current_value() { # domain key
    defaults read "$1" "$2" 2>/dev/null
}

# defaults read 对 bool 返回 1/0，统一成 true/false 再比较
normalize() { # type value
    case "$1" in
        bool)
            case "$2" in
                1|true|TRUE|yes) echo true ;;
                0|false|FALSE|no) echo false ;;
                *) echo "$2" ;;
            esac
            ;;
        *) echo "$2" ;;
    esac
}

write_value() { # domain key type value
    case "$3" in
        bool)   defaults write "$1" "$2" -bool   "$4" ;;
        int)    defaults write "$1" "$2" -int    "$4" ;;
        float)  defaults write "$1" "$2" -float  "$4" ;;
        string) defaults write "$1" "$2" -string "$4" ;;
        *)      echo "未知类型: $3" >&2; return 1 ;;
    esac
}

restart_ui() {
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
}

do_list() {
    printf '%-22s %-34s %-28s %s\n' "DOMAIN" "KEY" "当前值" "期望值"
    for row in "${SETTINGS[@]}"; do
        IFS='|' read -r domain key type want <<< "$row"
        cur="$(current_value "$domain" "$key")"
        [[ -z "$cur" ]] && cur="<未设置>"
        disp="$(normalize "$type" "$cur")"
        printf '%-22s %-34s %-28s %s\n' "$domain" "$key" "$disp" "$want"
    done
}

do_diff() {
    changed=0
    for row in "${SETTINGS[@]}"; do
        IFS='|' read -r domain key type want <<< "$row"
        cur="$(current_value "$domain" "$key")"
        if [[ "$(normalize "$type" "$cur")" != "$(normalize "$type" "$want")" ]]; then
            printf '  %-22s %-32s 当前=%-20s 期望=%s\n' "$domain" "$key" "${cur:-<未设置>}" "$want"
            changed=$((changed + 1))
        fi
    done
    [[ $changed -eq 0 ]] && echo "✅ 全部与期望值一致"
    return 0
}

do_backup() {
    local file="$BACKUP_DIR/defaults-$(date +%Y%m%d-%H%M%S).tsv"
    : > "$file"
    for row in "${SETTINGS[@]}"; do
        IFS='|' read -r domain key type want <<< "$row"
        cur="$(current_value "$domain" "$key")"
        [[ -z "$cur" ]] && cur="__UNSET__"
        printf '%s\t%s\t%s\t%s\n' "$domain" "$key" "$type" "$cur" >> "$file"
    done
    echo "$file"
}

do_apply() {
    local bk
    bk="$(do_backup)"
    echo "已备份当前值: $bk"
    local n=0
    for row in "${SETTINGS[@]}"; do
        IFS='|' read -r domain key type want <<< "$row"
        if write_value "$domain" "$key" "$type" "$want" 2>/dev/null; then
            n=$((n + 1))
        else
            echo "  ⚠️ 写入失败: $domain $key"
        fi
    done
    restart_ui
    echo "已应用 $n/${#SETTINGS[@]} 项，Dock/Finder 已重启"
}

do_restore() {
    local file="${1:-}"
    if [[ -z "$file" ]]; then
        file="$(ls -t "$BACKUP_DIR"/defaults-*.tsv 2>/dev/null | head -1)"
    fi
    [[ -n "$file" && -f "$file" ]] || { echo "找不到备份文件" >&2; exit 1; }
    echo "从 $file 回滚"
    while IFS=$'\t' read -r domain key type value; do
        [[ -z "$domain" ]] && continue
        if [[ "$value" == "__UNSET__" ]]; then
            defaults delete "$domain" "$key" 2>/dev/null
        else
            write_value "$domain" "$key" "$type" "$value"
        fi
    done < "$file"
    restart_ui
    echo "回滚完成"
}

case "${1:-list}" in
    list)    do_list ;;
    diff)    do_diff ;;
    backup)  do_backup ;;
    apply)   do_apply ;;
    restore) do_restore "${2:-}" ;;
    *)       echo "用法: $0 [list|diff|backup|apply|restore [file]]" >&2; exit 2 ;;
esac
