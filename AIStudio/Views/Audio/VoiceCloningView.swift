//
//  VoiceCloningView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct VoiceCloningView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Voice Cloning")
                        .font(.headline)

                    Text("Clone a voice using f5-tts-mlx. Provide a reference audio sample.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Reference audio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference Audio")
                            .font(.subheadline)

                        HStack {
                            TextField("Path to reference audio", text: $viewModel.referenceAudioPath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                let panel = NSOpenPanel()
                                panel.allowedContentTypes = [.audio]
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    viewModel.referenceAudioPath = url.path
                                }
                            }
                        }

                        Text("Supports WAV, MP3, M4A — short clips (5-30s) work best")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Drop zone
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 60)
                        .overlay(
                            Text("Drag & drop audio file here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            for provider in providers {
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    if let url {
                                        Task { @MainActor in
                                            viewModel.referenceAudioPath = url.path
                                        }
                                    }
                                }
                            }
                            return true
                        }

                    Divider()

                    // Text to speak
                    Text("Text")
                        .font(.subheadline)
                    TextEditor(text: $viewModel.cloneText)
                        .frame(minHeight: 80, maxHeight: 150)
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .scrollContentBackground(.hidden)

                    // Speed
                    HStack {
                        Text("Speed")
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $viewModel.cloneSpeed, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", viewModel.cloneSpeed))
                            .frame(width: 40)
                            .monospacedDigit()
                    }

                    Divider()

                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") { viewModel.cancel() }
                                .controlSize(.large)
                        } else {
                            Button("Clone Voice") { viewModel.cloneVoice() }
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.cloneText.isEmpty || viewModel.referenceAudioPath.isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage).font(.caption).foregroundColor(.secondary)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
                .padding()
            }
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 450)

            VStack {
                if viewModel.isGenerating {
                    ProgressView("Cloning voice...")
                } else if viewModel.generatedAudioData != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Voice cloned successfully")
                            .font(.headline)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Provide reference audio and text")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
