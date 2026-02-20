//
//  Automatic1111Service.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Automatic1111 (AUTOMATIC1111/stable-diffusion-webui) REST API client.
/// Endpoints: /sdapi/v1/txt2img, /sdapi/v1/img2img, /sdapi/v1/sd-models, /sdapi/v1/samplers, /sdapi/v1/interrupt
actor Automatic1111Service: ImageBackendProtocol {
    let backendType: BackendType = .automatic1111

    private var baseURL: String
    private let session: URLSession
    private let timeoutInterval: TimeInterval = 300 // 5 minutes for generation

    init(baseURL: String = "http://localhost:7860") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    func updateBaseURL(_ url: String) {
        self.baseURL = url
    }

    // MARK: - Health Check

    func checkHealth() async -> BackendStatus {
        guard let url = URL(string: "\(baseURL)/sdapi/v1/samplers") else {
            return .error("Invalid URL")
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .connected
            } else {
                return .error("Unexpected response")
            }
        } catch {
            return .disconnected
        }
    }

    // MARK: - Models

    func listModels() async throws -> [A1111Model] {
        let data = try await get("/sdapi/v1/sd-models")
        do {
            return try JSONDecoder().decode([A1111Model].self, from: data)
        } catch {
            throw BackendError.decodingFailed("Failed to decode models: \(error.localizedDescription)")
        }
    }

    // MARK: - Samplers

    func listSamplers() async throws -> [A1111Sampler] {
        let data = try await get("/sdapi/v1/samplers")
        do {
            return try JSONDecoder().decode([A1111Sampler].self, from: data)
        } catch {
            throw BackendError.decodingFailed("Failed to decode samplers: \(error.localizedDescription)")
        }
    }

    // MARK: - Text to Image

    func textToImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        let requestData = try JSONEncoder().encode(request)
        let responseData = try await post("/sdapi/v1/txt2img", body: requestData)

        let a1111Response: A1111Response
        do {
            a1111Response = try JSONDecoder().decode(A1111Response.self, from: responseData)
        } catch {
            throw BackendError.decodingFailed("txt2img response: \(error.localizedDescription)")
        }

        guard !a1111Response.images.isEmpty else {
            throw BackendError.noImagesReturned
        }

        // Parse info for actual seed
        var actualSeed = request.seed
        if let infoString = a1111Response.info,
           let infoData = infoString.data(using: .utf8),
           let info = try? JSONDecoder().decode(A1111InfoResponse.self, from: infoData) {
            actualSeed = info.seed ?? request.seed
        }

        let images = try a1111Response.images.enumerated().map { index, base64String in
            guard let imageData = Data(base64Encoded: base64String) else {
                throw BackendError.invalidImageData
            }
            guard ImageUtils.validateImageData(imageData) else {
                throw BackendError.invalidImageData
            }
            return GeneratedImage(imageData: imageData, index: index)
        }

        let generationTime = Date().timeIntervalSince(startTime)
        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: request.samplerName,
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: actualSeed,
            backendName: "Automatic1111",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    // MARK: - Image to Image

    func imageToImage(_ request: ImageToImageRequest) async throws -> ImageGenerationResult {
        let startTime = Date()

        let requestData = try JSONEncoder().encode(request)
        let responseData = try await post("/sdapi/v1/img2img", body: requestData)

        let a1111Response: A1111Response
        do {
            a1111Response = try JSONDecoder().decode(A1111Response.self, from: responseData)
        } catch {
            throw BackendError.decodingFailed("img2img response: \(error.localizedDescription)")
        }

        guard !a1111Response.images.isEmpty else {
            throw BackendError.noImagesReturned
        }

        var actualSeed = request.seed
        if let infoString = a1111Response.info,
           let infoData = infoString.data(using: .utf8),
           let info = try? JSONDecoder().decode(A1111InfoResponse.self, from: infoData) {
            actualSeed = info.seed ?? request.seed
        }

        let images = try a1111Response.images.enumerated().map { index, base64String in
            guard let imageData = Data(base64Encoded: base64String) else {
                throw BackendError.invalidImageData
            }
            guard ImageUtils.validateImageData(imageData) else {
                throw BackendError.invalidImageData
            }
            return GeneratedImage(imageData: imageData, index: index)
        }

        let generationTime = Date().timeIntervalSince(startTime)
        let metadata = GenerationMetadata(
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            steps: request.steps,
            samplerName: request.samplerName,
            cfgScale: request.cfgScale,
            width: request.width,
            height: request.height,
            seed: actualSeed,
            backendName: "Automatic1111",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    // MARK: - Cancel

    func cancel() async throws {
        _ = try await post("/sdapi/v1/interrupt", body: Data())
    }

    // MARK: - HTTP Helpers

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL("\(baseURL)\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.requestFailed(0, "No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw BackendError.requestFailed(httpResponse.statusCode, body)
        }

        return data
    }

    private func post(_ path: String, body: Data) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL("\(baseURL)\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.requestFailed(0, "No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw BackendError.requestFailed(httpResponse.statusCode, body)
        }

        return data
    }
}
