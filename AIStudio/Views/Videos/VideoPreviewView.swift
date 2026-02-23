//
//  VideoPreviewView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import AVKit

/// Direct NSViewRepresentable wrapper for AVPlayerView.
/// Avoids _AVKit_SwiftUI framework which crashes on macOS 26.3 when using
/// the SwiftUI VideoPlayer component (superclass metadata resolution failure).
private struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

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
                AVPlayerViewRepresentable(player: player)
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
