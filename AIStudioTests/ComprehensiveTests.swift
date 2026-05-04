//
//  ComprehensiveTests.swift
//  AIStudioTests
//
//  Comprehensive test suite covering unit, security, integration, functional, and frame tests.
//  Written by Jordan Koch
//  Created: 2026-05-03
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

// MARK: - Unit Tests

final class ChatMessageUnitTests: XCTestCase {

    // MARK: Test 1
    func testChatMessageCreation() {
        let msg = ChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNotNil(msg.id)
    }

    // MARK: Test 2
    func testChatRoleRawValues() {
        XCTAssertEqual(ChatRole.system.rawValue, "system")
        XCTAssertEqual(ChatRole.user.rawValue, "user")
        XCTAssertEqual(ChatRole.assistant.rawValue, "assistant")
    }

    // MARK: Test 3
    func testChatConversationInit() {
        let convo = ChatConversation(title: "Test Chat")
        XCTAssertEqual(convo.title, "Test Chat")
        XCTAssertTrue(convo.messages.isEmpty)
    }

    // MARK: Test 4
    func testChatConversationAddMessage() {
        var convo = ChatConversation()
        let originalUpdate = convo.updatedAt
        let msg = ChatMessage(role: .user, content: "test")
        // Small delay to ensure updatedAt changes
        convo.addMessage(msg)
        XCTAssertEqual(convo.messages.count, 1)
        XCTAssertEqual(convo.messages.first?.content, "test")
        XCTAssertGreaterThanOrEqual(convo.updatedAt, originalUpdate)
    }

    // MARK: Test 5
    func testChatConversationDefaultTitle() {
        let convo = ChatConversation()
        XCTAssertEqual(convo.title, "New Chat")
    }

    // MARK: Test 6
    func testChatMessageCodable() throws {
        let msg = ChatMessage(role: .assistant, content: "Response")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.content, "Response")
    }
}

final class GenerationRequestUnitTests: XCTestCase {

    // MARK: Test 7
    func testImageGenerationRequestDefaults() {
        let req = ImageGenerationRequest(prompt: "a cat")
        XCTAssertEqual(req.prompt, "a cat")
        XCTAssertEqual(req.steps, 20)
        XCTAssertEqual(req.width, 512)
        XCTAssertEqual(req.height, 512)
        XCTAssertEqual(req.seed, -1)
        XCTAssertEqual(req.batchSize, 1)
        XCTAssertEqual(req.cfgScale, 7.0)
        XCTAssertEqual(req.samplerName, "Euler a")
    }

    // MARK: Test 8
    func testImageGenerationRequestCodable() throws {
        let req = ImageGenerationRequest(prompt: "sunset", negativePrompt: "blurry", steps: 30)
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ImageGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.prompt, "sunset")
        XCTAssertEqual(decoded.negativePrompt, "blurry")
        XCTAssertEqual(decoded.steps, 30)
    }

    // MARK: Test 9
    func testImageGenerationRequestCodingKeys() throws {
        let req = ImageGenerationRequest(prompt: "test", negativePrompt: "bad", cfgScale: 9.5)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["negative_prompt"])
        XCTAssertNotNil(json?["cfg_scale"])
        XCTAssertNotNil(json?["sampler_name"])
        XCTAssertNotNil(json?["batch_size"])
    }

    // MARK: Test 10
    func testTTSRequestDefaults() {
        let req = TTSRequest(text: "Hello world")
        XCTAssertEqual(req.text, "Hello world")
        XCTAssertEqual(req.voice, "default")
        XCTAssertEqual(req.speed, 1.0)
        XCTAssertEqual(req.engine, "kokoro")
    }

    // MARK: Test 11
    func testMusicGenRequestDefaults() {
        let req = MusicGenRequest(prompt: "jazz piano")
        XCTAssertEqual(req.duration, 10.0)
        XCTAssertEqual(req.modelSize, "small")
    }

    // MARK: Test 12
    func testTranscriptionRequestDefaults() {
        let req = TranscriptionRequest(audioFilePath: "/tmp/audio.wav")
        XCTAssertEqual(req.model, "base")
        XCTAssertNil(req.language)
    }

    // MARK: Test 13
    func testImageToImageRequestDefaults() {
        let req = ImageToImageRequest(prompt: "enhance", initImages: ["base64data"])
        XCTAssertEqual(req.denoisingStrength, 0.75)
        XCTAssertEqual(req.steps, 20)
        XCTAssertEqual(req.initImages.count, 1)
    }
}

