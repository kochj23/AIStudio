//
//  GenerationRequest.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Request for text-to-image generation
struct ImageGenerationRequest: Codable, Sendable {
    let prompt: String
    var negativePrompt: String = ""
    var steps: Int = 20
    var samplerName: String = "Euler a"
    var cfgScale: Double = 7.0
    var width: Int = 512
    var height: Int = 512
    var seed: Int = -1
    var batchSize: Int = 1

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case steps
        case samplerName = "sampler_name"
        case cfgScale = "cfg_scale"
        case width
        case height
        case seed
        case batchSize = "batch_size"
    }
}

/// Request for image-to-image generation
struct ImageToImageRequest: Codable, Sendable {
    let prompt: String
    var negativePrompt: String = ""
    let initImages: [String] // Base64-encoded images
    var denoisingStrength: Double = 0.75
    var steps: Int = 20
    var samplerName: String = "Euler a"
    var cfgScale: Double = 7.0
    var width: Int = 512
    var height: Int = 512
    var seed: Int = -1

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case initImages = "init_images"
        case denoisingStrength = "denoising_strength"
        case steps
        case samplerName = "sampler_name"
        case cfgScale = "cfg_scale"
        case width
        case height
        case seed
    }
}

/// Request for TTS generation (Phase 4)
struct TTSRequest: Codable, Sendable {
    let text: String
    var voice: String = "default"
    var speed: Double = 1.0
    var engine: String = "kokoro"
}

/// Request for voice cloning (Phase 4)
struct VoiceCloneRequest: Codable, Sendable {
    let text: String
    let referenceAudioPath: String
    var speed: Double = 1.0
}

/// Request for speech-to-text (Phase 4)
struct TranscriptionRequest: Codable, Sendable {
    let audioFilePath: String
    var model: String = "base"
    var language: String? = nil
}

/// Request for music generation (Phase 4)
struct MusicGenRequest: Codable, Sendable {
    let prompt: String
    var duration: Double = 10.0
    var modelSize: String = "small"
}
