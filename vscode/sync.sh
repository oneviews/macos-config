#!/usr/bin/env bash
# 同步本目录的 settings.json 与 VS Code 用户设置
#   ./sync.sh          将本目录 -> VS Code（会先备份现有设置）
#   ./sync.sh push     同上
#   ./sync.sh pull     将 VS Code -> 本目录（在 VS Code 界面里改完后回存）
#   ./sync.sh diff     查看两者差异
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SRC_DIR/settings.json"
DST="$HOME/Library/Application Support/Code/User/settings.json"
TS="$(date +%Y%m%d-%H%M%S)"

validate() {
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" \
        && echo "JSON OK: $1"
}

case "${1:-push}" in
    push)
        [[ -f "$SRC" ]] || { echo "找不到 $SRC" >&2; exit 1; }
        validate "$SRC"
        mkdir -p "$(dirname "$DST")"
        if [[ -f "$DST" ]]; then
            cp -p "$DST" "$DST.bak.$TS"
            echo "已备份: $DST.bak.$TS"
        fi
        cp "$SRC" "$DST"
        echo "已推送: $SRC -> $DST"
        ;;
    pull)
        [[ -f "$DST" ]] || { echo "找不到 $DST" >&2; exit 1; }
        cp -p "$DST" "$SRC"
        validate "$SRC"
        echo "已回存: $DST -> $SRC"
        ;;
    diff)
        diff -u "$SRC" "$DST" || true
        ;;
    *)
        echo "用法: $0 [push|pull|diff]" >&2
        exit 2
        ;;
esac
