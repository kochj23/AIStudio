//
//  GalleryService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

/// Scans the output directory for generated media and builds a MediaItem index.
actor GalleryService {
    private var items: [MediaItem] = []
    private let fileManager = FileManager.default

    /// Scan the output directory and build the media index
    @MainActor
    func scanOutputDirectory() async -> [MediaItem] {
        let baseDir = AppSettings.shared.outputDirectory
        return await scan(baseDir: baseDir)
    }

    private func scan(baseDir: String) -> [MediaItem] {
        var results: [MediaItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: baseDir),
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            let mediaType: MediaType?

            switch ext {
            case "png", "jpg", "jpeg", "webp":
                mediaType = .image
            case "mp4", "mov", "avi":
                mediaType = .video
            case "wav", "mp3", "m4a", "flac":
                mediaType = .audio
            default:
                mediaType = nil
            }

            guard let type = mediaType else { continue }

            // Skip metadata files
            if fileURL.lastPathComponent.contains("_metadata") { continue }

            // Load metadata if available
            let metadataPath = fileURL.deletingPathExtension().path + "_metadata.json"
            var metadata: [String: String] = [:]
            if let metaData = fileManager.contents(atPath: metadataPath),
               let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                for (key, value) in json {
                    metadata[key] = "\(value)"
                }
            }

            let item = MediaItem(
                type: type,
                filePath: fileURL.path,
                thumbnailPath: nil,
                metadata: metadata
            )
            results.append(item)
        }

        // Sort by creation date (newest first)
        results.sort { $0.createdAt > $1.createdAt }
        items = results
        return results
    }

    /// Generate thumbnails for image items that don't have them
    func generateThumbnails(for items: [MediaItem]) -> [MediaItem] {
        return items.map { item in
            guard item.type == .image, item.thumbnailPath == nil else { return item }

            let thumbnailDir = (item.filePath as NSString).deletingLastPathComponent + "/.thumbnails"
            try? fileManager.createDirectory(atPath: thumbnailDir, withIntermediateDirectories: true)

            let thumbPath = thumbnailDir + "/" + (item.filePath as NSString).lastPathComponent

            if !fileManager.fileExists(atPath: thumbPath),
               let image = NSImage(contentsOfFile: item.filePath),
               let thumbnail = ImageUtils.generateThumbnail(from: image),
               let pngData = ImageUtils.pngData(from: thumbnail) {
                try? pngData.write(to: URL(fileURLWithPath: thumbPath))
            }

            var updated = item
            updated.thumbnailPath = thumbPath
            return updated
        }
    }

    /// Delete a media item and its metadata
    func deleteItem(_ item: MediaItem) throws {
        try fileManager.removeItem(atPath: item.filePath)

        let metadataPath = (item.filePath as NSString).deletingPathExtension + "_metadata.json"
        if fileManager.fileExists(atPath: metadataPath) {
            try fileManager.removeItem(atPath: metadataPath)
        }

        if let thumbPath = item.thumbnailPath, fileManager.fileExists(atPath: thumbPath) {
            try fileManager.removeItem(atPath: thumbPath)
        }

        items.removeAll { $0.id == item.id }
    }
}
