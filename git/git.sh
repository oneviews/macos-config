#!/usr/bin/env bash
# 把本目录的 git 全局配置部署到 ~/.config/git/，并验证各目录实际生效的身份
#
#   ./git.sh                      部署（默认）
#   ./git.sh --dry                只打印将要做的事
#   ./git.sh status               部署状态 + 各目录生效身份
#   ./git.sh test <目录>          打印该目录实际使用的作者身份
#   ./git.sh set-identity "名字" "邮箱"   写入 ~/project 的身份后重新部署
#
# 机制：~/.config/git/config 里用 includeIf "gitdir:<目录>/" 指向对应的身份文件，
#       分别指向两份身份文件，因此不必在每个仓库里再配 user.name/user.email。
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/git"
TS="$(date +%Y%m%d-%H%M%S)"
DRY=0

# 源文件 -> 目标文件（同名）
MAP=(
    "gitconfig:config"
    "ignore:ignore"
    "identity.work.gitconfig:identity.work.gitconfig"
    "identity.project.gitconfig:identity.project.gitconfig"
)

ident_of() {
    local d="$1"
    [[ -d "${d}" ]] || { echo "（目录不存在）"; return 0; }
    local out local_mail=""
    out="$(git -C "${d}" var GIT_AUTHOR_IDENT 2>/dev/null || true)"
    local_mail="$(git -C "${d}" config --local --get user.email 2>/dev/null || true)"
    if [[ -z "${out}" ]]; then
        echo "⚠️  未设置（提交时会报错）"
    elif [[ -n "${local_mail}" ]]; then
        echo "${out% * *}（仓库级覆盖：${local_mail}）"
    else
        echo "${out% * *}"
    fi
}

status() {
    echo "目标目录: ${TARGET}"
    echo
    echo "部署状态:"
    local s t name
    for pair in "${MAP[@]}"; do
        s="${DIR}/${pair%%:*}"
        t="${TARGET}/${pair##*:}"
        if [[ ! -f "${t}" ]]; then
            printf '  ⚠️  %-34s 未部署\n' "${pair##*:}"
        elif cmp -s "${s}" "${t}"; then
            printf '  ✅ %-34s 一致\n' "${pair##*:}"
        else
            printf '  ❌ %-34s 与源不同（重新 ./git.sh 同步）\n' "${pair##*:}"
        fi
    done
    echo
    echo "生效身份:"
    local sample
    sample="$(find "${HOME}/project" -maxdepth 2 -type d -name .git 2>/dev/null | head -1 | sed 's|/.git$||' || true)"
    for d in "${sample}" "${HOME}/Work"; do
        [[ -n "${d}" && -d "${d}" ]] || continue
        printf '  %-34s %s\n' "${d/#${HOME}/~}" "$(ident_of "${d}")"
    done
    printf '  %-34s %s\n' "/tmp（未命中 includeIf）" "$(ident_of /tmp)"
    echo
    if [[ -f "${HOME}/.gitconfig" ]]; then
        echo "⚠️  检测到 ~/.gitconfig：它的优先级高于 XDG 配置，可能覆盖本配置"
    fi
    if ! grep -qE '^[[:space:]]*email[[:space:]]*=' "${TARGET}/identity.project.gitconfig" 2>/dev/null; then
        echo "ℹ️  ~/project 身份未填写 → ./git.sh set-identity \"名字\" \"邮箱\""
    fi
}

case "${1:-apply}" in
    apply|"") ;;
    --dry|dry) DRY=1 ;;
    status) status; exit 0 ;;
    test)
        [[ -n "${2:-}" ]] || { echo "用法: $0 test <目录>" >&2; exit 2; }
        ident_of "$2"; exit 0 ;;
    set-identity)
        [[ -n "${2:-}" && -n "${3:-}" ]] || { echo "用法: $0 set-identity \"名字\" \"邮箱\"" >&2; exit 2; }
        [[ "$3" == *@* && "$3" != *" "* ]] || { echo "❌ 邮箱格式不对: $3" >&2; exit 1; }
        {
            echo "# ~/project 下的所有仓库（含公开仓库）使用这一份身份。"
            echo "# 由 git.sh set-identity 生成；手动改完再执行 ./git.sh 也能生效。"
            echo "[user]"
            echo "    name = $2"
            echo "    email = $3"
        } > "${DIR}/identity.project.gitconfig"
        echo "✅ 已写入身份: $2 <$3>"
        ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "❌ 未知参数: $1" >&2; exit 2 ;;
esac

mkdir -p "${TARGET}"
for pair in "${MAP[@]}"; do
    s="${DIR}/${pair%%:*}"
    t="${TARGET}/${pair##*:}"
    if [[ ! -f "${s}" ]]; then
        echo "❌ 源文件缺失: ${s}" >&2
        exit 1
    fi
    if [[ ${DRY} -eq 1 ]]; then
        if [[ -f "${t}" ]] && cmp -s "${s}" "${t}"; then
            echo "· ${t} 已一致"
        else
            echo "· 将写入 ${t}"
        fi
        continue
    fi
    if [[ -f "${t}" ]] && cmp -s "${s}" "${t}"; then
        echo "✅ ${t} 已一致"
        continue
    fi
    if [[ -f "${t}" ]]; then
        cp -p "${t}" "${t}.bak.${TS}"
        echo "ℹ️  已备份 ${t}.bak.${TS}"
    fi
    cp -p "${s}" "${t}"
    echo "✅ 已写入 ${t}"
done

[[ ${DRY} -eq 1 ]] && { echo; echo "ℹ️  --dry：未改动磁盘"; exit 0; }

echo
status
echo
echo "回滚: cp -p '${TARGET}/<文件>.bak.${TS}' '${TARGET}/<文件>'"
