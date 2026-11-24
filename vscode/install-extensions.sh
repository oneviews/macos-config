#!/usr/bin/env bash
# 按 extensions.txt 安装 VS Code 扩展（幂等：已装则跳过/覆盖升级）
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="${1:-$DIR/extensions.txt}"

command -v code >/dev/null 2>&1 || { echo "❌ 找不到 code 命令：在 VS Code 里执行 Shell Command: Install 'code' command in PATH" >&2; exit 1; }
[[ -f "$FILE" ]] || { echo "❌ 找不到扩展清单：$FILE" >&2; exit 1; }

installed="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
ok=0; skip=0; bad=0

while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    id="${line%@*}"
    if grep -qx "$(echo "$id" | tr '[:upper:]' '[:lower:]')" <<< "$installed"; then
        echo "  ⏭  已安装 $id"
        skip=$((skip + 1))
        continue
    fi
    if code --install-extension "$id" --force >/dev/null 2>&1; then
        echo "  ✅ 已安装 $id"
        ok=$((ok + 1))
    else
        echo "  ❌ 安装失败 $id"
        bad=$((bad + 1))
    fi
done < "$FILE"

echo "完成：新装 ${ok}，已存在 ${skip}，失败 ${bad}"
[[ $bad -eq 0 ]] || exit 1
