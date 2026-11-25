#!/usr/bin/env bash
# px —— 快捷入口（本仓库的公开版）
#
# 由 ~/.config/zsh/interactive.zsh 在交互式 shell 里自动 source，不需要手动改 .zshrc。
#
#   px dark | light | tog   切换系统外观（VS Code / Ghostty 自动跟随）
#   px app                  查看当前外观与各应用跟随情况
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
  ds <问题>                     DeepSeek 一行问答（--pro / --think / --dry，或 ds status）
  help                          显示本帮助

代理控制（on / off / st / sys / k / socks / key）不包含在本仓库：
它需要你自己的节点凭证与代理启动脚本。请使用自己的 VPN 或自建代理配置。
EOF
}

px() {
    local sh="$_PX_DIR"
    local cmd="${1:-help}"
    case "$cmd" in
        dark)  "$sh/appearance.sh" dark ;;
        light) "$sh/appearance.sh" light ;;
        tog|toggle) "$sh/appearance.sh" toggle ;;
        app|appearance|status) "$sh/appearance.sh" status ;;
        ds)    shift; "$sh/ds.sh" "$@" ;;
        help|-h|--help) _px_usage ;;
        on|off|st|sys|k|socks|key)
            echo "ℹ️  代理部分不在本仓库内（需要你自己的节点配置与代理脚本）。" >&2
            echo "    外观：px dark|light|tog|app    更多：px help" >&2
            return 1 ;;
        *)     _px_usage; echo "❌ 未知命令: $cmd" >&2; return 1 ;;
    esac
}