final class BackendConfigurationUnitTests: XCTestCase {

    // MARK: Test 14
    func testBackendTypeDisplayNames() {
        XCTAssertEqual(BackendType.automatic1111.displayName, "Automatic1111")
        XCTAssertEqual(BackendType.comfyUI.displayName, "ComfyUI")
        XCTAssertEqual(BackendType.swarmUI.displayName, "SwarmUI")
        XCTAssertEqual(BackendType.mlxNative.displayName, "MLX Native")
    }

    // MARK: Test 15
    func testBackendTypeDefaultURLs() {
        XCTAssertEqual(BackendType.automatic1111.defaultURL, "http://localhost:7860")
        XCTAssertEqual(BackendType.comfyUI.defaultURL, "http://localhost:8188")
        XCTAssertEqual(BackendType.swarmUI.defaultURL, "http://localhost:7801")
        XCTAssertEqual(BackendType.mlxNative.defaultURL, "")
    }

    // MARK: Test 16
    func testBackendTypeAllCases() {
        XCTAssertEqual(BackendType.allCases.count, 4)
    }

    // MARK: Test 17
    func testBackendStatusDisplayText() {
        XCTAssertEqual(BackendStatus.connected.displayText, "Connected")
        XCTAssertEqual(BackendStatus.disconnected.displayText, "Disconnected")
        XCTAssertEqual(BackendStatus.checking.displayText, "Checking...")
        XCTAssertEqual(BackendStatus.error("timeout").displayText, "Error: timeout")
    }

    // MARK: Test 18
    func testBackendStatusIsConnected() {
        XCTAssertTrue(BackendStatus.connected.isConnected)
        XCTAssertFalse(BackendStatus.disconnected.isConnected)
        XCTAssertFalse(BackendStatus.checking.isConnected)
        XCTAssertFalse(BackendStatus.error("fail").isConnected)
    }

    // MARK: Test 19
    func testBackendStatusEquatable() {
        XCTAssertEqual(BackendStatus.connected, BackendStatus.connected)
        XCTAssertNotEqual(BackendStatus.connected, BackendStatus.disconnected)
        XCTAssertEqual(BackendStatus.error("x"), BackendStatus.error("x"))
        XCTAssertNotEqual(BackendStatus.error("a"), BackendStatus.error("b"))
    }

    // MARK: Test 20
    func testBackendConfigurationInit() {
        let config = BackendConfiguration(type: .automatic1111)
        XCTAssertEqual(config.type, .automatic1111)
        XCTAssertEqual(config.url, "http://localhost:7860")
        XCTAssertEqual(config.name, "Automatic1111")
        XCTAssertEqual(config.status, .disconnected)
    }

    // MARK: Test 21
    func testBackendConfigurationCustomURL() {
        let config = BackendConfiguration(type: .comfyUI, url: "http://myhost:9999", name: "Custom")
        XCTAssertEqual(config.url, "http://myhost:9999")
        XCTAssertEqual(config.name, "Custom")
    }
}

final class LLMBackendTypeUnitTests: XCTestCase {

    // MARK: Test 22
    func testLLMBackendTypeAllCases() {
        XCTAssertEqual(LLMBackendType.allCases.count, 6)
    }

    // MARK: Test 23
    func testLLMBackendTypeDefaultURLs() {
        XCTAssertEqual(LLMBackendType.ollama.defaultURL, "http://localhost:11434")
        XCTAssertEqual(LLMBackendType.tinyLLM.defaultURL, "http://localhost:8000")
        XCTAssertEqual(LLMBackendType.openWebUI.defaultURL, "http://localhost:8080")
        XCTAssertEqual(LLMBackendType.mlx.defaultURL, "")
        XCTAssertEqual(LLMBackendType.auto.defaultURL, "")
    }

