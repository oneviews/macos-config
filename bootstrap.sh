#!/usr/bin/env bash
# 一键把本仓库的配置应用到本机（缺什么只提示，不静默安装）
#
#   ./bootstrap.sh --dry          只检查 + 打印将要做的事
#   ./bootstrap.sh                检查后逐项应用（缺应用的会跳过并提示）
#   ./bootstrap.sh --yes          不询问
#   ./bootstrap.sh --write-zshrc  额外把 source 块追加到 ~/.zshrc（先备份）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
YES=0
WRITE_ZSHRC=0
for arg in "$@"; do
    case "${arg}" in
        --dry) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --write-zshrc) WRITE_ZSHRC=1 ;;
        -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "❌ 未知参数: ${arg}" >&2; exit 2 ;;
    esac
done

have() { command -v "$1" >/dev/null 2>&1; }
ok()   { printf '  ✅ %-22s %s\n' "$1" "$2"; }
warn() { printf '  ⚠️  %-22s %s\n' "$1" "$2"; }

echo "仓库: ${REPO}"
echo
echo "环境检查:"
have brew        && ok "Homebrew"  "$(brew --prefix)"            || warn "Homebrew" "未安装 → https://brew.sh"
have jq          && ok "jq"        "$(jq --version)"             || warn "jq" "未安装（karabiner 合并需要）→ brew install jq"
have python3     && ok "python3"   "$(python3 -V 2>&1)"          || warn "python3" "未安装（JSON 校验需要）"
have code        && ok "VS Code CLI" "$(code --version 2>/dev/null | head -1)" || warn "VS Code CLI" "命令面板 → Shell Command: Install 'code' command in PATH"
[[ -d /Applications/Ghostty.app ]] && ok "Ghostty" "已安装" || warn "Ghostty" "可选 → brew install --cask ghostty"
[[ -d /Applications/Karabiner-Elements.app ]] && ok "Karabiner" "已安装" || warn "Karabiner" "可选 → brew install --cask karabiner-elements"
if ls "${HOME}/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi 'maple.*mono'; then
    ok "Maple Mono" "字体已安装"
else
    warn "Maple Mono" "可选 → brew install --cask font-maple-mono-nf-cn（缺失会回退系统字体）"
fi
echo

run_step() {
    local name="$1"; shift
    if [[ ${DRY} -eq 1 ]]; then
        echo "· ${name}: 将执行 $*"
        return 0
    fi
    echo "--- ${name} ---"
    if ! "$@"; then
        echo "⚠️  ${name} 未完成（见上面的原因），已继续"
    fi
    echo
}

# 1. VS Code（复制，不软链：VS Code 会原子重写 settings.json）
if have code; then
    if [[ ${DRY} -eq 1 ]]; then
        echo "· VS Code: 将执行 ${REPO}/vscode/sync.sh push（会先备份现有 settings.json）"
    else
        run_step "VS Code" "${REPO}/vscode/sync.sh" push
    fi
else
    echo "ℹ️  跳过 VS Code（没有 code 命令）"
fi

# 2. Ghostty（符号链接）
if [[ -d /Applications/Ghostty.app ]]; then
    if [[ ${DRY} -eq 1 ]]; then run_step "Ghostty" "${REPO}/ghostty/install.sh" --dry
    else run_step "Ghostty" "${REPO}/ghostty/install.sh"; fi
else
    echo "ℹ️  跳过 Ghostty（未安装）"
fi

# 3. Karabiner（按 description 合并）
if [[ -d /Applications/Karabiner-Elements.app ]]; then
    if [[ ${DRY} -eq 1 ]]; then run_step "Karabiner" "${REPO}/karabiner/install.sh" --dry
    else run_step "Karabiner" "${REPO}/karabiner/install.sh"; fi
else
    echo "ℹ️  跳过 Karabiner（未安装）"
fi

# 4. 系统偏好（需要可选的 sudo，脚本自己会说明）
if [[ ${DRY} -eq 1 ]]; then run_step "macOS 偏好" "${REPO}/macos/settings.sh" diff
else run_step "macOS 偏好" "${REPO}/macos/settings.sh" apply; fi

# 5. zsh 片段：链接到 ~/.config/zsh，由 ~/.zshrc 的标记块 source
ZSHDIR="${XDG_CONFIG_HOME:-${HOME}/.config}/zsh"
if [[ ${DRY} -eq 1 ]]; then
    echo "· zsh: 将把 shell/{env,aliases,interactive}.zsh、cmds.sh、appearance.sh 链接到 ${ZSHDIR}"
else
    mkdir -p "${ZSHDIR}"
    for f in env.zsh aliases.zsh interactive.zsh cmds.sh appearance.sh; do
        ln -sfn "${REPO}/shell/${f}" "${ZSHDIR}/${f}"
    done
    echo "✅ zsh 片段已链接到 ${ZSHDIR}"
fi

BLOCK="# >>> dotfiles
source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/zsh/env.zsh\"
source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/zsh/aliases.zsh\"
source \"\${XDG_CONFIG_HOME:-\$HOME/.config}/zsh/interactive.zsh\"
# <<< dotfiles"

echo
echo "请把下面这段放进 ~/.zshrc（没有重复添加就可以）:"
printf '%s\n' "${BLOCK}" | sed 's/^/  /'

if [[ ${WRITE_ZSHRC} -eq 1 && ${DRY} -eq 0 ]]; then
    RC="${HOME}/.zshrc"
    touch "${RC}"
    if grep -q '# >>> dotfiles' "${RC}"; then
        echo "ℹ️  ~/.zshrc 已有 # >>> dotfiles 标记块，未重复写入"
    else
        cp -p "${RC}" "${RC}.bak.$(date +%Y%m%d-%H%M%S)"
        printf '\n%s\n' "${BLOCK}" >> "${RC}"
        echo "✅ 已追加到 ${RC}（原文件已备份；回滚：删掉该标记块）"
    fi
fi

echo
echo "下一步: exec zsh（或开新窗口），然后 ./scripts/secret-scan.sh 复核。"
