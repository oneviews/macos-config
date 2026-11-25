#!/usr/bin/env bash
# cmds —— 综合查看「我们定义的命令」与「安装的软件带来的命令」
#
# 用法：
#   cmds                  # 总览：别名 + 函数 + 直接安装的软件 + GUI 应用
#   cmds aliases          # 只看别名
#   cmds funcs            # 只看函数
#   cmds tools            # 只看软件命令（默认只列 brew leaves）
#   cmds tools --all      # 含依赖库提供的命令（icu4c / xz 等，会比较长）
#   cmds casks            # 只看 GUI 应用
#   cmds --no-color       # 关颜色（管道里会自动关）
#
# 数据来源（全部只读）：
#   ~/.zshrc / shell/aliases.zsh       我们定义的别名
#   shell/px.zsh                       我们定义的函数（px：外观 / DeepSeek 问答）
#   brew list --formula / brew leaves  软件命令（leaves = 直接安装）
#   brew info --json=v2 --installed    版本与描述（一次调用，约 0.5s）
#   brew list --cask                   GUI 应用
set -euo pipefail
shopt -s nullglob

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
ZSHRC="$HOME/.zshrc"
ALIASES="$DIR/aliases.zsh"
PX="$DIR/px.zsh"

COLOR=1
ALL=0
FILTER=all

