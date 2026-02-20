//
//  AudioTabView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Container view for all audio sub-features: TTS, Voice Clone, Music, STT.
struct AudioTabView: View {
    @StateObject private var viewModel = AudioViewModel()
    @State private var selectedSubTab: AudioSubTab = .tts

    enum AudioSubTab: String, CaseIterable {
        case tts = "Text to Speech"
        case voiceClone = "Voice Clone"
        case music = "Music"
        case stt = "Speech to Text"

        var icon: String {
            switch self {
            case .tts: return "speaker.wave.3"
            case .voiceClone: return "person.wave.2"
            case .music: return "music.note"
            case .stt: return "mic"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab picker
            Picker("", selection: $selectedSubTab) {
                ForEach(AudioSubTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            Group {
                switch selectedSubTab {
                case .tts:
                    TTSView(viewModel: viewModel)
                case .voiceClone:
                    VoiceCloningView(viewModel: viewModel)
                case .music:
                    MusicGenerationView(viewModel: viewModel)
                case .stt:
                    SpeechToTextView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Shared playback bar
            if viewModel.generatedAudioData != nil {
                Divider()
                AudioPlayerView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
    }
}
