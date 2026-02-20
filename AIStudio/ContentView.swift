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
        case gallery = "Gallery"

        var icon: String {
            switch self {
            case .images: return "photo.artframe"
            case .videos: return "film"
            case .audio: return "waveform"
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

            PlaceholderTab(title: "Video Generation", icon: StudioTab.videos.icon, description: "Coming in Phase 3")
                .tabItem {
                    Label(StudioTab.videos.rawValue, systemImage: StudioTab.videos.icon)
                }
                .tag(StudioTab.videos)

            PlaceholderTab(title: "Audio Studio", icon: StudioTab.audio.icon, description: "Coming in Phase 4")
                .tabItem {
                    Label(StudioTab.audio.rawValue, systemImage: StudioTab.audio.icon)
                }
                .tag(StudioTab.audio)

            PlaceholderTab(title: "Gallery", icon: StudioTab.gallery.icon, description: "Coming in Phase 5")
                .tabItem {
                    Label(StudioTab.gallery.rawValue, systemImage: StudioTab.gallery.icon)
                }
                .tag(StudioTab.gallery)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct PlaceholderTab: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title)
                .fontWeight(.semibold)
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
