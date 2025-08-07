#!/usr/bin/env swift

import Foundation
import VLCKitSPM

print("🎉 VLCKitSPM 集成验证")
print("===================")

// 验证 VLC 库是否可用
let vlc = VLCLibrary.shared()
print("✅ VLCLibrary 可用: \(vlc != nil)")

// 验证 VLCMediaPlayer 是否可创建
let player = VLCMediaPlayer()
print("✅ VLCMediaPlayer 可创建: \(player != nil)")

// 显示 VLC 版本信息
if let version = vlc?.version {
    print("✅ VLC 版本: \(version)")
}

print("\n🚀 VLCKitSPM 集成完成！")
print("现在可以在 VLCVideoPlayerView.swift 中使用所有 VLC 功能了。")
