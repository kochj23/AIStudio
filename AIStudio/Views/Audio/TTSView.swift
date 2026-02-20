//
//  TTSView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct TTSView: View {
    @ObservedObject var viewModel: AudioViewModel

    var body: some View {
        HSplitView {
            // Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Text to Speech")
                        .font(.headline)

                    Text("MLX-based TTS engines: Kokoro, CSM, Chatterbox, Dia, Spark, Breeze, Mars5")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Text input
                    Text("Text")
                        .font(.subheadline)
                    TextEditor(text: $viewModel.ttsText)
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .scrollContentBackground(.hidden)

                    Divider()

                    // Engine selector
                    HStack {
                        Text("Engine")
                            .frame(width: 70, alignment: .leading)
                        Picker("", selection: $viewModel.ttsEngine) {
                            ForEach(viewModel.availableEngines, id: \.self) { engine in
                                Text(engine.capitalized).tag(engine)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: viewModel.ttsEngine) { _, _ in
                            viewModel.loadVoices()
                        }
                    }

                    // Voice selector
                    if !viewModel.availableVoices.isEmpty {
                        HStack {
                            Text("Voice")
                                .frame(width: 70, alignment: .leading)
                            Picker("", selection: $viewModel.ttsVoice) {
                                ForEach(viewModel.availableVoices, id: \.self) { voice in
                                    Text(voice).tag(voice)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    // Speed
                    HStack {
                        Text("Speed")
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $viewModel.ttsSpeed, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", viewModel.ttsSpeed))
                            .frame(width: 40)
                            .monospacedDigit()
                    }

                    Divider()

                    // Generate
                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") { viewModel.cancel() }
                                .controlSize(.large)
                        } else {
                            Button("Generate Speech") { viewModel.generateSpeech() }
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.ttsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    statusFooter
                }
                .padding()
            }
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 450)

            // Waveform / info panel
            audioInfoPanel
                .frame(minWidth: 300)
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
    }

    private var audioInfoPanel: some View {
        VStack {
            if viewModel.isGenerating {
                ProgressView("Generating...")
            } else if viewModel.generatedAudioData != nil {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    Text("Audio generated")
                        .font(.headline)
                    if let path = viewModel.generatedAudioPath {
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Enter text and generate speech")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
