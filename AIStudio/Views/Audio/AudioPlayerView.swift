//
//  AudioPlayerView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Reusable audio playback bar with play/pause/scrub.
struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Play/Stop button
            Button(action: {
                if viewModel.isPlaying {
                    viewModel.stopPlayback()
                } else {
                    viewModel.playGeneratedAudio()
                }
            }) {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.generatedAudioData == nil)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * viewModel.playbackProgress, height: 4)
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            // Duration
            if viewModel.playbackDuration > 0 {
                Text(formatTime(viewModel.playbackDuration * viewModel.playbackProgress))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Text("/")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))

                Text(formatTime(viewModel.playbackDuration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Save button
            if let audioData = viewModel.generatedAudioData {
                Button(action: {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.wav]
                    panel.nameFieldStringValue = "generated_audio.wav"
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            try? audioData.write(to: url)
                        }
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
