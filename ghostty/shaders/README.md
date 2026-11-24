# Ghostty 自定义着色器

## 当前启用

| 文件 | 效果 | 来源 |
| --- | --- | --- |
| `cursor_warp.glsl` | Neovide 风格光标拖尾 | [sahaj-b/cursor-shaders](https://github.com/sahaj-b/cursor-shaders)（MIT，许可证见 `LICENSE.cursor-shaders`） |

对应 `../config` 中的两行：

```ini
custom-shader = ~/.config/ghostty/shaders/cursor_warp.glsl
custom-shader-animation = true
```

## 调参

`cursor_warp.glsl` 顶部是常量，直接改数值即可（改完在 Ghostty 里按 `Cmd+Shift+,`）：

| 常量 | 作用 |
| --- | --- |
| `DURATION` | 拖尾总时长（秒） |
| `TRAIL_SIZE` | 0 = 四角同步移动；1 = 最大拖尾（前角瞬移） |
| `THRESHOLD_MIN_DISTANCE` | 触发拖尾的最小移动距离（单位：光标高度） |
| `TRAIL_THICKNESS` / `TRAIL_THICKNESS_X` | 拖尾粗细（1.0 = 与光标同高） |
| `FADE_ENABLED` / `FADE_EXPONENT` | 沿拖尾渐隐 |
| `TRAIL_COLOR` | 默认取 `iCurrentCursorColor`，跟随主题换色 |

## 同仓库其他 shader（未入库，按需复制）

`cursor_sweep.glsl`（收缩）、`cursor_tail.glsl`（kitty 彗尾）、
`ripple_cursor.glsl` / `ripple_rectangle_cursor.glsl`（脉冲环）、
`sonic_boom_cursor.glsl` / `rectangle_boom_cursor.glsl`（爆开）。
脉冲类在失焦时会冻结，需要 `custom-shader-animation = always`。

## 风险与回滚

- shader 编译错误**不会**让 `+validate-config` 报错，只写进 Ghostty 日志；
- 官方警告：无效 shader 可能让窗口全黑 → 注释掉 `custom-shader` 那一行即可恢复；
- 带 `custom-shader-animation = true` 时，官方给的 CPU 量级是「generally less than 10%」，
  且只对聚焦的终端生效；
- 多条 `custom-shader` 会按顺序叠加（前一条的输出进 `iChannel0`），别一次堆三个 CRT。
- 回滚：删掉 `../config` 里的 `custom-shader` / `custom-shader-animation` 两行，
  或 `git checkout -- ghostty/config`。
