//
//  ImageGenerationViewModel.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine
import AppKit

@MainActor
class ImageGenerationViewModel: ObservableObject {
    // MARK: - Prompt

    @Published var prompt: String = ""
    @Published var negativePrompt: String = ""

    // MARK: - Parameters

    @Published var steps: Int = 20
    @Published var cfgScale: Double = 7.0
    @Published var width: Int = 512
    @Published var height: Int = 512
    @Published var seed: Int = -1
    @Published var samplerName: String = "Euler a"
    @Published var batchSize: Int = 1

    // MARK: - State

    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    // MARK: - Results

    @Published var generatedImages: [GeneratedImage] = []
    @Published var selectedImageIndex: Int = 0
    @Published var lastMetadata: GenerationMetadata?

    // MARK: - Backend Data

    @Published var availableModels: [A1111Model] = []
    @Published var availableSamplers: [A1111Sampler] = []

    private weak var backendManager: BackendManager?
    private weak var generationQueue: GenerationQueue?
    private var generationTask: Task<Void, Never>?

    var selectedImage: GeneratedImage? {
        guard selectedImageIndex >= 0 && selectedImageIndex < generatedImages.count else { return nil }
        return generatedImages[selectedImageIndex]
    }

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Setup

    func configure(with backendManager: BackendManager, queue: GenerationQueue? = nil) {
        self.backendManager = backendManager
        self.generationQueue = queue
        loadDefaults()
    }

    private func loadDefaults() {
        let settings = AppSettings.shared
        steps = settings.defaultSteps
        cfgScale = settings.defaultCFGScale
        width = settings.defaultWidth
        height = settings.defaultHeight
        samplerName = settings.defaultSampler
    }

    // MARK: - Backend Data Loading

    func loadModelsAndSamplers() async {
        guard let backendManager else { return }

        do {
            async let modelsResult = backendManager.listModels()
            async let samplersResult = backendManager.listSamplers()

            let (models, samplers) = try await (modelsResult, samplersResult)
            self.availableModels = models
            self.availableSamplers = samplers
            logInfo("Loaded \(models.count) models, \(samplers.count) samplers", category: "ImageGen")
        } catch {
            logWarning("Failed to load models/samplers: \(error.localizedDescription)", category: "ImageGen")
        }
    }

    // MARK: - Generation

    func generate() {
        guard canGenerate else { return }
        guard let backendManager, let backend = backendManager.activeBackend else {
            errorMessage = "No backend connected. Check Settings."
            return
        }

        let sanitizedPrompt = SecurityUtils.sanitizePrompt(prompt)
        let sanitizedNegative = SecurityUtils.sanitizePrompt(negativePrompt)

        let request = ImageGenerationRequest(
            prompt: sanitizedPrompt,
            negativePrompt: sanitizedNegative,
            steps: steps,
            samplerName: samplerName,
            cfgScale: cfgScale,
            width: width,
            height: height,
            seed: seed,
            batchSize: batchSize
        )

        isGenerating = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Generating..."

        generationTask = Task {
            do {
                let result = try await backend.textToImage(request)

                self.generatedImages = result.images
                self.lastMetadata = result.metadata
                self.selectedImageIndex = 0
                self.statusMessage = "Done in \(result.metadata.formattedTime) | Seed: \(result.metadata.seedDisplay)"

                // Auto-save if enabled
                if AppSettings.shared.autoSaveImages {
                    await autoSaveImages(result)
                }

                // Record prompt in history
                PromptHistory.shared.record(
                    prompt: sanitizedPrompt,
                    negativePrompt: sanitizedNegative,
                    steps: self.steps,
                    cfgScale: self.cfgScale,
                    width: self.width,
                    height: self.height,
                    seed: result.metadata.seed,
                    samplerName: self.samplerName
                )

                logInfo("Generated \(result.images.count) image(s) in \(result.metadata.formattedTime)", category: "ImageGen")
            } catch is CancellationError {
                statusMessage = "Cancelled"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
                logError("Generation failed: \(error.localizedDescription)", category: "ImageGen")
            }

            isGenerating = false
            progress = 1.0
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil

        Task {
            guard let backend = backendManager?.activeBackend else { return }
            try? await backend.cancel()
        }

        isGenerating = false
        statusMessage = "Cancelled"
    }

    // MARK: - Auto-Save

    private func autoSaveImages(_ result: ImageGenerationResult) async {
        for (index, image) in result.images.enumerated() {
            do {
                let path = try FileOrganizer.saveGeneratedImage(
                    image.imageData,
                    prompt: result.metadata.prompt,
                    seed: result.metadata.seed,
                    index: result.images.count > 1 ? index : 0
                )
                FileOrganizer.saveMetadata(result.metadata, alongside: path)
            } catch {
                logWarning("Auto-save failed for image \(index): \(error.localizedDescription)", category: "ImageGen")
            }
        }
    }

    // MARK: - Save/Copy Actions

    func saveSelectedImage() {
        guard let image = selectedImage else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = FileOrganizer.uniqueImageFilename(
            prompt: prompt,
            seed: lastMetadata?.seed ?? -1
        )

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try image.imageData.write(to: url)
                self?.statusMessage = "Saved to \(url.lastPathComponent)"
            } catch {
                self?.errorMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func copySelectedImageToClipboard() {
        guard let image = selectedImage, let nsImage = image.nsImage else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        statusMessage = "Copied to clipboard"
    }

    // MARK: - Utility

    func randomizeSeed() {
        seed = -1
    }

    func swapDimensions() {
        let temp = width
        width = height
        height = temp
    }

    // MARK: - Queue Integration

    /// Add current settings to the generation queue
    func addToQueue() {
        guard let generationQueue else { return }
        let params = GenerationParameters(
            steps: steps,
            cfgScale: cfgScale,
            width: width,
            height: height,
            seed: seed,
            samplerName: samplerName,
            batchSize: batchSize
        )
        let added = generationQueue.enqueue(
            prompt: SecurityUtils.sanitizePrompt(prompt),
            negativePrompt: SecurityUtils.sanitizePrompt(negativePrompt),
            parameters: params
        )
        if added {
            statusMessage = "Added to queue (\(generationQueue.pendingCount) pending)"
        } else {
            errorMessage = "Queue is full"
        }
    }

    // MARK: - Prompt History Integration

    /// Load settings from a saved prompt entry
    func loadFromPromptEntry(_ entry: PromptEntry) {
        prompt = entry.prompt
        negativePrompt = entry.negativePrompt
        steps = entry.parameters.steps
        cfgScale = entry.parameters.cfgScale
        width = entry.parameters.width
        height = entry.parameters.height
        seed = entry.parameters.seed
        samplerName = entry.parameters.samplerName
        statusMessage = "Loaded prompt from history"
    }

    /// Standard SD sizes
    static let standardSizes: [(String, Int, Int)] = [
        ("512x512", 512, 512),
        ("512x768", 512, 768),
        ("768x512", 768, 512),
        ("768x768", 768, 768),
        ("1024x1024", 1024, 1024),
        ("1024x768", 1024, 768),
        ("768x1024", 768, 1024),
    ]
}
