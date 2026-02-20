//
//  MusicGenerationView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct MusicGenerationView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Music Generation")
                        .font(.headline)

                    Text("Generate music from text descriptions using MusicGen via MLX.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Prompt
                    Text("Prompt")
                        .font(.subheadline)
                    TextEditor(text: $viewModel.musicPrompt)
                        .frame(minHeight: 60, maxHeight: 120)
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .scrollContentBackground(.hidden)

                    Text("Example: \"upbeat electronic dance music with heavy bass\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Divider()

                    // Duration
                    HStack {
                        Text("Duration")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $viewModel.musicDuration, in: 5...30, step: 1)
                        Text("\(Int(viewModel.musicDuration))s")
                            .frame(width: 30)
                            .monospacedDigit()
                    }

                    // Model size
                    HStack {
                        Text("Model")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $viewModel.musicModelSize) {
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") { viewModel.cancel() }
                                .controlSize(.large)
                        } else {
                            Button("Generate Music") { viewModel.generateMusic() }
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.musicPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    ProgressView("Generating music...")
                } else if viewModel.generatedAudioData != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Music generated")
                            .font(.headline)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Describe the music you want to create")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
