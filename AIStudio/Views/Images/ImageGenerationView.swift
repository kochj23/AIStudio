//
//  ImageGenerationView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Main image generation view — HSplitView with controls on left, preview on right.
struct ImageGenerationView: View {
    @EnvironmentObject var backendManager: BackendManager
    @StateObject private var viewModel = ImageGenerationViewModel()

    var body: some View {
        HSplitView {
            // Left panel: Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BackendSelectorView()

                    Divider()

                    ImagePromptView(
                        prompt: $viewModel.prompt,
                        negativePrompt: $viewModel.negativePrompt
                    )

                    Divider()

                    ImageParametersView(
                        steps: $viewModel.steps,
                        cfgScale: $viewModel.cfgScale,
                        width: $viewModel.width,
                        height: $viewModel.height,
                        seed: $viewModel.seed,
                        samplerName: $viewModel.samplerName,
                        batchSize: $viewModel.batchSize,
                        availableSamplers: viewModel.availableSamplers,
                        onSwapDimensions: viewModel.swapDimensions,
                        onRandomizeSeed: viewModel.randomizeSeed
                    )

                    Divider()

                    // Generate / Cancel button
                    HStack {
                        if viewModel.isGenerating {
                            Button("Cancel") {
                                viewModel.cancelGeneration()
                            }
                            .keyboardShortcut(.escape)
                            .controlSize(.large)
                        } else {
                            Button("Generate") {
                                viewModel.generate()
                            }
                            .keyboardShortcut(.return, modifiers: .command)
                            .controlSize(.large)
                            .disabled(!viewModel.canGenerate)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Status
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

            // Right panel: Preview
            ImagePreviewView(
                images: viewModel.generatedImages,
                selectedIndex: $viewModel.selectedImageIndex,
                metadata: viewModel.lastMetadata,
                isGenerating: viewModel.isGenerating,
                onSave: viewModel.saveSelectedImage,
                onCopy: viewModel.copySelectedImageToClipboard
            )
            .frame(minWidth: 400)
        }
        .onAppear {
            viewModel.configure(with: backendManager)
            Task {
                await viewModel.loadModelsAndSamplers()
            }
        }
    }
}
