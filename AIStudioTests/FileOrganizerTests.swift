//
//  FileOrganizerTests.swift
//  AIStudioTests
//
//  Tests for FileOrganizer — date-based directory organization and filename generation.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class FileOrganizerTests: XCTestCase {

    // MARK: - Unique Image Filename

    func testUniqueImageFilenameFormat() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "a beautiful sunset", seed: 42)
        XCTAssertTrue(filename.hasSuffix(".png"))
        XCTAssertTrue(filename.contains("a_beautiful_sunset"))
        XCTAssertTrue(filename.contains("s42"))
    }

    func testUniqueImageFilenameRandomSeed() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test", seed: -1)
        XCTAssertTrue(filename.contains("srand"))
    }

    func testUniqueImageFilenameWithIndex() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test", seed: 42, index: 3)
        XCTAssertTrue(filename.contains("_3.png"))
    }

    func testUniqueImageFilenameNoIndex() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test", seed: 42, index: 0)
        XCTAssertFalse(filename.contains("_0.png"))
        XCTAssertTrue(filename.hasSuffix("s42.png"))
    }

    func testUniqueImageFilenameSanitization() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "hello @#$% world!!!", seed: 1)
        // Only alphanumeric, underscore, hyphen should remain
        let nameOnly = (filename as NSString).deletingPathExtension
        for char in nameOnly {
            XCTAssertTrue(
                char.isLetter || char.isNumber || char == "_" || char == "-",
                "Unexpected character in filename: \(char)"
            )
        }
    }

    func testUniqueImageFilenameTruncation() {
        let longPrompt = String(repeating: "word ", count: 100)
        let filename = FileOrganizer.uniqueImageFilename(prompt: longPrompt, seed: 1)
        // Prompt part should be truncated to 40 characters
        XCTAssertTrue(filename.count < 200, "Filename should be reasonably short")
    }

    func testUniqueImageFilenameEmptyPrompt() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "", seed: 1)
        XCTAssertTrue(filename.contains("generated"))
    }

    func testUniqueImageFilenameSpecialCharsOnly() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "@#$%^&*()", seed: 1)
        XCTAssertTrue(filename.contains("generated"))
    }

    // MARK: - Unique Audio Filename

    func testUniqueAudioFilename() {
        let filename = FileOrganizer.uniqueAudioFilename(type: "tts", label: "Hello World")
        XCTAssertTrue(filename.hasSuffix(".wav"))
        XCTAssertTrue(filename.contains("tts"))
        XCTAssertTrue(filename.contains("hello_world"))
    }

    // MARK: - Unique Video Filename

    func testUniqueVideoFilename() {
        let filename = FileOrganizer.uniqueVideoFilename(prompt: "dancing cat")
        XCTAssertTrue(filename.hasSuffix(".mp4"))
        XCTAssertTrue(filename.contains("dancing_cat"))
    }

    // MARK: - Output Directory

    @MainActor
    func testOutputDirectoryContainsDate() {
        let dir = FileOrganizer.outputDirectory(for: "images", baseDir: "/tmp/test_output")
        // Should contain today's date in yyyy-MM-dd format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        XCTAssertTrue(dir.contains(today))
        XCTAssertTrue(dir.contains("/images"))
    }

    @MainActor
    func testOutputDirectoryCustomBase() {
        let dir = FileOrganizer.outputDirectory(for: "videos", baseDir: "/custom/path")
        XCTAssertTrue(dir.hasPrefix("/custom/path"))
        XCTAssertTrue(dir.hasSuffix("/videos"))
    }

    // MARK: - Save and Metadata

    @MainActor
    func testSaveGeneratedImage() throws {
        // Create a minimal PNG
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        guard let pngData = ImageUtils.pngData(from: image) else {
            XCTFail("Failed to create PNG data")
            return
        }

        let tempBase = NSTemporaryDirectory() + "aistudio_test_\(UUID().uuidString)"
        let path = try FileOrganizer.saveGeneratedImage(
            pngData,
            prompt: "test image",
            seed: 42,
            index: 0
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertTrue(path.hasSuffix(".png"))

        // Cleanup
        try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent)
    }

    func testSaveMetadata() {
        let metadata = GenerationMetadata(
            prompt: "test", negativePrompt: "", steps: 20,
            samplerName: "Euler a", cfgScale: 7.0,
            width: 512, height: 512, seed: 42,
            backendName: "test", generationTime: 1.5
        )

        let tempPath = NSTemporaryDirectory() + "aistudio_test_\(UUID().uuidString).png"
        FileManager.default.createFile(atPath: tempPath, contents: Data())

        FileOrganizer.saveMetadata(metadata, alongside: tempPath)

        let metadataPath = (tempPath as NSString).deletingPathExtension + "_metadata.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataPath))

        // Verify JSON is valid
        if let data = FileManager.default.contents(atPath: metadataPath) {
            let decoded = try? JSONDecoder().decode(GenerationMetadata.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.prompt, "test")
            XCTAssertEqual(decoded?.seed, 42)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
        try? FileManager.default.removeItem(atPath: metadataPath)
    }
}
