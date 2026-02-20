//
//  ImageUtils.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

enum ImageUtils {

    /// Maximum allowed image data size (50 MB)
    static let maxImageSize: Int = 50 * 1024 * 1024

    /// PNG magic bytes
    private static let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// JPEG magic bytes
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]

    /// Validate that image data is a real PNG or JPEG (check magic bytes)
    static func validateImageData(_ data: Data) -> Bool {
        guard data.count > 8 else { return false }
        guard data.count <= maxImageSize else {
            logWarning("Image data exceeds maximum size: \(data.count) bytes", category: "ImageUtils")
            return false
        }

        let bytes = [UInt8](data.prefix(8))

        // Check PNG
        if bytes.starts(with: pngMagic) { return true }

        // Check JPEG
        if bytes.starts(with: jpegMagic) { return true }

        logWarning("Image data failed magic byte validation", category: "ImageUtils")
        return false
    }

    /// Decode a base64-encoded image string to Data
    static func decodeBase64Image(_ base64String: String) -> Data? {
        // Strip data URI prefix if present
        var cleaned = base64String
        if let range = cleaned.range(of: ";base64,") {
            cleaned = String(cleaned[range.upperBound...])
        }
        return Data(base64Encoded: cleaned)
    }

    /// Create an NSImage from raw image data
    static func imageFromData(_ data: Data) -> NSImage? {
        guard validateImageData(data) else { return nil }
        return NSImage(data: data)
    }

    /// Generate a thumbnail from an NSImage
    static func generateThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return nil }

        let scale: CGFloat
        if originalSize.width > originalSize.height {
            scale = maxSize / originalSize.width
        } else {
            scale = maxSize / originalSize.height
        }

        // If already small enough, return as-is
        if scale >= 1.0 { return image }

        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                    from: NSRect(origin: .zero, size: originalSize),
                    operation: .copy,
                    fraction: 1.0)
        thumbnail.unlockFocus()

        return thumbnail
    }

    /// Save image data to a file path
    static func saveImage(_ data: Data, to path: String) throws {
        guard validateImageData(data) else {
            throw ImageSaveError.invalidData
        }

        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try data.write(to: url)
        logInfo("Image saved to: \(path)", category: "ImageUtils")
    }

    /// Convert NSImage to PNG data
    static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    enum ImageSaveError: LocalizedError {
        case invalidData
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid image data"
            case .writeFailed(let path): return "Failed to write image to \(path)"
            }
        }
    }
}
