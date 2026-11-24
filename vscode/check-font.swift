#!/usr/bin/env swift
// 校验字体是否已被 macOS 正确注册（VS Code / 终端等应用能否解析到该字体族）
// 用法: xcrun swift check-font.swift ["Maple Mono NF CN"]
import AppKit

let target = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Maple Mono NF CN"
let mgr = NSFontManager.shared
let families = mgr.availableFontFamilies.filter { $0.lowercased().contains(target.lowercased()) }

guard !families.isEmpty else {
    print("❌ 系统字体库中没有匹配 '\(target)' 的字体族")
    print("   排查顺序：")
    print("   1) 文件是否在 ~/Library/Fonts:  ls ~/Library/Fonts | grep -i <name>")
    print("   2) 是否带 quarantine（下载来的字体常见，会导致不自动装入）:")
    print("      xattr -l ~/Library/Fonts/<file>.ttf")
    print("   3) 修复并让 fontd 重新扫描:")
    print("      xattr -d com.apple.quarantine ~/Library/Fonts/*.ttf && killall fontd")
    exit(1)
}

for fam in families {
    let members = (mgr.availableMembers(ofFontFamily: fam) ?? []).compactMap { $0.first as? String }
    print("✅ 字体族: \(fam)   字形数: \(members.count)")
    for m in members.prefix(4) { print("   - \(m)") }
}

if let f = NSFont(name: target, size: 18) {
    print("✅ NSFont 解析成功: \(f.fontName) (family=\(f.familyName ?? "-"), ascent=\(f.ascender))")
} else {
    print("⚠️ 字体族可见但 NSFont(name:) 未解析，请检查族名拼写")
}
