//
//  MediaItem.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Type of media item in the gallery
enum MediaType: String, Codable, CaseIterable, Sendable {
    case image = "image"
    case video = "video"
    case audio = "audio"

    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        }
    }
}

/// A media item for the gallery (Phase 5)
struct MediaItem: Identifiable, Codable, Sendable {
    let id: UUID
    let type: MediaType
    let filePath: String
    var thumbnailPath: String?
    let metadata: [String: String]
    let createdAt: Date

    init(type: MediaType, filePath: String, thumbnailPath: String? = nil, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.metadata = metadata
        self.createdAt = Date()
    }

    var fileName: String {
        (filePath as NSString).lastPathComponent
    }
}
