// 校验 Ghostty 的 font-style 查找依据：某个字体族是否「对外宣称」了指定样式名，
// 以及 CoreText 最终解析到哪个 PostScript 名。
//
//   xcrun swift ghostty/check-font-style.swift
//   xcrun swift ghostty/check-font-style.swift "Maple Mono NF CN"
import Foundation
import CoreText

let family = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Maple Mono NF CN"
let styles = ["Regular", "Italic", "Bold", "Bold Italic"]

print("字体族: \(family)")
var ok = false
for style in styles {
    let attrs: [CFString: Any] = [
        kCTFontFamilyNameAttribute: family,
        kCTFontStyleNameAttribute: style,
    ]
    let desc = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(desc, 12, nil)
    let ps = CTFontCopyPostScriptName(font) as String
    let resolvedFamily = CTFontCopyFamilyName(font) as String
    let match = resolvedFamily == family
    if match { ok = true }
    print("  style=\(style.padding(toLength: 12, withPad: " ", startingAt: 0)) -> \(ps)\(match ? "" : "   ⚠️ 未匹配到该族")")
}

if ok {
    print("✅ 该族支持按样式名查找（Ghostty 的 font-style 才能生效）")
} else {
    print("❌ 该族找不到任何匹配样式；请用 ghostty +list-fonts 查看真实族名")
    exit(1)
}
