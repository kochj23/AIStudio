//
//  VideoGenerationViewModel.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine
import AppKit
import AVFoundation

@MainActor
class VideoGenerationViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var negativePrompt: String = ""
    @Published var frameCount: Int = 16
    @Published var fps: Int = 8
    @Published var steps: Int = 20
    @Published var cfgScale: Double = 7.0
    @Published var width: Int = 512
    @Published var height: Int = 512
    @Published var seed: Int = -1

    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    @Published var generatedVideoURL: URL?

    private weak var backendManager: BackendManager?
    private var generationTask: Task<Void, Never>?

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func configure(with backendManager: BackendManager) {
        self.backendManager = backendManager
    }

    func generate() {
        guard canGenerate else { return }

        // Video generation uses ComfyUI with AnimateDiff workflow
        guard let backendManager,
              backendManager.backends[.comfyUI]?.status.isConnected == true else {
            errorMessage = "ComfyUI must be connected for video generation."
            return
        }

        isGenerating = true
        progress = 0.0
        errorMessage = nil
        statusMessage = "Generating video..."

        generationTask = Task {
            do {
                // Build AnimateDiff workflow for ComfyUI
                _ = buildAnimateDiffWorkflow()
                let comfyService = ComfyUIService(baseURL: AppSettings.shared.comfyUIURL)

                // Submit as a txt2img request with AnimateDiff nodes
                let request = ImageGenerationRequest(
                    prompt: prompt,
                    negativePrompt: negativePrompt,
                    steps: steps,
                    samplerName: "euler_ancestral",
                    cfgScale: cfgScale,
                    width: width,
                    height: height,
                    seed: seed
                )

                let result = try await comfyService.textToImage(request)

                // If frames are returned, combine into video
                if result.images.count > 1 {
                    let videoURL = try await combineFramesToVideo(result.images)
                    generatedVideoURL = videoURL
                    statusMessage = "Video generated (\(result.images.count) frames)"
                } else if let firstImage = result.images.first {
                    // Single animated image — save directly
                    let path = try FileOrganizer.saveGeneratedImage(
                        firstImage.imageData, prompt: prompt, seed: seed
                    )
                    generatedVideoURL = URL(fileURLWithPath: path)
                    statusMessage = "Done in \(result.metadata.formattedTime)"
                }

                logInfo("Video generated: \(result.images.count) frames", category: "VideoGen")
            } catch is CancellationError {
                statusMessage = "Cancelled"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
                logError("Video generation failed: \(error.localizedDescription)", category: "VideoGen")
            }

            isGenerating = false
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        statusMessage = "Cancelled"
    }

    // MARK: - Private

    private func buildAnimateDiffWorkflow() -> [String: Any] {
        // AnimateDiff workflow nodes for ComfyUI
        return [
            "prompt": prompt,
            "negative_prompt": negativePrompt,
            "frames": frameCount,
            "fps": fps,
            "steps": steps,
            "cfg_scale": cfgScale,
            "width": width,
            "height": height,
            "seed": seed,
        ] as [String : Any]
    }

    private func combineFramesToVideo(_ frames: [GeneratedImage]) async throws -> URL {
        let outputDir = FileOrganizer.outputDirectory(for: "videos")
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let filename = FileOrganizer.uniqueVideoFilename(prompt: prompt)
        let outputPath = "\(outputDir)/\(filename)"
        let outputURL = URL(fileURLWithPath: outputPath)

        // Use AVAssetWriter to combine frames into MP4
        guard let firstFrame = frames.first?.nsImage else {
            throw BackendError.noImagesReturned
        }

        let size = firstFrame.size
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: nil
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        _ = CMTime(value: 1, timescale: CMTimeScale(fps))

        for (index, frame) in frames.enumerated() {
            guard let nsImage = frame.nsImage,
                  let pixelBuffer = nsImage.pixelBuffer() else {
                continue
            }

            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            let presentationTime = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        return outputURL
    }
}

// MARK: - NSImage to CVPixelBuffer

extension NSImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
