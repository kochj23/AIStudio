//
//  FileOrganizer.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Organizes generated media into date-based directories.
/// Output structure: ~/Documents/AIStudio/output/{date}/{type}/filename
enum FileOrganizer {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter
    }()

    /// Get the output directory for a media type on the current date
    @MainActor
    static func outputDirectory(for type: String, baseDir: String? = nil) -> String {
        let base = baseDir ?? AppSettings.shared.outputDirectory
        let dateString = dateFormatter.string(from: Date())
        return "\(base)/\(dateString)/\(type)"
    }

    /// Generate a unique filename for a generated image
    static func uniqueImageFilename(prompt: String, seed: Int, index: Int = 0) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let sanitizedPrompt = sanitizeForFilename(prompt, maxLength: 40)
        let seedStr = seed == -1 ? "rand" : "\(seed)"

        if index > 0 {
            return "\(timestamp)_\(sanitizedPrompt)_s\(seedStr)_\(index).png"
        }
        return "\(timestamp)_\(sanitizedPrompt)_s\(seedStr).png"
    }

    /// Generate a unique filename for audio
    static func uniqueAudioFilename(type: String, label: String) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let sanitized = sanitizeForFilename(label, maxLength: 40)
        return "\(timestamp)_\(type)_\(sanitized).wav"
    }

    /// Generate a unique filename for video
    static func uniqueVideoFilename(prompt: String) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let sanitized = sanitizeForFilename(prompt, maxLength: 40)
        return "\(timestamp)_\(sanitized).mp4"
    }

    /// Save image data to the organized output directory
    @MainActor
    static func saveGeneratedImage(_ data: Data, prompt: String, seed: Int, index: Int = 0) throws -> String {
        let dir = outputDirectory(for: "images")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let filename = uniqueImageFilename(prompt: prompt, seed: seed, index: index)
        let fullPath = "\(dir)/\(filename)"

        try data.write(to: URL(fileURLWithPath: fullPath))
        logInfo("Saved image: \(fullPath)", category: "FileOrganizer")
        return fullPath
    }

    /// Save metadata JSON alongside a generated file
    static func saveMetadata(_ metadata: GenerationMetadata, alongside filePath: String) {
        let metadataPath = (filePath as NSString).deletingPathExtension + "_metadata.json"
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: URL(fileURLWithPath: metadataPath))
        } catch {
            logWarning("Failed to save metadata: \(error.localizedDescription)", category: "FileOrganizer")
        }
    }

    /// Sanitize a string for use in a filename
    private static func sanitizeForFilename(_ input: String, maxLength: Int = 50) -> String {
        var sanitized = input
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")

        // Remove anything that's not alphanumeric, underscore, or hyphen
        sanitized = sanitized.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

        // Truncate
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }

        // Fallback if empty
        if sanitized.isEmpty {
            sanitized = "generated"
        }

        return sanitized
    }
}
