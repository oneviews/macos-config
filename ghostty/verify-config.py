#!/usr/bin/env python3
"""逐键对照：仓库里的 config 写的值 vs Ghostty 实际解析出来的值。

为什么需要它：`+validate-config` 对未知键静默放行（故意写错键名仍 exit 0），
所以"改了等于没改"只能靠 `+show-config` 反向核对。

判定分三类：
  ✅ 生效       show-config 里的值与写的一致（且不等于默认值 → 确实起作用）
  ⚪ 等于默认值  写的就是默认值，输出里因此看不到；幂等无害（自解释用）
  ❌ 未生效     写了但 show-config 里查不到、且不等于默认值 → 真的写错了

用法：
  ./verify-config.py          # 人类可读
  ./verify-config.py -q       # 只报 ❌，供 CI / 快速体检用
退出码：0 = 无 ❌；1 = 有 ❌；2 = 找不到 Ghostty CLI
"""

from __future__ import annotations

import os
import subprocess
import sys

GHOSTTY = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config")

# 同一个值的不同写法（Ghostty 会把别名规范化后再输出）
ALIASES = {
    "window-theme": {"auto": "system", "system": "system"},
}

# 值会被 Ghostty 展开成绝对路径的键：配置里写 ~/…，+show-config 输出 /Users/…
PATH_KEYS = {"custom-shader", "background-image", "macos-custom-icon"}


def norm(key: str, value: str) -> str:
    v = value.strip().strip('"').strip("'")
    v = ALIASES.get(key, {}).get(v, v)
    if key in PATH_KEYS:
        v = os.path.expanduser(v)
    try:
        return str(float(v))  # 0.80 == 0.8
    except ValueError:
        return v


def load_pairs(path: str) -> list[tuple[str, str]]:
    pairs = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or "=" not in s:
                continue
            k, v = s.split("=", 1)
            pairs.append((k.strip(), v.strip()))
    return pairs


def show(flag: str) -> dict[str, list[str]]:
    out = subprocess.run([GHOSTTY, "+show-config", *([flag] if flag else [])],
                         capture_output=True, text=True).stdout
    res: dict[str, list[str]] = {}
    for line in out.splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            res.setdefault(k.strip(), []).append(v.strip())
    return res


def main() -> int:
    if not os.access(GHOSTTY, os.X_OK):
        print(f"找不到 Ghostty CLI: {GHOSTTY}", file=sys.stderr)
        return 2

    quiet = "-q" in sys.argv
    pairs = load_pairs(CONFIG)
    configs = [(k, v) for k, v in pairs if k != "keybind"]
    keybinds = [p for p in pairs if p[0] == "keybind"]

    effective = show("")
    defaults = show("--default")

    live, same_as_default, broken = [], [], []
    for k, v in configs:
        got = [norm(k, x) for x in effective.get(k, [])]
        want = norm(k, v)
        if want in got:
            live.append((k, v))
        elif k in defaults and want in [norm(k, x) for x in defaults[k]]:
            same_as_default.append((k, v))
        else:
            broken.append((k, v, ", ".join(effective.get(k, ["(未输出)"]))))

    print(f"配置项（不含 keybind）: {len(configs)}")
    print(f"  ✅ 生效            : {len(live)}")
    print(f"  ⚪ 等于默认值（无害）: {len(same_as_default)}")
    print(f"  ❌ 未生效/值不符    : {len(broken)}")
    print(f"keybind: {len(keybinds)} 条自定义（show-config 输出 {len(effective.get('keybind', []))} 行 = 内建 + 自定义）")

    if not quiet and same_as_default:
        print("\n显式写出默认值（想精简可删，留着当文档也行）：")
        for k, v in same_as_default:
            print(f"  ⚪ {k} = {v}")

    if broken:
        print("\n以下配置写了但没有对应的生效值，请核对键名/取值：")
        for k, v, got in broken:
            print(f"  ❌ {k} = {v}   → show-config: {got}")

    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
