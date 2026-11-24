#!/usr/bin/env bash
# 把 complex-modifications.json（单条规则）合并进 Karabiner-Elements 当前选中的 profile
#   同名规则（按 description 判断）会被替换，因此可重复执行
#
#   ./install.sh          合并到 ~/.config/karabiner/karabiner.json
#   ./install.sh --dry    只打印将要发生的变化，不写入
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/complex-modifications.json"
LIVE="$HOME/.config/karabiner/karabiner.json"
DRY=0
[[ "${1:-}" == "--dry" ]] && DRY=1

command -v jq >/dev/null 2>&1 || { echo "❌ 需要 jq（brew install jq）" >&2; exit 1; }
[[ -f "$SRC" ]] || { echo "❌ 找不到规则文件: $SRC" >&2; exit 1; }
[[ -f "$LIVE" ]] || { echo "❌ 找不到 Karabiner 配置: ${LIVE}（先安装并运行 Karabiner-Elements）" >&2; exit 1; }

DESC="$(jq -r '.description // empty' "$SRC")"
[[ -n "$DESC" ]] || { echo "❌ 规则缺少 description 字段" >&2; exit 1; }

echo "规则: $DESC"
echo "目标: $LIVE"
echo "选中 profile 现有规则数: $(jq '[.profiles[] | select(.selected==true) | .complex_modifications.rules // []] | add | length' "$LIVE")"

if [[ $DRY -eq 1 ]]; then
    jq --slurpfile new "$SRC" --arg d "$DESC" '
        .profiles |= map(
            if .selected == true then
                .complex_modifications.rules = (((.complex_modifications.rules // []) | map(select(.description != $d))) + $new)
            else . end)
        | [.profiles[] | select(.selected==true) | .complex_modifications.rules[] | .description]
    ' "$LIVE"
    echo "--dry: 未写入"
    exit 0
fi

BK="$LIVE.bak.$(date +%Y%m%d-%H%M%S)"
cp -p "$LIVE" "$BK"
echo "已备份: $BK"

tmp="$(mktemp)"
jq --slurpfile new "$SRC" --arg d "$DESC" '
    .profiles |= map(
        if .selected == true then
            .complex_modifications.rules = (((.complex_modifications.rules // []) | map(select(.description != $d))) + $new)
        else . end)
' "$LIVE" > "$tmp"

# 写入前做结构校验：必须仍有 selected profile 且规则数 >= 1
if ! jq -e '[.profiles[] | select(.selected==true)] | length >= 1' "$tmp" >/dev/null; then
    echo "❌ 合并结果校验失败，未写入（原文件未改动）" >&2
    rm -f "$tmp"
    exit 1
fi

fmt_ok=$(jq -e 'type == "object"' "$tmp" >/dev/null 2>&1 && echo yes || echo no)
if [[ "$fmt_ok" != "yes" ]]; then
    echo "❌ 生成的文件不是合法 JSON，未写入" >&2
    rm -f "$tmp"
    exit 1
fi

cat "$tmp" > "$LIVE"   # 用重定向写入，保留原文件权限与属主
rm -f "$tmp"
chmod 600 "$LIVE" 2>/dev/null || true

echo "✅ 已写入。当前选中 profile 的规则:"
jq -r '.profiles[] | select(.selected==true) | .complex_modifications.rules[] | "  - " + (.description // "(无描述)")' "$LIVE"
echo
echo "Karabiner-Elements 会自动重载配置；若未生效，在它的界面里点一次 profile 即可。"
echo "回滚: cp -p '$BK' '$LIVE'"