usage() {
    cat <<'EOF'
用法: cmds [aliases|funcs|tools|casks|all] [--all] [--no-color]

  (无参数)      别名 + 函数 + 直接安装的软件 + GUI 应用
  aliases       只看别名（含全局别名）
  funcs         只看我们定义的函数
  tools         只看软件带来的命令
  tools --all   连依赖库提供的命令一起列（icu4c / xz 等）
  casks         只看 GUI 应用

数据来自 ~/.zshrc、shell/*.zsh、brew；只读，不改任何文件。
EOF
}

for arg in "$@"; do
    case "$arg" in
        aliases|alias) FILTER=aliases ;;
        funcs|functions) FILTER=funcs ;;
        tools|software) FILTER=tools ;;
        casks|apps|gui) FILTER=casks ;;
        all) FILTER=all ;;
        --all) ALL=1 ;;
        --no-color) COLOR=0 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "❌ 未知参数: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$COLOR" = 1 ] && [ -t 1 ]; then
    B=$'\033[1m'; D=$'\033[2m'; C=$'\033[36m'; G=$'\033[32m'; N=$'\033[0m'
else
    B=''; D=''; C=''; G=''; N=''
fi

h1() { printf '\n%s%s%s\n' "$B$C" "$1" "$N"; }
h2() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }

TMP=$(mktemp)
DEDUP=$(mktemp)
trap 'rm -f "$TMP" "$DEDUP"' EXIT

# ---------- 1) 我们定义的别名 ----------
collect_aliases() { # $1=file  $2=默认分组
    local file="$1" group="$2" line rest name val kind
    if [ ! -f "$file" ]; then
        return 0
    fi
    while IFS= read -r line; do
        case "$line" in
            '# --- '*)
                group=${line#'# --- '}
                group=${group%% ---*}
                group=${group%%（*}
                continue
                ;;
            'alias -g '*) rest=${line#alias -g }; kind=global ;;
            'alias -- '*) rest=${line#alias -- }; kind=normal ;;
            'alias '*)    rest=${line#alias };    kind=normal ;;
            *) continue ;;
        esac
        name=${rest%%=*}
        val=${rest#*=}
        val=${val%% # *}                              # 去掉行尾注释
        val=${val%"${val##*[![:space:]]}"}            # 去掉注释前残留的空格
        val=${val#\"}; val=${val%\"}
        val=${val#\'}; val=${val%\'}
        printf '%s\t%s\t%s\t%s\n' "$group" "$name" "$val" "$kind"
    done < "$file"
}

collect_aliases "$ZSHRC" "基础" > "$TMP"
collect_aliases "$ALIASES" "" >> "$TMP"

# 同名以「后出现」为准（与 zsh 一致），但保留原有分组顺序
awk -F'\t' '
    { line[NR]=$0; key[NR]=$2 }
    END {
        for (i=NR; i>=1; i--) {
            if (!(key[i] in seen)) { seen[key[i]]=1; out[++n]=i }
        }
        for (j=n; j>=1; j--) print line[out[j]]
    }
' "$TMP" > "$DEDUP"

print_aliases() {
    local g n v k last=""
    h2 "[我们定义的别名]  $(wc -l < "$DEDUP" | tr -d ' ') 条"
    while IFS=$'\t' read -r g n v k; do
        if [ -z "$g" ]; then
            g="其它"
        fi
        if [ "$g" != "$last" ]; then
            printf '\n  %s%s%s\n' "$D" "$g" "$N"
            last="$g"
        fi
        printf '    %s%-14s%s %s' "$G" "$n" "$N" "$v"
        if [ "$k" = global ]; then
            printf '  %s(全局)%s' "$D" "$N"
        fi
        printf '\n'
    done < "$DEDUP"
}

# ---------- 2) 我们定义的函数 ----------
print_funcs() {
    h2 "[我们定义的函数]"
    printf '    %s%-14s%s %s\n' "$G" "px" "$N" "外观切换 + DeepSeek 问答（代理部分不含）"
    printf '    %s%-14s%s %s\n' "$G" "cmds" "$N" "本命令：别名 / 函数 / 软件命令总览"
}

# ---------- 3) 软件带来的命令 ----------
TOOL_COUNT=0
DEP_COUNT=0
LEAF_COUNT=0
META=""
CASKS_META=""
LEAVES_FILE=""

# 一次 brew info 拿全量元数据（约 0.5s）；jq 缺失时降级为只列名字
load_brew_meta() {
    command -v brew >/dev/null 2>&1 || return 1
    command -v jq  >/dev/null 2>&1 || return 1
    local info
    META=$(mktemp)
    CASKS_META=$(mktemp)
    info=$(mktemp)
    trap 'rm -f "$TMP" "$DEDUP" "${META:-}" "${CASKS_META:-}" "${LEAVES_FILE:-}"' EXIT
    brew info --json=v2 --installed > "$info" 2>/dev/null || true
    if [ -s "$info" ]; then
        jq -r '.formulae[] | [.name, .versions.stable, (.desc // ""), ((.dependencies // []) | join(","))] | @tsv' \
            "$info" > "$META" 2>/dev/null || true
        jq -r '.casks[] | [.token, (((.name // [])[0]) // .token), (.desc // "")] | @tsv' \
            "$info" > "$CASKS_META" 2>/dev/null || true
    fi
    rm -f "$info"
    [ -s "$META" ]
}

print_tools() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "⚠️ 未找到 Homebrew，跳过软件命令"
        return 0
    fi
    if [ ! -s "${META:-}" ] && ! load_brew_meta; then
        echo "⚠️ 需要 jq 才能读取 brew 元数据（brew info --json）"
        return 0
    fi

    local prefix f ver desc deps d p bins is_leaf tag dep_names=""
    prefix=$(brew --prefix)

    # leaves = 没有被其它已装 formula 依赖的 formula（等价 brew leaves，省一次调用）
    LEAVES_FILE=$(mktemp)
    awk -F'\t' '
        FNR==NR { n=split($4,a,","); for(i=1;i<=n;i++) if(a[i]!="") dep[a[i]]=1; next }
        { if (!($1 in dep)) print $1 }
    ' "$META" "$META" > "$LEAVES_FILE"
    LEAF_COUNT=$(sed '/^$/d' "$LEAVES_FILE" | wc -l | tr -d ' ')

    h2 "[安装的软件带来的命令]"
    while IFS=$'\t' read -r f ver desc deps; do
        bins=""
        for d in bin sbin; do
            for p in "$prefix/opt/$f/$d/"*; do
                if [ -e "$p" ]; then
                    bins="$bins $(basename "$p")"
                fi
            done
        done
        if [ -z "${bins// /}" ]; then
            continue
        fi

        is_leaf=0
        if grep -qx -- "$f" "$LEAVES_FILE"; then
            is_leaf=1
        fi

        if [ "$is_leaf" = 0 ] && [ "$ALL" = 0 ]; then
            DEP_COUNT=$((DEP_COUNT + 1))
            dep_names="$dep_names $f"
            continue
        fi

        TOOL_COUNT=$((TOOL_COUNT + 1))
        if [ "$is_leaf" = 1 ]; then
            tag="${G}直接安装${N}"
        else
            tag="${D}依赖${N}"
        fi

        printf '  %s●%s %-12s %-9s %s\n' "$G" "$N" "$f" "$ver" "$tag"
        if [ -n "$desc" ]; then
            printf '     %s%s%s\n' "$D" "$desc" "$N"
        fi
        printf '     命令: %s\n' "${bins# }"
        case "$f" in
            zoxide) printf '     函数: z / zi（由 zoxide init zsh 注入）\n' ;;
            fzf) printf '     绑定: Ctrl+R 历史 / Ctrl+T 文件（Alt+C 需 macos-option-as-alt）\n' ;;
        esac
    done < <(sort -t$'\t' -k1,1 "$META")

    if [ "$ALL" = 0 ] && [ "$DEP_COUNT" -gt 0 ]; then
        printf '\n  %s另有 %d 个依赖库提供命令（%s）\n  用 cmds tools --all 查看%s\n' \
            "$D" "$DEP_COUNT" "${dep_names# }" "$N"
    fi
}

# ---------- 4) GUI 应用 ----------
CASK_COUNT=0

print_casks() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "⚠️ 未找到 Homebrew，跳过 GUI 应用"
        return 0
    fi
    if [ -z "${CASKS_META:-}" ] && ! load_brew_meta; then
        echo "⚠️ 需要 jq 才能读取 cask 元数据（brew info --json）"
        return 0
    fi

    local c name desc extra
    CASK_COUNT=$(sed '/^$/d' "$CASKS_META" | wc -l | tr -d ' ')
    h2 "[GUI 应用（cask）]  $CASK_COUNT 个"
    while IFS=$'\t' read -r c name desc; do
        extra=""
        case "$c" in
            visual-studio-code) extra="CLI: code（$(command -v code 2>/dev/null || echo 未找到)）" ;;
            ghostty) extra="CLI: /Applications/Ghostty.app/Contents/MacOS/ghostty（+动作，不在 PATH）" ;;
            font-*) extra="字体（无 CLI）" ;;
        esac
        printf '  %-26s %s\n' "$c" "$extra"
    done < <(sort -t$'\t' -k1,1 "$CASKS_META")
}

# ---------- 输出 ----------
print_header() {
    printf '%sℹ️  Work 命令总览%s  %s\n' "$B$C" "$N" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s仓库: %s%s\n' "$D" "$ROOT" "$N"
}

case "$FILTER" in
    aliases) print_aliases ;;
    funcs) print_funcs ;;
    tools) print_header; print_tools ;;
    casks) print_casks ;;
    all)
        print_header
        print_aliases
        print_funcs
        print_tools
        print_casks
        h1 "统计"
        printf '  别名 %s 条 · 函数 2 个 · 直接安装的 formula %s 个 · GUI 应用 %s 个\n' \
            "$(wc -l < "$DEDUP" | tr -d ' ')" "$LEAF_COUNT" "$CASK_COUNT"
        ;;
esac


