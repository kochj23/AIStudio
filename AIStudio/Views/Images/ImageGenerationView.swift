//
//  ImageGenerationView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main image generation view — HSplitView with controls on left, preview on right.
struct ImageGenerationView: View {
    @EnvironmentObject var backendManager: BackendManager
    @EnvironmentObject var generationQueue: GenerationQueue
    @EnvironmentObject var promptHistory: PromptHistory
    @StateObject private var viewModel = ImageGenerationViewModel()

    @State private var showingQueue = false
    @State private var showingHistory = false
    @State private var showingComparison = false
    @State private var dropTargeted = false

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

                    // Prompt history button
                    Button {
                        showingHistory.toggle()
                    } label: {
                        Label("Prompt History", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Divider()

                    ImageParametersView(
                        steps: $viewModel.steps,
                        cfgScale: $viewModel.cfgScale,
                        width: $viewModel.width,
                        height: $viewModel.height,
                        seed: $viewModel.seed,
                        samplerName: $viewModel.samplerName,
                        batchSize: $viewModel.batchSize,
                        selectedCheckpoint: $viewModel.selectedCheckpoint,
                        availableModels: viewModel.availableModels,
                        availableSamplers: viewModel.availableSamplers,
                        onSwapDimensions: viewModel.swapDimensions,
                        onRandomizeSeed: viewModel.randomizeSeed
                    )

                    Divider()

                    // Generate / Cancel / Queue buttons
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

                            Button {
                                viewModel.addToQueue()
                            } label: {
                                Label("Queue", systemImage: "plus.rectangle.on.rectangle")
                            }
                            .disabled(!viewModel.canGenerate)
                            .help("Add to generation queue (⇧⌘Q)")
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Queue indicator
                    if generationQueue.pendingCount > 0 || generationQueue.isProcessing {
                        Button {
                            showingQueue.toggle()
                        } label: {
                            HStack {
                                if generationQueue.isProcessing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("\(generationQueue.pendingCount) queued")
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }

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

                    // Compare button (when 2+ images exist)
                    if viewModel.generatedImages.count >= 2 {
                        Button {
                            showingComparison.toggle()
                        } label: {
                            Label("Compare Images", systemImage: "square.split.2x1")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding()
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

            // Right panel: Preview with drag & drop
            ImagePreviewView(
                images: viewModel.generatedImages,
                selectedIndex: $viewModel.selectedImageIndex,
                metadata: viewModel.lastMetadata,
                isGenerating: viewModel.isGenerating,
                onSave: viewModel.saveSelectedImage,
                onCopy: viewModel.copySelectedImageToClipboard
            )
            .frame(minWidth: 400)
            .overlay(
                // Drop zone overlay for img2img
                RoundedRectangle(cornerRadius: 12)
                    .stroke(dropTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
                    .background(dropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
            )
            .onDrop(of: [.image, .fileURL], isTargeted: $dropTargeted) { providers in
                handleImageDrop(providers)
            }
        }
        .onAppear {
            viewModel.configure(with: backendManager, queue: generationQueue)
            Task {
                await viewModel.loadModelsAndSamplers()
            }
        }
        // Keyboard shortcut notifications
        .onReceive(NotificationCenter.default.publisher(for: .triggerGenerate)) { _ in
            viewModel.generate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerCancel)) { _ in
            viewModel.cancelGeneration()
        }
        .onReceive(NotificationCenter.default.publisher(for: .randomizeSeed)) { _ in
            viewModel.randomizeSeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .swapDimensions)) { _ in
            viewModel.swapDimensions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addToQueue)) { _ in
            viewModel.addToQueue()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveImage)) { _ in
            viewModel.saveSelectedImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyImage)) { _ in
            viewModel.copySelectedImageToClipboard()
        }
        // Sheets
        .sheet(isPresented: $showingQueue) {
            GenerationQueueView(queue: generationQueue)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showingHistory) {
            PromptHistoryView(history: promptHistory) { entry in
                viewModel.loadFromPromptEntry(entry)
                showingHistory = false
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingComparison) {
            if viewModel.generatedImages.count >= 2 {
                ImageComparisonView(
                    leftImage: viewModel.generatedImages[0],
                    rightImage: viewModel.generatedImages[min(1, viewModel.generatedImages.count - 1)],
                    leftMetadata: viewModel.lastMetadata,
                    rightMetadata: viewModel.lastMetadata
                )
                .frame(minWidth: 800, minHeight: 600)
            }
        }
    }

    // MARK: - Drag & Drop

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Handle file URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    let imageExtensions = ["png", "jpg", "jpeg", "webp", "bmp", "tiff"]
                    if imageExtensions.contains(url.pathExtension.lowercased()) {
                        Task { @MainActor in
                            viewModel.statusMessage = "Dropped: \(url.lastPathComponent) (img2img coming soon)"
                        }
                    }
                }
                return true
            }

            // Handle direct image data
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard data != nil else { return }
                    Task { @MainActor in
                        viewModel.statusMessage = "Image dropped (img2img coming soon)"
                    }
                }
                return true
            }
        }
        return false
    }
}
