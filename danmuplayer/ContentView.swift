//
//  ContentView.swift
//  danmuplayer
//
//  Created by keybird on 2025/8/5.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "tv")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("弹幕播放器")
                .font(.title)
            Text("支持WebDAV和弹弹Play API")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
