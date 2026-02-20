//
//  GenerationResult.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

/// Result from an image generation request
struct ImageGenerationResult: Sendable {
    let images: [GeneratedImage]
    let metadata: GenerationMetadata
    let timestamp: Date

    init(images: [GeneratedImage], metadata: GenerationMetadata) {
        self.images = images
        self.metadata = metadata
        self.timestamp = Date()
    }
}

/// A single generated image with its data
struct GeneratedImage: Identifiable, Sendable {
    let id: UUID
    let imageData: Data
    let index: Int

    init(imageData: Data, index: Int = 0) {
        self.id = UUID()
        self.imageData = imageData
        self.index = index
    }

    var nsImage: NSImage? {
        NSImage(data: imageData)
    }
}

/// Metadata about the generation
struct GenerationMetadata: Codable, Sendable {
    let prompt: String
    let negativePrompt: String
    let steps: Int
    let samplerName: String
    let cfgScale: Double
    let width: Int
    let height: Int
    let seed: Int
    let backendName: String
    let generationTime: TimeInterval

    var formattedTime: String {
        String(format: "%.1fs", generationTime)
    }

    var seedDisplay: String {
        seed == -1 ? "Random" : "\(seed)"
    }
}

/// A1111 API response for txt2img/img2img
struct A1111Response: Codable {
    let images: [String] // Base64-encoded PNG images
    let parameters: A1111Parameters?
    let info: String?
}

/// A1111 generation parameters from response
struct A1111Parameters: Codable {
    let prompt: String?
    let negativePrompt: String?
    let seed: Int?
    let samplerName: String?
    let steps: Int?
    let cfgScale: Double?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case seed
        case samplerName = "sampler_name"
        case steps
        case cfgScale = "cfg_scale"
        case width
        case height
    }
}

/// A1111 info JSON parsed from response
struct A1111InfoResponse: Codable {
    let seed: Int?
    let allSeeds: [Int]?
    let prompt: String?

    enum CodingKeys: String, CodingKey {
        case seed
        case allSeeds = "all_seeds"
        case prompt
    }
}

/// A1111 model info
struct A1111Model: Codable, Identifiable, Hashable {
    let title: String
    let modelName: String
    let hash: String?
    let filename: String?

    var id: String { modelName }

    enum CodingKeys: String, CodingKey {
        case title
        case modelName = "model_name"
        case hash
        case filename
    }
}

/// A1111 sampler info
struct A1111Sampler: Codable, Identifiable, Hashable {
    let name: String
    let aliases: [String]?

    var id: String { name }
}
