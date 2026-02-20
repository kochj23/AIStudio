//
//  ContentView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var backendManager: BackendManager
    @State private var selectedTab: StudioTab = .images

    enum StudioTab: String, CaseIterable {
        case images = "Images"
        case videos = "Videos"
        case audio = "Audio"
        case chat = "Chat"
        case gallery = "Gallery"

        var icon: String {
            switch self {
            case .images: return "photo.artframe"
            case .videos: return "film"
            case .audio: return "waveform"
            case .chat: return "brain.head.profile"
            case .gallery: return "square.grid.3x3"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ImageGenerationView()
                .tabItem {
                    Label(StudioTab.images.rawValue, systemImage: StudioTab.images.icon)
                }
                .tag(StudioTab.images)

            VideoGenerationView()
                .tabItem {
                    Label(StudioTab.videos.rawValue, systemImage: StudioTab.videos.icon)
                }
                .tag(StudioTab.videos)

            AudioTabView()
                .tabItem {
                    Label(StudioTab.audio.rawValue, systemImage: StudioTab.audio.icon)
                }
                .tag(StudioTab.audio)

            ChatView()
                .tabItem {
                    Label(StudioTab.chat.rawValue, systemImage: StudioTab.chat.icon)
                }
                .tag(StudioTab.chat)

            GalleryView()
                .tabItem {
                    Label(StudioTab.gallery.rawValue, systemImage: StudioTab.gallery.icon)
                }
                .tag(StudioTab.gallery)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? StudioTab {
                selectedTab = tab
            }
        }
    }
}
