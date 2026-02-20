//
//  MLXImageService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// MLX Native image generation service.
/// Bridges to PythonDaemonService for local Stable Diffusion inference via diffusionkit/mflux.
actor MLXImageService: ImageBackendProtocol {
    let backendType: BackendType = .mlxNative

    private let daemon: PythonDaemonService

    init(daemon: PythonDaemonService) {
        self.daemon = daemon
    }

    func checkHealth() async -> BackendStatus {
        do {
            let response = try await daemon.sendRequest(command: "health")
            if let status = response["status"] as? String, status == "ok" {
                return .connected
            }
            return .error("Unexpected response")
        } catch {
            return .disconnected
        }
    }

    func listModels() async throws -> [A1111Model] {
        let response = try await daemon.sendRequest(command: "list_image_models")
        guard let models = response["models"] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            return A1111Model(
                title: name,
                modelName: name,
                hash: nil,
                filename: dict["path"] as? String
            )
        }
    }

    func listSamplers() async throws -> [A1111Sampler] {
        // MLX SD uses fixed samplers
        return [
            A1111Sampler(name: "euler", aliases: nil),
            A1111Sampler(name: "euler_ancestral", aliases: nil),
        ]
    }

    func textToImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        let params: [String: Any] = [
            "prompt": request.prompt,
            "negative_prompt": request.negativePrompt,
            "steps": request.steps,
            "cfg_scale": request.cfgScale,
            "width": request.width,
            "height": request.height,
            "seed": request.seed,
        ]

        let response = try await daemon.sendRequest(command: "generate_image", params: params)

        guard let imagesBase64 = response["images"] as? [String] else {
            throw BackendError.noImagesReturned
        }

        let images = try imagesBase64.enumerated().map { index, base64 in
            guard let data = Data(base64Encoded: base64) else {
                throw BackendError.invalidImageData
            }
            guard ImageUtils.validateImageData(data) else {
                throw BackendError.invalidImageData
            }
            return GeneratedImage(imageData: data, index: index)
        }

        let actualSeed = response["seed"] as? Int ?? request.seed
        let generationTime = Date().timeIntervalSince(startTime)

        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: "euler",
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: actualSeed,
            backendName: "MLX Native",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    func imageToImage(_ request: ImageToImageRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        var params: [String: Any] = [
            "prompt": request.prompt,
            "negative_prompt": request.negativePrompt,
            "steps": request.steps,
            "cfg_scale": request.cfgScale,
            "width": request.width,
            "height": request.height,
            "seed": request.seed,
            "denoising_strength": request.denoisingStrength,
        ]

        if let firstImage = request.initImages.first {
            params["init_image"] = firstImage
        }

        let response = try await daemon.sendRequest(command: "img2img", params: params)

        guard let imagesBase64 = response["images"] as? [String] else {
            throw BackendError.noImagesReturned
        }

        let images = try imagesBase64.enumerated().map { index, base64 in
            guard let data = Data(base64Encoded: base64) else {
                throw BackendError.invalidImageData
            }
            return GeneratedImage(imageData: data, index: index)
        }

        let generationTime = Date().timeIntervalSince(startTime)
        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: "euler",
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: response["seed"] as? Int ?? request.seed,
            backendName: "MLX Native",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    func cancel() async throws {
        _ = try? await daemon.sendRequest(command: "cancel")
    }
}
