//
//  MLXAudioService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// MLX Audio service for TTS, voice cloning, speech-to-text, and music generation.
/// All operations run via PythonDaemonService (mlx-audio, f5-tts-mlx, mlx-whisper, MusicGen).
actor MLXAudioService {
    private let daemon: PythonDaemonService

    init(daemon: PythonDaemonService) {
        self.daemon = daemon
    }

    // MARK: - TTS

    /// Generate speech from text using MLX-based TTS
    func textToSpeech(_ request: TTSRequest) async throws -> AudioGenerationResult {
        let startTime = Date()

        let params: [String: Any] = [
            "text": request.text,
            "voice": request.voice,
            "speed": request.speed,
            "engine": request.engine,
        ]

        let response = try await daemon.sendRequest(command: "tts", params: params)

        guard let audioBase64 = response["audio"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw AudioError.noAudioReturned
        }

        let generationTime = Date().timeIntervalSince(startTime)
        return AudioGenerationResult(
            audioData: audioData,
            sampleRate: response["sample_rate"] as? Int ?? 24000,
            duration: response["duration"] as? Double ?? 0,
            generationTime: generationTime,
            type: .tts,
            metadata: ["engine": request.engine, "voice": request.voice]
        )
    }

    // MARK: - Voice Cloning

    /// Clone a voice using f5-tts-mlx
    func cloneVoice(_ request: VoiceCloneRequest) async throws -> AudioGenerationResult {
        let startTime = Date()

        let params: [String: Any] = [
            "text": request.text,
            "reference_audio": request.referenceAudioPath,
            "speed": request.speed,
        ]

        let response = try await daemon.sendRequest(command: "voice_clone", params: params)

        guard let audioBase64 = response["audio"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw AudioError.noAudioReturned
        }

        let generationTime = Date().timeIntervalSince(startTime)
        return AudioGenerationResult(
            audioData: audioData,
            sampleRate: response["sample_rate"] as? Int ?? 24000,
            duration: response["duration"] as? Double ?? 0,
            generationTime: generationTime,
            type: .voiceClone,
            metadata: ["reference": (request.referenceAudioPath as NSString).lastPathComponent]
        )
    }

    // MARK: - Speech to Text

    /// Transcribe audio using mlx-whisper
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        let startTime = Date()

        var params: [String: Any] = [
            "audio_file": request.audioFilePath,
            "model": request.model,
        ]
        if let language = request.language {
            params["language"] = language
        }

        let response = try await daemon.sendRequest(command: "transcribe", params: params)

        guard let text = response["text"] as? String else {
            throw AudioError.transcriptionFailed
        }

        let generationTime = Date().timeIntervalSince(startTime)
        return TranscriptionResult(
            text: text,
            language: response["language"] as? String ?? "unknown",
            segments: parseSegments(response["segments"]),
            processingTime: generationTime
        )
    }

    // MARK: - Music Generation

    /// Generate music using MusicGen via MLX
    func generateMusic(_ request: MusicGenRequest) async throws -> AudioGenerationResult {
        let startTime = Date()

        let params: [String: Any] = [
            "prompt": request.prompt,
            "duration": request.duration,
            "model_size": request.modelSize,
        ]

        let response = try await daemon.sendRequest(command: "generate_music", params: params)

        guard let audioBase64 = response["audio"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw AudioError.noAudioReturned
        }

        let generationTime = Date().timeIntervalSince(startTime)
        return AudioGenerationResult(
            audioData: audioData,
            sampleRate: response["sample_rate"] as? Int ?? 32000,
            duration: response["duration"] as? Double ?? request.duration,
            generationTime: generationTime,
            type: .music,
            metadata: ["prompt": request.prompt, "model_size": request.modelSize]
        )
    }

    // MARK: - Available Models

    func listTTSEngines() async throws -> [String] {
        let response = try await daemon.sendRequest(command: "list_tts_engines")
        return response["engines"] as? [String] ?? ["kokoro", "csm", "chatterbox", "dia", "spark", "breeze", "mars5"]
    }

    func listVoices(engine: String) async throws -> [String] {
        let response = try await daemon.sendRequest(command: "list_voices", params: ["engine": engine])
        return response["voices"] as? [String] ?? []
    }

    func listWhisperModels() async throws -> [String] {
        return ["tiny", "base", "small", "medium", "large-v3"]
    }

    // MARK: - Private

    private func parseSegments(_ raw: Any?) -> [TranscriptionSegment] {
        guard let segments = raw as? [[String: Any]] else { return [] }
        return segments.compactMap { seg in
            guard let start = seg["start"] as? Double,
                  let end = seg["end"] as? Double,
                  let text = seg["text"] as? String else {
                return nil
            }
            return TranscriptionSegment(start: start, end: end, text: text)
        }
    }
}

// MARK: - Audio Result Types

struct AudioGenerationResult: Sendable {
    let audioData: Data
    let sampleRate: Int
    let duration: Double
    let generationTime: TimeInterval
    let type: AudioOutputType
    let metadata: [String: String]

    var formattedTime: String {
        String(format: "%.1fs", generationTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    enum AudioOutputType: String, Sendable {
        case tts
        case voiceClone
        case music
    }
}

struct TranscriptionResult: Sendable {
    let text: String
    let language: String
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval

    var formattedTime: String {
        String(format: "%.1fs", processingTime)
    }
}

struct TranscriptionSegment: Identifiable, Sendable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String

    var timeRange: String {
        String(format: "%02d:%05.2f - %02d:%05.2f", Int(start) / 60, start.truncatingRemainder(dividingBy: 60), Int(end) / 60, end.truncatingRemainder(dividingBy: 60))
    }
}

enum AudioError: LocalizedError {
    case noAudioReturned
    case transcriptionFailed
    case invalidAudioData
    case engineNotAvailable(String)
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .noAudioReturned: return "No audio data returned from daemon."
        case .transcriptionFailed: return "Transcription failed."
        case .invalidAudioData: return "Invalid audio data."
        case .engineNotAvailable(let e): return "TTS engine '\(e)' is not available."
        case .fileTooLarge: return "Audio file exceeds maximum size (100 MB)."
        }
    }
}
