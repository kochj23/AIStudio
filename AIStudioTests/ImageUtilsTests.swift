//
//  ImageUtilsTests.swift
//  AIStudioTests
//
//  Tests for ImageUtils — image validation, base64 decoding, thumbnails.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class ImageUtilsTests: XCTestCase {

    // MARK: - PNG Validation

    func testValidPNGData() {
        // Minimal valid PNG header
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        pngData.append(Data(repeating: 0, count: 100))
        XCTAssertTrue(ImageUtils.validateImageData(pngData))
    }

    func testValidJPEGData() {
        // JPEG magic bytes
        var jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        jpegData.append(Data(repeating: 0, count: 100))
        XCTAssertTrue(ImageUtils.validateImageData(jpegData))
    }

    func testInvalidImageData() {
        let textData = "This is not an image".data(using: .utf8)!
        XCTAssertFalse(ImageUtils.validateImageData(textData))
    }

    func testEmptyData() {
        XCTAssertFalse(ImageUtils.validateImageData(Data()))
    }

    func testTooSmallData() {
        let smallData = Data([0x89, 0x50])
        XCTAssertFalse(ImageUtils.validateImageData(smallData))
    }

    func testOversizedImageData() {
        // 51 MB — exceeds the 50 MB limit
        let oversized = Data(repeating: 0x89, count: 51 * 1024 * 1024)
        XCTAssertFalse(ImageUtils.validateImageData(oversized))
    }

    func testMaxSizeConstant() {
        XCTAssertEqual(ImageUtils.maxImageSize, 50 * 1024 * 1024)
    }

    // MARK: - Base64 Decoding

    func testDecodeBase64Image() {
        let original = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let base64String = original.base64EncodedString()
        let decoded = ImageUtils.decodeBase64Image(base64String)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeBase64WithDataURI() {
        let original = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let base64String = "data:image/png;base64," + original.base64EncodedString()
        let decoded = ImageUtils.decodeBase64Image(base64String)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeInvalidBase64() {
        let decoded = ImageUtils.decodeBase64Image("not-valid-base64!!!")
        XCTAssertNil(decoded)
    }

    // MARK: - Image Save Error

    func testImageSaveErrorDescriptions() {
        XCTAssertNotNil(ImageUtils.ImageSaveError.invalidData.errorDescription)
        XCTAssertNotNil(ImageUtils.ImageSaveError.writeFailed("/test/path").errorDescription)
    }

    // MARK: - Save Image (File System)

    func testSaveImageInvalidData() {
        let badData = "not an image".data(using: .utf8)!
        XCTAssertThrowsError(try ImageUtils.saveImage(badData, to: "/tmp/test_bad.png")) { error in
            XCTAssertTrue(error is ImageUtils.ImageSaveError)
        }
    }

    func testSaveImageValidData() throws {
        // Create a minimal 1x1 pixel PNG
        let pngData = createMinimalPNG()
        let path = NSTemporaryDirectory() + "aistudio_test_\(UUID().uuidString).png"

        try ImageUtils.saveImage(pngData, to: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        // Cleanup
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Helpers

    /// Creates a minimal valid 1x1 red pixel PNG
    private func createMinimalPNG() -> Data {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        return ImageUtils.pngData(from: image)!
    }
}
