//
//  MediaExportService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

/// Handles saving and exporting media files to organized directories.
enum MediaExportService {

    /// Maximum allowed file sizes
    static let maxImageSize: Int = 50 * 1024 * 1024  // 50 MB
    static let maxAudioSize: Int = 100 * 1024 * 1024  // 100 MB
    static let maxVideoSize: Int = 500 * 1024 * 1024  // 500 MB

    /// Save audio data to the output directory
    @MainActor
    static func saveAudio(_ data: Data, type: String, label: String) throws -> String {
        guard data.count <= maxAudioSize else {
            throw ExportError.fileTooLarge("Audio file exceeds \(maxAudioSize / 1024 / 1024) MB limit")
        }

        let dir = FileOrganizer.outputDirectory(for: "audio")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let filename = FileOrganizer.uniqueAudioFilename(type: type, label: label)
        let fullPath = "\(dir)/\(filename)"

        try data.write(to: URL(fileURLWithPath: fullPath))
        logInfo("Saved audio: \(fullPath)", category: "MediaExport")
        return fullPath
    }

    /// Save video data to the output directory
    @MainActor
    static func saveVideo(_ data: Data, prompt: String) throws -> String {
        guard data.count <= maxVideoSize else {
            throw ExportError.fileTooLarge("Video file exceeds \(maxVideoSize / 1024 / 1024) MB limit")
        }

        let dir = FileOrganizer.outputDirectory(for: "videos")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let filename = FileOrganizer.uniqueVideoFilename(prompt: prompt)
        let fullPath = "\(dir)/\(filename)"

        try data.write(to: URL(fileURLWithPath: fullPath))
        logInfo("Saved video: \(fullPath)", category: "MediaExport")
        return fullPath
    }

    /// Open the output directory in Finder
    @MainActor
    static func revealInFinder() {
        let path = AppSettings.shared.outputDirectory
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Open a specific file in Finder
    static func revealFileInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    enum ExportError: LocalizedError {
        case fileTooLarge(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let msg): return msg
            case .writeFailed(let msg): return "Failed to write: \(msg)"
            }
        }
    }
}
