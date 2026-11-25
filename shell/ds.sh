#!/usr/bin/env bash
# DeepSeek 一行问答（零安装：只需要 curl + jq）
#
#   ./ds.sh "用一句话解释 APFS"        默认 deepseek-flash，关闭思考，快且便宜
#   ./ds.sh --pro "..."               改用 deepseek-v4-pro（难题）
#   ./ds.sh --think "..."             开启思考模式（会先输出推理再给答案）
#   ./ds.sh --dry "..."               只打印将要发送的请求（key 掩码），不联网
#   ./ds.sh status                    看 key 来源 / 端点连通性 / 可用模型
#
# key 取值顺序：$DEEPSEEK_API_KEY → 钥匙串 deepseek-api
set -euo pipefail

API_CHAT="https://api.deepseek.com/chat/completions"
API_MODELS="https://api.deepseek.com/models"
DEFAULT_MODEL="deepseek-flash"
MAX_TIME=120

MODEL="$DEFAULT_MODEL"
THINK="disabled"
MAX_TOKENS=4096
SYS=""
DRY=0
RAW=0

usage() {
    cat <<'EOF'
用法: ds.sh [选项] "问题"
  --pro                用 deepseek-v4-pro（默认 deepseek-flash）
  --model <id>         自定义模型 ID
  --think              开启思考模式（默认关闭）
  --max-tokens <n>     输出上限，默认 4096
  --system "<文本>"    追加 system 提示
  --dry                只打印请求体（key 掩码），不发送
  --raw                打印完整 JSON 响应
  status               查看 key 来源 / 端点 / 可用模型
  -h | --help          本帮助
EOF
}

mask() {
    local k="$1"
    if [ "${#k}" -le 10 ]; then
        printf '***'
    else
        printf '%s…%s' "${k:0:5}" "${k: -4}"
    fi
}

# 依次尝试三个来源；找不到就返回 1
resolve_key() {
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        KEY="$DEEPSEEK_API_KEY"
        KEY_SRC="环境变量 DEEPSEEK_API_KEY"
        return 0
    fi
    local kc
    kc=$(security find-generic-password -s deepseek-api -w 2>/dev/null || true)
    if [ -n "$kc" ]; then
        KEY="$kc"
        KEY_SRC="钥匙串（service: deepseek-api）"
        return 0
    fi
    return 1
}

cmd_status() {
    echo "ℹ️ 默认模型：${MODEL}（--pro 切 deepseek-v4-pro）"
    if resolve_key; then
        echo "ℹ️ key 来源：${KEY_SRC}"
        echo "ℹ️ key：$(mask "$KEY")（${#KEY} 字符）"
    else
        echo "❌ 没找到 key。二选一："
        echo "   1) export DEEPSEEK_API_KEY=sk-..."
        echo "   2) security add-generic-password -s deepseek-api -a \"\$USER\" -w"
        return 1
    fi
    local code
    code=$(curl -sS -o /tmp/ds-models.json -w '%{http_code}' --max-time 20 \
        -H "Authorization: Bearer ${KEY}" "$API_MODELS") || code="000"
    if [ "$code" = "200" ]; then
        echo "✅ 端点可达：GET $API_MODELS → HTTP 200"
        echo "   可用模型：$(jq -r '[.data[].id] | join(", ")' /tmp/ds-models.json 2>/dev/null || echo '解析失败')"
    else
        echo "❌ 端点异常：GET $API_MODELS → HTTP ${code}"
        return 1
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --pro) MODEL="deepseek-v4-pro"; shift ;;
        --model) MODEL="$2"; shift 2 ;;
        --think) THINK="enabled"; shift ;;
        --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
        --system) SYS="$2"; shift 2 ;;
        --dry) DRY=1; shift ;;
        --raw) RAW=1; shift ;;
        status) cmd_status; exit $? ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) echo "❌ 未知选项：$1" >&2; usage >&2; exit 2 ;;
        *) break ;;
    esac
done

[ $# -ge 1 ] || { usage >&2; exit 2; }
QUESTION="$*"

if ! resolve_key; then
    echo "❌ 没找到 DeepSeek API key：跑 './ds.sh status' 看三种配置方式" >&2
    exit 1
fi

BODY=$(jq -n \
    --arg model "$MODEL" \
    --arg sys "$SYS" \
    --arg q "$QUESTION" \
    --arg think "$THINK" \
    --argjson max "$MAX_TOKENS" \
    'def msgs: (if $sys != "" then [{role: "system", content: $sys}] else [] end)
              + [{role: "user", content: $q}];
     {model: $model, messages: msgs, thinking: {type: $think},
      max_tokens: $max, stream: false}')

if [ "$DRY" = "1" ]; then
    echo "ℹ️ key 来源：${KEY_SRC}（$(mask "$KEY")）"
    echo "ℹ️ POST ${API_CHAT}"
    printf '%s\n' "$BODY" | jq .
    exit 0
fi

RESP=$(mktemp -t ds)
trap 'rm -f "$RESP"' EXIT
code=$(curl -sS -o "$RESP" -w '%{http_code}' --max-time "$MAX_TIME" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${KEY}" \
    -d "$BODY" "$API_CHAT") || code="000"

if [ "$code" != "200" ]; then
    echo "❌ HTTP ${code}" >&2
    head -c 600 "$RESP" >&2
    echo >&2
    exit 1
fi

if [ "$RAW" = "1" ]; then
    cat "$RESP"
    exit 0
fi

content=$(jq -r '.choices[0].message.content // empty' "$RESP")
if [ -z "$content" ]; then
    content=$(jq -r '.choices[0].message.reasoning_content // "(空响应)"' "$RESP")
fi
printf '%s\n' "$content"

# —— 用量与估价（低峰/高峰按 UTC 工作日 01-04、06-10 判定；中国法定节假日未计入）——
hit=$(jq -r '.usage.prompt_cache_hit_tokens // 0' "$RESP")
miss=$(jq -r '.usage.prompt_cache_miss_tokens // .usage.prompt_tokens // 0' "$RESP")
out=$(jq -r '.usage.completion_tokens // 0' "$RESP")
dow=$(date -u +%u)
hh=$(date -u +%H)
hh=${hh#0}
[ -n "$hh" ] || hh=0
peak=0
if [ "$dow" -le 5 ]; then
    if { [ "$hh" -ge 1 ] && [ "$hh" -lt 4 ]; } || { [ "$hh" -ge 6 ] && [ "$hh" -lt 10 ]; }; then
        peak=1
    fi
fi
cost=$(awk -v h="$hit" -v m="$miss" -v o="$out" -v p="$peak" -v md="$MODEL" 'BEGIN {
    if (md ~ /pro/) { ch = 0.022; cm = 0.66; co = 1.98 } else { ch = 0.003; cm = 0.15; co = 0.6 }
    if (p) { ch *= 2; cm *= 2; co *= 2 }
    printf "%.6f", (h * ch + m * cm + o * co) / 1000000
}')
tier="低峰"
[ "$peak" = "1" ] && tier="高峰"
echo "ℹ️ ${MODEL} | 输入 ${miss}（缓存命中 ${hit}）+ 输出 ${out} tokens | 约 \$${cost}（${tier}价）"
