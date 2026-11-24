#!/usr/bin/env bash
# 泄漏自检：纯静态正则扫描，不联网、不改文件。
#
#   ./scripts/secret-scan.sh            # 扫本仓库（脚本所在目录的上一级）
#   ./scripts/secret-scan.sh <目录>     # 扫指定目录
#
# 退出码：0 = 干净；1 = 有命中（CI 用它把门）
set -euo pipefail

DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[[ -d "${DIR}" ]] || { echo "❌ 目录不存在: ${DIR}" >&2; exit 1; }

# 回环地址允许出现（文档里的示例）
ALLOW='^(.*)(127\.0\.0\.1|0\.0\.0\.0)(.*)$'

PATTERNS=(
    '([0-9]{1,3}\.){3}[0-9]{1,3}'
    '/Users/[A-Za-z]'
    'macmini'
    '~/Work'
    'sk-[A-Za-z0-9_-]{16,}'
    'gh[pousr]_[A-Za-z0-9]{20,}'
    'xox[baprs]-[A-Za-z0-9-]{10,}'
    'BEGIN [A-Z ]*PRIVATE KEY'
    '(ss|vmess|vless|trojan|hysteria2?)://'
    'outline\.ya?ml|sslinkers'
    'apple@'
)

hits=0
for pat in "${PATTERNS[@]}"; do
    # 排除 .git、本脚本自身、以及许可证文本
    out="$(grep -rInE --binary-files=without-match \
        --exclude-dir=.git --exclude=secret-scan.sh --exclude=LICENSE* \
        -- "${pat}" "${DIR}" 2>/dev/null || true)"
    [[ -z "${out}" ]] && continue
    # IP 那条：放过回环地址所在行
    if [[ "${pat}" == '([0-9]{1,3}\.){3}[0-9]{1,3}' ]]; then
        out="$(printf '%s\n' "${out}" | grep -Ev "${ALLOW}" || true)"
        [[ -z "${out}" ]] && continue
    fi
    echo "❌ 命中模式 ${pat}:" >&2
    printf '%s\n' "${out}" | sed 's|^|   |' >&2
    hits=$((hits + 1))
done

echo
if [[ ${hits} -gt 0 ]]; then
    echo "❌ 自检失败：${hits} 类模式命中（见上）" >&2
    exit 1
fi
echo "✅ 自检通过：未发现 IP / 个人路径 / 密钥 / 订阅链接样式"
