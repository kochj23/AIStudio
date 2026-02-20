//
//  VideoPreviewView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL?
    let isGenerating: Bool

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            if isGenerating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Generating video...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if let _ = videoURL, let player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No video generated yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Requires ComfyUI with AnimateDiff installed")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .onChange(of: videoURL) { _, newURL in
            if let newURL {
                player = AVPlayer(url: newURL)
            } else {
                player = nil
            }
        }
    }
}
