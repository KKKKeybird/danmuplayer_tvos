//
//  danmuplayerApp.swift
//  danmuplayer
//
//  Created by keybird on 2025/8/5.
//

import SwiftUI

@main
@available(tvOS 17.0, *)
struct danmuplayerApp: App {
    @StateObject private var mediaLibraryVM = MediaLibraryViewModel()

    var body: some Scene {
        WindowGroup {
            MediaLibraryListView(viewModel: mediaLibraryVM)
        }
    }
}
