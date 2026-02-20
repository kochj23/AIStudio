//
//  SpeechToTextView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct SpeechToTextView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Speech to Text")
                        .font(.headline)

                    Text("Transcribe audio using mlx-whisper (local, on-device).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Audio file
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio File")
                            .font(.subheadline)

                        HStack {
                            TextField("Path to audio file", text: $viewModel.sttAudioPath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                let panel = NSOpenPanel()
                                panel.allowedContentTypes = [.audio]
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    viewModel.sttAudioPath = url.path
                                }
                            }
                        }
                    }

                    // Drop zone
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 50)
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
                                            viewModel.sttAudioPath = url.path
                                        }
                                    }
                                }
                            }
                            return true
                        }

                    Divider()

                    // Model
                    HStack {
                        Text("Model")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $viewModel.sttModel) {
                            Text("Tiny").tag("tiny")
                            Text("Base").tag("base")
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large v3").tag("large-v3")
                        }
                        .labelsHidden()
                    }

                    // Language
                    HStack {
                        Text("Language")
                            .frame(width: 80, alignment: .leading)
                        TextField("Auto-detect (or e.g. 'en')", text: $viewModel.sttLanguage)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") { viewModel.cancel() }
                                .controlSize(.large)
                        } else {
                            Button("Transcribe") { viewModel.transcribe() }
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.sttAudioPath.isEmpty)
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

            // Transcription output
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isGenerating {
                    Spacer()
                    ProgressView("Transcribing...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if !viewModel.transcriptionText.isEmpty {
                    HStack {
                        Text("Transcription")
                            .font(.headline)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.transcriptionText, forType: .string)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    ScrollView {
                        Text(viewModel.transcriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }

                    // Segments
                    if !viewModel.transcriptionSegments.isEmpty {
                        Divider()
                        Text("Segments")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.transcriptionSegments) { segment in
                                    HStack(alignment: .top) {
                                        Text(segment.timeRange)
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                            .frame(width: 120, alignment: .leading)
                                        Text(segment.text)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "mic")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Select an audio file to transcribe")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .frame(minWidth: 300)
        }
    }
}
