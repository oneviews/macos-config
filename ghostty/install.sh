#!/usr/bin/env bash
# 把本目录的 config 部署为 Ghostty 的唯一配置来源
#
#   ./install.sh            应用（删除会覆盖它的 App Support 旧配置；旧文件先备份）
#   ./install.sh --dry      只打印将要做什么，不改动任何文件
#   ./install.sh status     看当前生效的是哪份文件、解析出的关键值
#
# 为什么用符号链接：Ghostty 只读配置、从不写回（不像 VS Code 会原子重写），
# 链接可保证「仓库 = 生效」永不漂移。
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/config"
THEMES_SRC="$DIR/themes"

XDG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
LIVE="$XDG_DIR/config"
THEMES_LIVE="$XDG_DIR/themes"
BACKUP_DIR="$XDG_DIR/backups"
# 旧版/残留位置：Ghostty 会与 XDG 配置「合并加载」，且优先级更高（会覆盖同名键）
LEGACY="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

TS="$(date +%Y%m%d-%H%M%S)"
DRY=0
LAST_BK=""

ghostty_bin() {
    if command -v ghostty >/dev/null 2>&1; then
        command -v ghostty
    elif [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
        echo /Applications/Ghostty.app/Contents/MacOS/ghostty
    else
        return 1
    fi
}

show_status() {
    local bin
    bin="$(ghostty_bin)" || { echo "❌ 未找到 Ghostty（brew install --cask ghostty）" >&2; return 1; }
    echo "Ghostty: $("$bin" +version 2>/dev/null | head -1)"
    echo "仓库配置: $SRC"
    if [[ -L "$LIVE" ]]; then
        echo "生效文件: $LIVE -> $(readlink "$LIVE")"
    elif [[ -f "$LIVE" ]]; then
        echo "生效文件: $LIVE （普通文件，不是链接；可能已漂移）"
    else
        echo "生效文件: 不存在"
    fi
    if [[ -f "$LEGACY" ]]; then
        echo "⚠️ 残留覆盖源: $LEGACY （会覆盖同名键，建议 ./install.sh 处理）"
    else
        echo "残留覆盖源: 无"
    fi
    echo "--- Ghostty 解析结果 ---"
    "$bin" +show-config 2>/dev/null \
        | grep -E '^(font-family|font-style|font-size|theme|background-blur|background-opacity|scrollback-limit-bytes) ' || true
    echo "--- 自定义键位是否加载 ---"
    "$bin" +show-config 2>/dev/null \
        | grep -E '=(new_tab|new_split:right|toggle_quick_terminal|reload_config)$' || true
}

verify() {
    local bin fams
    bin="$(ghostty_bin)" || return 0
    fams="$("$bin" +show-config 2>/dev/null | grep '^font-family = ' || true)"
    if [[ "$fams" == "font-family = Maple Mono NF CN" ]]; then
        echo "✅ 字体唯一且解析正确: Maple Mono NF CN"
    else
        echo "⚠️ 字体条目解析结果异常：" >&2
        echo "$fams" >&2
    fi
    echo "✅ 生效值: $("$bin" +show-config 2>/dev/null | grep -E '^(font-size|theme) ' | tr '\n' ' ')"
}

case "${1:-apply}" in
    apply|"") ;;
    --dry|dry) DRY=1 ;;
    status) show_status; exit 0 ;;
    -h|--help) echo "用法: $0 [apply|--dry|status]"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
esac

[[ -f "$SRC" ]] || { echo "❌ 找不到仓库配置: $SRC" >&2; exit 1; }

echo "仓库配置: $SRC"
echo "目标链接: $LIVE"

if [[ $DRY -eq 1 ]]; then
    if [[ -L "$LIVE" ]]; then
        if [[ "$(readlink "$LIVE")" == "$SRC" ]]; then
            echo "· $LIVE 已指向仓库配置，无需改动"
        else
            echo "· $LIVE 现指向 $(readlink "$LIVE")，将改为指向 $SRC"
        fi
    elif [[ -f "$LIVE" ]]; then
        echo "· 将备份 $LIVE -> $BACKUP_DIR/config.bak.$TS"
        echo "· 将建立链接: $LIVE -> $SRC"
    else
        echo "· 将建立链接: $LIVE -> $SRC"
    fi
    [[ -f "$LEGACY" ]] && echo "· 将备份并移除覆盖源 $LEGACY"
    for f in "$THEMES_SRC"/*; do
        [[ -f "$f" ]] || continue
        tgt="$THEMES_LIVE/$(basename "$f")"
        if [[ -L "$tgt" && "$(readlink "$tgt")" == "$f" ]]; then
            echo "· $tgt 已指向仓库主题，无需改动"
        else
            echo "· 将建立链接: $tgt -> $f"
        fi
    done
    if [[ -d "$DIR/shaders" ]]; then
        echo "· 将复制着色器: $DIR/shaders/* -> $XDG_DIR/shaders/"
    fi
    echo "--dry: 未改动任何文件"
    exit 0
fi

mkdir -p "$XDG_DIR" "$BACKUP_DIR" "$THEMES_LIVE"

# 1. 备份并移除会覆盖 XDG 配置的旧文件
if [[ -f "$LEGACY" ]]; then
    bk="$BACKUP_DIR/config.ghostty.bak.$TS"
    cp -p "$LEGACY" "$bk"
    rm -f "$LEGACY"
    echo "已备份并移除覆盖源: $bk"
fi

# 2. 备份现有 XDG 配置（若还不是我们的链接）
if [[ -f "$LIVE" && ! -L "$LIVE" ]]; then
    cp -p "$LIVE" "$BACKUP_DIR/config.bak.$TS"
    LAST_BK="$BACKUP_DIR/config.bak.$TS"
    echo "已备份: $LAST_BK"
fi

# 3. 建立链接
ln -sfn "$SRC" "$LIVE"
echo "✅ 已链接: $LIVE -> $SRC"

# 4. 主题文件同样交给仓库管理
for f in "$THEMES_SRC"/*; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    if [[ -f "$THEMES_LIVE/$name" && ! -L "$THEMES_LIVE/$name" ]]; then
        cp -p "$THEMES_LIVE/$name" "$BACKUP_DIR/$name.bak.$TS"
    fi
    ln -sfn "$f" "$THEMES_LIVE/$name"
    echo "✅ 已链接主题: $THEMES_LIVE/$name"
done

# 4b. 着色器：config 里 custom-shader 指向 ~/.config/ghostty/shaders/，这里把仓库里的复制过去
if [[ -d "$DIR/shaders" ]]; then
    mkdir -p "$XDG_DIR/shaders"
    cp -f "$DIR"/shaders/* "$XDG_DIR/shaders/" 2>/dev/null || true
    echo "✅ 已复制着色器: $XDG_DIR/shaders"
fi

echo
verify
echo
echo "在 Ghostty 里按 Cmd+Shift+, 重载配置（字号/字体类改动对新窗口生效）。"
if [[ -n "$LAST_BK" ]]; then
    echo "回滚: cp -p '$LAST_BK' '$LIVE'"
else
    echo "回滚: 本次未生成备份（已是指向仓库的链接）；改坏了用 git -C '$DIR' checkout -- config"
fi
echo "历史备份: ls -1t '$BACKUP_DIR'"
