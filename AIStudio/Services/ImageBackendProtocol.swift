//
//  ImageBackendProtocol.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Protocol that all image generation backends must conform to.
/// This abstraction allows the ViewModel to call `backendManager.activeBackend.textToImage(request)`
/// without knowing or caring which backend is active.
protocol ImageBackendProtocol: Actor {
    /// The backend type identifier
    var backendType: BackendType { get }

    /// Check if the backend is reachable
    func checkHealth() async -> BackendStatus

    /// List available models on this backend
    func listModels() async throws -> [A1111Model]

    /// List available samplers on this backend
    func listSamplers() async throws -> [A1111Sampler]

    /// Generate image(s) from a text prompt
    func textToImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResult

    /// Generate image(s) from an existing image + prompt
    func imageToImage(_ request: ImageToImageRequest) async throws -> ImageGenerationResult

    /// Cancel any in-progress generation
    func cancel() async throws
}

/// Errors that backends can throw
enum BackendError: LocalizedError, Sendable {
    case notConnected
    case invalidURL(String)
    case requestFailed(Int, String)
    case decodingFailed(String)
    case invalidImageData
    case cancelled
    case timeout
    case noImagesReturned
    case backendSpecific(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Backend is not connected. Check that it's running and the URL is correct."
        case .invalidURL(let url):
            return "Invalid backend URL: \(url)"
        case .requestFailed(let code, let message):
            return "Request failed (HTTP \(code)): \(message)"
        case .decodingFailed(let detail):
            return "Failed to decode response: \(detail)"
        case .invalidImageData:
            return "Backend returned invalid image data."
        case .cancelled:
            return "Generation was cancelled."
        case .timeout:
            return "Request timed out."
        case .noImagesReturned:
            return "Backend returned no images."
        case .backendSpecific(let message):
            return message
        }
    }
}