    // MARK: Test 24
    func testLLMBackendTypeAttribution() {
        XCTAssertNotNil(LLMBackendType.tinyLLM.attribution)
        XCTAssertNotNil(LLMBackendType.tinyChat.attribution)
        XCTAssertNotNil(LLMBackendType.openWebUI.attribution)
        XCTAssertNil(LLMBackendType.ollama.attribution)
        XCTAssertNil(LLMBackendType.mlx.attribution)
    }

    // MARK: Test 25
    func testLLMBackendConfigurationInit() {
        let config = LLMBackendConfiguration(type: .ollama)
        XCTAssertEqual(config.type, .ollama)
        XCTAssertEqual(config.url, "http://localhost:11434")
        XCTAssertEqual(config.status, .disconnected)
    }
}

final class MediaItemUnitTests: XCTestCase {

    // MARK: Test 26
    func testMediaTypeIcons() {
        XCTAssertEqual(MediaType.image.icon, "photo")
        XCTAssertEqual(MediaType.video.icon, "film")
        XCTAssertEqual(MediaType.audio.icon, "waveform")
    }

    // MARK: Test 27
    func testMediaItemFileName() {
        let item = MediaItem(type: .image, filePath: "/path/to/image.png")
        XCTAssertEqual(item.fileName, "image.png")
    }

    // MARK: Test 28
    func testMediaItemCodable() throws {
        let item = MediaItem(type: .video, filePath: "/tmp/video.mp4", metadata: ["prompt": "test"])
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
        XCTAssertEqual(decoded.type, .video)
        XCTAssertEqual(decoded.filePath, "/tmp/video.mp4")
        XCTAssertEqual(decoded.metadata["prompt"], "test")
    }

    // MARK: Test 29
    func testMediaTypeAllCases() {
        XCTAssertEqual(MediaType.allCases.count, 3)
    }
}

// MARK: - Security Tests

final class AIStudioSecurityTests: XCTestCase {

    // MARK: Test 30 - Path Traversal Prevention
    func testValidateFilePathBlocksTraversal() {
        XCTAssertFalse(SecurityUtils.validateFilePath("../../etc/passwd"))
        XCTAssertFalse(SecurityUtils.validateFilePath("/tmp/../../../etc/shadow"))
        XCTAssertFalse(SecurityUtils.validateFilePath(""))
        XCTAssertFalse(SecurityUtils.validateFilePath("   "))
    }

    // MARK: Test 31 - Valid File Paths
    func testValidateFilePathAllowsLegitimate() {
        XCTAssertTrue(SecurityUtils.validateFilePath("/tmp/test.png"))
        XCTAssertTrue(SecurityUtils.validateFilePath("/Users/test/Documents/image.jpg"))
    }

    // MARK: Test 32 - URL Validation
    func testValidateURLBlocksDangerous() {
        XCTAssertFalse(SecurityUtils.validateURL("javascript:alert(1)"))
        XCTAssertFalse(SecurityUtils.validateURL("ftp://evil.com"))
        XCTAssertFalse(SecurityUtils.validateURL("not a url"))
        XCTAssertFalse(SecurityUtils.validateURL(""))
    }

