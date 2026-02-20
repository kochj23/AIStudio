//
//  SwarmUIService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// SwarmUI REST API client.
/// Default: http://localhost:7801
/// API documentation is sparse — this implementation covers basic txt2img.
actor SwarmUIService: ImageBackendProtocol {
    let backendType: BackendType = .swarmUI

    private var baseURL: String
    private let session: URLSession
    private var sessionId: String?

    init(baseURL: String = "http://localhost:7801") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        self.session = URLSession(configuration: config)
    }

    func updateBaseURL(_ url: String) {
        self.baseURL = url
    }

    // MARK: - Health Check

    func checkHealth() async -> BackendStatus {
        guard let url = URL(string: "\(baseURL)/API/GetNewSession") else {
            return .error("Invalid URL")
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8)
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Cache session while we're at it
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sid = json["session_id"] as? String {
                    self.sessionId = sid
                }
                return .connected
            }
            return .error("Unexpected response")
        } catch {
            return .disconnected
        }
    }

    // MARK: - Session

    private func ensureSession() async throws {
        if sessionId != nil { return }

        let body: [String: Any] = [:]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = try await post("/API/GetNewSession", body: data)

        if let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
           let session = json["session_id"] as? String {
            self.sessionId = session
        }
    }

    // MARK: - Models

    func listModels() async throws -> [A1111Model] {
        try await ensureSession()

        let body: [String: Any] = [
            "session_id": sessionId ?? "",
            "path": "",
            "depth": 10
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let response = try await post("/API/ListModels", body: data)

        if let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
           let files = json["files"] as? [[String: Any]] {
            return files.compactMap { dict in
                guard let name = dict["name"] as? String else { return nil }
                let title = dict["title"] as? String ?? name
                return A1111Model(title: title, modelName: name, hash: nil, filename: name)
            }
        }
        return []
    }

    func listSamplers() async throws -> [A1111Sampler] {
        // SwarmUI typically supports standard samplers
        return [
            A1111Sampler(name: "euler", aliases: nil),
            A1111Sampler(name: "euler_ancestral", aliases: nil),
            A1111Sampler(name: "dpmpp_2m", aliases: nil),
            A1111Sampler(name: "dpmpp_sde", aliases: nil),
            A1111Sampler(name: "ddim", aliases: nil),
        ]
    }

    // MARK: - Text to Image

    func textToImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult {
        let startTime = Date()
        try await ensureSession()

        var body: [String: Any] = [
            "session_id": sessionId ?? "",
            "prompt": request.prompt,
            "negativeprompt": request.negativePrompt,
            "steps": request.steps,
            "cfgscale": request.cfgScale,
            "width": request.width,
            "height": request.height,
            "seed": request.seed,
            "images": request.batchSize,
            "sampler": request.samplerName,
        ]
        if let checkpoint = request.checkpointName, !checkpoint.isEmpty {
            body["model"] = checkpoint
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let responseData = try await post("/API/GenerateText2Image", body: bodyData)

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let imagesArray = json["images"] as? [String] else {
            throw BackendError.noImagesReturned
        }

        var images: [GeneratedImage] = []
        for (index, urlOrBase64) in imagesArray.enumerated() {
            let imageData: Data
            if urlOrBase64.hasPrefix("http") {
                guard let url = URL(string: urlOrBase64) else {
                    throw BackendError.invalidImageData
                }
                let (data, _) = try await session.data(from: url)
                imageData = data
            } else {
                guard let data = Data(base64Encoded: urlOrBase64) else {
                    throw BackendError.invalidImageData
                }
                imageData = data
            }

            guard ImageUtils.validateImageData(imageData) else {
                throw BackendError.invalidImageData
            }
            images.append(GeneratedImage(imageData: imageData, index: index))
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
            seed: json["seed"] as? Int ?? request.seed,
            backendName: "SwarmUI",
            generationTime: generationTime
        )

        return ImageGenerationResult(images: images, metadata: metadata)
    }

    func imageToImage(_ request: ImageToImageRequest) async throws -> ImageGenerationResult {
        // SwarmUI img2img uses similar API
        throw BackendError.backendSpecific("SwarmUI img2img not yet implemented")
    }

    func cancel() async throws {
        guard let sid = sessionId else { return }
        let body: [String: Any] = ["session_id": sid]
        let data = try JSONSerialization.data(withJSONObject: body)
        _ = try? await post("/API/InterruptAll", body: data)
    }

    // MARK: - HTTP

    private func post(_ path: String, body: Data) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendError.invalidURL("\(baseURL)\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 300
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0,
                                             String(data: data, encoding: .utf8) ?? "No body")
        }
        return data
    }
}
