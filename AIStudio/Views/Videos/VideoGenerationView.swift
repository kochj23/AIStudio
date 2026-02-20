//
//  VideoGenerationView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct VideoGenerationView: View {
    @EnvironmentObject var backendManager: BackendManager
    @StateObject private var viewModel = VideoGenerationViewModel()

    var body: some View {
        HSplitView {
            // Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Video Generation")
                        .font(.headline)

                    Text("Requires ComfyUI with AnimateDiff")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.subheadline)
                        TextEditor(text: $viewModel.prompt)
                            .frame(minHeight: 60, maxHeight: 120)
                            .border(Color.secondary.opacity(0.3), width: 1)
                            .scrollContentBackground(.hidden)

                        Text("Negative Prompt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.negativePrompt)
                            .frame(minHeight: 40, maxHeight: 80)
                            .border(Color.secondary.opacity(0.3), width: 1)
                            .scrollContentBackground(.hidden)
                    }

                    Divider()

                    // Parameters
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Parameters")
                            .font(.subheadline)

                        HStack {
                            Text("Frames")
                                .frame(width: 70, alignment: .leading)
                            Stepper("\(viewModel.frameCount)", value: $viewModel.frameCount, in: 4...64, step: 4)
                        }

                        HStack {
                            Text("FPS")
                                .frame(width: 70, alignment: .leading)
                            Stepper("\(viewModel.fps)", value: $viewModel.fps, in: 4...30)
                        }

                        HStack {
                            Text("Steps")
                                .frame(width: 70, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(viewModel.steps) },
                                set: { viewModel.steps = Int($0) }
                            ), in: 1...100, step: 1)
                            Text("\(viewModel.steps)")
                                .frame(width: 30)
                                .monospacedDigit()
                        }

                        HStack {
                            Text("CFG")
                                .frame(width: 70, alignment: .leading)
                            Slider(value: $viewModel.cfgScale, in: 1...20, step: 0.5)
                            Text(String(format: "%.1f", viewModel.cfgScale))
                                .frame(width: 30)
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Size")
                                .frame(width: 70, alignment: .leading)
                            Text("\(viewModel.width)x\(viewModel.height)")
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Seed")
                                .frame(width: 70, alignment: .leading)
                            TextField("-1 = random", value: $viewModel.seed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    Divider()

                    // Generate button
                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") { viewModel.cancelGeneration() }
                                .keyboardShortcut(.escape)
                                .controlSize(.large)
                        } else {
                            Button("Generate Video") { viewModel.generate() }
                                .keyboardShortcut(.return, modifiers: .command)
                                .controlSize(.large)
                                .disabled(!viewModel.canGenerate)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

            // Preview
            VideoPreviewView(videoURL: viewModel.generatedVideoURL, isGenerating: viewModel.isGenerating)
                .frame(minWidth: 400)
        }
        .onAppear {
            viewModel.configure(with: backendManager)
        }
    }
}