    // MARK: Test 33 - URL Validation Accepts Safe
    func testValidateURLAllowsSafe() {
        XCTAssertTrue(SecurityUtils.validateURL("http://localhost:7860"))
        XCTAssertTrue(SecurityUtils.validateURL("https://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("file:///tmp/test.png"))
    }

    // MARK: Test 34 - Port Validation
    func testValidatePort() {
        XCTAssertTrue(SecurityUtils.validatePort(80))
        XCTAssertTrue(SecurityUtils.validatePort(1))
        XCTAssertTrue(SecurityUtils.validatePort(65535))
        XCTAssertFalse(SecurityUtils.validatePort(0))
        XCTAssertFalse(SecurityUtils.validatePort(-1))
        XCTAssertFalse(SecurityUtils.validatePort(65536))
    }

    // MARK: Test 35 - HTML Sanitization
    func testSanitizeHTML() {
        let input = "<script>alert('xss')</script>"
        let sanitized = SecurityUtils.sanitizeHTML(input)
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertTrue(sanitized.contains("&lt;script&gt;"))
    }

    // MARK: Test 36 - User Input Sanitization
    func testSanitizeUserInputRemovesControlChars() {
        let input = "Hello\0World\t\r\nTest"
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertFalse(sanitized.contains("\0"))
    }

    // MARK: Test 37 - Prompt Sanitization
    func testSanitizePromptPreservesSDSyntax() {
        let prompt = "(high quality:1.4), [lowered emphasis], a cat"
        let sanitized = SecurityUtils.sanitizePrompt(prompt)
        XCTAssertTrue(sanitized.contains("(high quality:1.4)"))
        XCTAssertTrue(sanitized.contains("[lowered emphasis]"))
    }

    // MARK: Test 38 - Secure Random Generation
    func testGenerateSecureRandomString() {
        let random = SecurityUtils.generateSecureRandomString(length: 32)
        XCTAssertNotNil(random)
        XCTAssertFalse(random!.isEmpty)
    }

    // MARK: Test 39 - Truncation
    func testTruncate() {
        XCTAssertEqual(SecurityUtils.truncate("short", to: 100), "short")
        let longString = String(repeating: "a", count: 200)
        let truncated = SecurityUtils.truncate(longString, to: 50)
        XCTAssertEqual(truncated.count, 50)
        XCTAssertTrue(truncated.hasSuffix("..."))
    }

    // MARK: Test 40 - Null Byte Sanitization in File Paths
    func testSanitizeFilePathRemovesNullBytes() {
        let input = "/tmp/test\0.png"
        let sanitized = SecurityUtils.sanitizeFilePath(input)
        XCTAssertFalse(sanitized.contains("\0"))
    }

    // MARK: Test 41 - Length Validation
    func testValidateLength() {
        XCTAssertTrue(SecurityUtils.validateLength("hello", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("", min: 1, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("toolongstring", min: 1, max: 5))
    }

    // MARK: Test 42 - File Path Over Length Limit
    func testValidateFilePathMaxLength() {
        let longPath = "/" + String(repeating: "a", count: 5000)
        XCTAssertFalse(SecurityUtils.validateFilePath(longPath))
    }
}

// MARK: - Integration Tests

final class AIStudioIntegrationTests: XCTestCase {

    // MARK: Test 43 - Backend Error Descriptions
    func testBackendErrorDescriptions() {
        let errors: [BackendError] = [
            .notConnected, .invalidURL("bad"), .requestFailed(500, "fail"),
            .decodingFailed("parse"), .invalidImageData, .cancelled,
            .timeout, .noImagesReturned, .backendSpecific("custom")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: Test 44 - Generation Metadata Formatted Time
    func testGenerationMetadataFormattedTime() {
        let metadata = GenerationMetadata(
            prompt: "test", negativePrompt: "", steps: 20, samplerName: "Euler a",
            cfgScale: 7.0, width: 512, height: 512, seed: 42,
            backendName: "test", generationTime: 3.456
        )
        XCTAssertEqual(metadata.formattedTime, "3.5s")
    }

    // MARK: Test 45 - Seed Display
    func testGenerationMetadataSeedDisplay() {
        let random = GenerationMetadata(
            prompt: "t", negativePrompt: "", steps: 20, samplerName: "Euler a",
            cfgScale: 7.0, width: 512, height: 512, seed: -1,
            backendName: "t", generationTime: 1.0
        )
        XCTAssertEqual(random.seedDisplay, "Random")

        let specific = GenerationMetadata(
            prompt: "t", negativePrompt: "", steps: 20, samplerName: "Euler a",
            cfgScale: 7.0, width: 512, height: 512, seed: 12345,
            backendName: "t", generationTime: 1.0
        )
        XCTAssertEqual(specific.seedDisplay, "12345")
    }

    // MARK: Test 46 - A1111 Response Decoding
    func testA1111ResponseDecoding() throws {
        let json = """
        {"images": ["aW1hZ2VkYXRh"], "parameters": null, "info": null}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(A1111Response.self, from: data)
        XCTAssertEqual(response.images.count, 1)
    }

    // MARK: Test 47 - A1111 Model Decoding
    func testA1111ModelDecoding() throws {
        let json = """
        {"title": "SD v1.5", "model_name": "sd_v15", "hash": "abc123", "filename": "model.safetensors"}
        """
        let data = json.data(using: .utf8)!
        let model = try JSONDecoder().decode(A1111Model.self, from: data)
        XCTAssertEqual(model.title, "SD v1.5")
        XCTAssertEqual(model.modelName, "sd_v15")
        XCTAssertEqual(model.id, "sd_v15")
    }

    // MARK: Test 48 - A1111 Sampler Decoding
    func testA1111SamplerDecoding() throws {
        let json = """
        {"name": "Euler a", "aliases": ["k_euler_a"]}
        """
        let data = json.data(using: .utf8)!
        let sampler = try JSONDecoder().decode(A1111Sampler.self, from: data)
        XCTAssertEqual(sampler.name, "Euler a")
        XCTAssertEqual(sampler.id, "Euler a")
    }

    // MARK: Test 49 - GeneratedImage Creation
    func testGeneratedImageCreation() {
        let imageData = Data(repeating: 0xFF, count: 100)
        let image = GeneratedImage(imageData: imageData, index: 2)
        XCTAssertEqual(image.imageData.count, 100)
        XCTAssertEqual(image.index, 2)
        XCTAssertNotNil(image.id)
    }

    // MARK: Test 50 - Metadata Codable Round Trip
    func testMetadataCodableRoundTrip() throws {
        let original = GenerationMetadata(
            prompt: "landscape painting", negativePrompt: "ugly", steps: 30,
            samplerName: "DPM++ 2M", cfgScale: 8.5, width: 1024, height: 768,
            seed: 999, backendName: "A1111", generationTime: 5.2
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationMetadata.self, from: data)
        XCTAssertEqual(decoded.prompt, original.prompt)
        XCTAssertEqual(decoded.seed, original.seed)
        XCTAssertEqual(decoded.width, original.width)
    }
}

// MARK: - Functional Tests

final class AIStudioFunctionalTests: XCTestCase {

    // MARK: Test 51 - PromptEntry Creation
    func testPromptEntryCreation() {
        let entry = PromptEntry(prompt: "a landscape", negativePrompt: "blurry", tags: ["nature"])
        XCTAssertEqual(entry.prompt, "a landscape")
        XCTAssertEqual(entry.useCount, 1)
        XCTAssertFalse(entry.isFavorite)
        XCTAssertEqual(entry.tags, ["nature"])
    }

    // MARK: Test 52 - PromptParameters Defaults
    func testPromptParametersDefaults() {
        let params = PromptParameters()
        XCTAssertEqual(params.steps, 20)
        XCTAssertEqual(params.cfgScale, 7.0)
        XCTAssertEqual(params.width, 512)
        XCTAssertEqual(params.height, 512)
        XCTAssertEqual(params.seed, -1)
        XCTAssertEqual(params.samplerName, "Euler a")
    }

    // MARK: Test 53 - PromptSortOrder Cases
    func testPromptSortOrderCases() {
        XCTAssertEqual(PromptSortOrder.allCases.count, 5)
        XCTAssertEqual(PromptSortOrder.newest.rawValue, "Newest")
        XCTAssertEqual(PromptSortOrder.mostUsed.rawValue, "Most Used")
    }

    // MARK: Test 54 - QueuedGeneration Status Values
    func testQueuedGenerationStatusValues() {
        XCTAssertEqual(QueuedGeneration.QueueStatus.pending.rawValue, "Pending")
        XCTAssertEqual(QueuedGeneration.QueueStatus.running.rawValue, "Running")
        XCTAssertEqual(QueuedGeneration.QueueStatus.completed.rawValue, "Completed")
        XCTAssertEqual(QueuedGeneration.QueueStatus.failed.rawValue, "Failed")
        XCTAssertEqual(QueuedGeneration.QueueStatus.cancelled.rawValue, "Cancelled")
    }

    // MARK: Test 55 - GenerationParameters Defaults
    func testGenerationParametersDefaults() {
        let params = GenerationParameters()
        XCTAssertEqual(params.steps, 20)
        XCTAssertEqual(params.cfgScale, 7.0)
        XCTAssertEqual(params.width, 512)
        XCTAssertEqual(params.height, 512)
        XCTAssertEqual(params.seed, -1)
        XCTAssertEqual(params.batchSize, 1)
    }

    // MARK: Test 56 - QueuedGeneration Type Values
    func testQueuedGenerationTypeValues() {
        XCTAssertEqual(QueuedGeneration.GenerationType.textToImage.rawValue, "txt2img")
        XCTAssertEqual(QueuedGeneration.GenerationType.imageToImage.rawValue, "img2img")
        XCTAssertEqual(QueuedGeneration.GenerationType.audio.rawValue, "audio")
        XCTAssertEqual(QueuedGeneration.GenerationType.video.rawValue, "video")
    }

    // MARK: Test 57 - FileOrganizer Unique Image Filename
    func testFileOrganizerUniqueImageFilename() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "A Beautiful Cat", seed: 42)
        XCTAssertTrue(filename.hasSuffix(".png"))
        XCTAssertTrue(filename.contains("a_beautiful_cat"))
        XCTAssertTrue(filename.contains("s42"))
    }

    // MARK: Test 58 - FileOrganizer Unique Image Filename Random Seed
    func testFileOrganizerRandomSeedFilename() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test", seed: -1)
        XCTAssertTrue(filename.contains("srand"))
    }

    // MARK: Test 59 - FileOrganizer Unique Image Filename With Index
    func testFileOrganizerFilenameWithIndex() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test", seed: 1, index: 3)
        XCTAssertTrue(filename.contains("_3.png"))
    }

    // MARK: Test 60 - FileOrganizer Audio Filename
    func testFileOrganizerAudioFilename() {
        let filename = FileOrganizer.uniqueAudioFilename(type: "tts", label: "Hello World")
        XCTAssertTrue(filename.hasSuffix(".wav"))
        XCTAssertTrue(filename.contains("tts"))
        XCTAssertTrue(filename.contains("hello_world"))
    }

    // MARK: Test 61 - FileOrganizer Video Filename
    func testFileOrganizerVideoFilename() {
        let filename = FileOrganizer.uniqueVideoFilename(prompt: "Dancing Robot")
        XCTAssertTrue(filename.hasSuffix(".mp4"))
        XCTAssertTrue(filename.contains("dancing_robot"))
    }

    // MARK: Test 62 - FileOrganizer Sanitizes Special Characters
    func testFileOrganizerSanitizesSpecialChars() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "test@#$%^&*()+=", seed: 1)
        // Should only contain alphanumeric, underscore, hyphen
        let nameOnly = filename.replacingOccurrences(of: ".png", with: "")
        for char in nameOnly {
            XCTAssertTrue(
                char.isLetter || char.isNumber || char == "_" || char == "-",
                "Unexpected character: \(char)"
            )
        }
    }

    // MARK: Test 63 - FileOrganizer Empty Prompt
    func testFileOrganizerEmptyPromptFallback() {
        let filename = FileOrganizer.uniqueImageFilename(prompt: "@#$%", seed: 1)
        XCTAssertTrue(filename.contains("generated"))
    }

    // MARK: Test 64 - PromptEntry Codable
    func testPromptEntryCodable() throws {
        let entry = PromptEntry(prompt: "test prompt", negativePrompt: "bad", tags: ["art", "landscape"])
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PromptEntry.self, from: data)
        XCTAssertEqual(decoded.prompt, entry.prompt)
        XCTAssertEqual(decoded.tags, ["art", "landscape"])
    }

    // MARK: Test 65 - VoiceCloneRequest Defaults
    func testVoiceCloneRequestDefaults() {
        let req = VoiceCloneRequest(text: "test", referenceAudioPath: "/tmp/ref.wav")
        XCTAssertEqual(req.speed, 1.0)
        XCTAssertEqual(req.text, "test")
    }
}

// MARK: - Frame / UI Data Tests

final class AIStudioFrameTests: XCTestCase {

    // MARK: Test 66 - Backend Type Icons
    func testBackendTypeIcons() {
        for backendType in BackendType.allCases {
            XCTAssertFalse(backendType.icon.isEmpty, "\(backendType) should have an icon")
        }
    }

    // MARK: Test 67 - LLM Backend Type Icons
    func testLLMBackendTypeIcons() {
        for backendType in LLMBackendType.allCases {
            XCTAssertFalse(backendType.icon.isEmpty, "\(backendType) should have an icon")
        }
    }

    // MARK: Test 68 - Backend Status Colors
    func testBackendStatusColors() {
        XCTAssertEqual(BackendStatus.connected.statusColor, "green")
        XCTAssertEqual(BackendStatus.disconnected.statusColor, "gray")
        XCTAssertEqual(BackendStatus.checking.statusColor, "yellow")
        XCTAssertEqual(BackendStatus.error("x").statusColor, "red")
    }

    // MARK: Test 69 - Media Type Raw Values
    func testMediaTypeRawValues() {
        XCTAssertEqual(MediaType.image.rawValue, "image")
        XCTAssertEqual(MediaType.video.rawValue, "video")
        XCTAssertEqual(MediaType.audio.rawValue, "audio")
    }

    // MARK: Test 70 - Image Validation Magic Bytes PNG
    func testImageValidationPNG() {
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        pngData.append(Data(repeating: 0x00, count: 100))
        XCTAssertTrue(ImageUtils.validateImageData(pngData))
    }

    // MARK: Test 71 - Image Validation Magic Bytes JPEG
    func testImageValidationJPEG() {
        var jpegData = Data([0xFF, 0xD8, 0xFF])
        jpegData.append(Data(repeating: 0x00, count: 100))
        XCTAssertTrue(ImageUtils.validateImageData(jpegData))
    }

    // MARK: Test 72 - Image Validation Rejects Invalid
    func testImageValidationRejectsInvalid() {
        let badData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])
        XCTAssertFalse(ImageUtils.validateImageData(badData))
    }

    // MARK: Test 73 - Image Validation Rejects Empty
    func testImageValidationRejectsEmpty() {
        XCTAssertFalse(ImageUtils.validateImageData(Data()))
    }

    // MARK: Test 74 - Image Validation Rejects Oversized
    func testImageValidationRejectsOversized() {
        let hugeData = Data(repeating: 0x89, count: 60 * 1024 * 1024)
        XCTAssertFalse(ImageUtils.validateImageData(hugeData))
    }

    // MARK: Test 75 - Base64 Image Decoding
    func testBase64ImageDecoding() {
        let base64 = "aW1hZ2VkYXRh"
        let data = ImageUtils.decodeBase64Image(base64)
        XCTAssertNotNil(data)
    }

    // MARK: Test 76 - Base64 Image With Data URI
    func testBase64ImageWithDataURI() {
        let dataURI = "data:image/png;base64,aW1hZ2VkYXRh"
        let data = ImageUtils.decodeBase64Image(dataURI)
        XCTAssertNotNil(data)
    }

    // MARK: Test 77 - Retry Handler Presets Exist
    func testRetryHandlerPresetsExist() {
        let http = RetryHandler.httpBackend
        XCTAssertEqual(http.maxAttempts, 3)
        XCTAssertEqual(http.baseDelay, 1.0)

        let daemon = RetryHandler.pythonDaemon
        XCTAssertEqual(daemon.maxAttempts, 2)

        let health = RetryHandler.healthCheck
        XCTAssertEqual(health.maxAttempts, 2)
        XCTAssertEqual(health.baseDelay, 0.5)
    }

    // MARK: Test 78 - Retry Handler Custom Init
    func testRetryHandlerCustomInit() {
        let handler = RetryHandler(maxAttempts: 5, baseDelay: 2.0, maxDelay: 60.0) { _ in true }
        XCTAssertEqual(handler.maxAttempts, 5)
        XCTAssertEqual(handler.baseDelay, 2.0)
        XCTAssertEqual(handler.maxDelay, 60.0)
    }
}
