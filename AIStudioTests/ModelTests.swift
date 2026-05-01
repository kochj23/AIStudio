//
//  ModelTests.swift
//  AIStudioTests
//
//  Tests for data models — BackendType, BackendStatus, ChatMessage, MediaItem, etc.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class ModelTests: XCTestCase {

    // MARK: - BackendType

    func testBackendTypeRawValues() {
        XCTAssertEqual(BackendType.automatic1111.rawValue, "automatic1111")
        XCTAssertEqual(BackendType.comfyUI.rawValue, "comfyui")
        XCTAssertEqual(BackendType.swarmUI.rawValue, "swarmui")
        XCTAssertEqual(BackendType.mlxNative.rawValue, "mlx_native")
    }

    func testBackendTypeDisplayNames() {
        XCTAssertEqual(BackendType.automatic1111.displayName, "Automatic1111")
        XCTAssertEqual(BackendType.comfyUI.displayName, "ComfyUI")
        XCTAssertEqual(BackendType.swarmUI.displayName, "SwarmUI")
        XCTAssertEqual(BackendType.mlxNative.displayName, "MLX Native")
    }

    func testBackendTypeDefaultURLs() {
        XCTAssertEqual(BackendType.automatic1111.defaultURL, "http://localhost:7860")
        XCTAssertEqual(BackendType.comfyUI.defaultURL, "http://localhost:8188")
        XCTAssertEqual(BackendType.swarmUI.defaultURL, "http://localhost:7801")
        XCTAssertEqual(BackendType.mlxNative.defaultURL, "")
    }

    func testBackendTypeCaseIterable() {
        XCTAssertEqual(BackendType.allCases.count, 4)
    }

    func testBackendTypeFromRawValue() {
        XCTAssertEqual(BackendType(rawValue: "automatic1111"), .automatic1111)
        XCTAssertEqual(BackendType(rawValue: "comfyui"), .comfyUI)
        XCTAssertNil(BackendType(rawValue: "nonexistent"))
    }

    // MARK: - BackendStatus

    func testBackendStatusConnected() {
        let status = BackendStatus.connected
        XCTAssertTrue(status.isConnected)
        XCTAssertEqual(status.displayText, "Connected")
        XCTAssertEqual(status.statusColor, "green")
    }

    func testBackendStatusDisconnected() {
        let status = BackendStatus.disconnected
        XCTAssertFalse(status.isConnected)
        XCTAssertEqual(status.displayText, "Disconnected")
        XCTAssertEqual(status.statusColor, "gray")
    }

    func testBackendStatusChecking() {
        let status = BackendStatus.checking
        XCTAssertFalse(status.isConnected)
        XCTAssertEqual(status.displayText, "Checking...")
        XCTAssertEqual(status.statusColor, "yellow")
    }

    func testBackendStatusError() {
        let status = BackendStatus.error("Connection refused")
        XCTAssertFalse(status.isConnected)
        XCTAssertTrue(status.displayText.contains("Connection refused"))
        XCTAssertEqual(status.statusColor, "red")
    }

    func testBackendStatusEquality() {
        XCTAssertEqual(BackendStatus.connected, BackendStatus.connected)
        XCTAssertEqual(BackendStatus.disconnected, BackendStatus.disconnected)
        XCTAssertNotEqual(BackendStatus.connected, BackendStatus.disconnected)
        XCTAssertEqual(BackendStatus.error("a"), BackendStatus.error("a"))
        XCTAssertNotEqual(BackendStatus.error("a"), BackendStatus.error("b"))
    }

    // MARK: - BackendConfiguration

    func testBackendConfigurationInit() {
        let config = BackendConfiguration(type: .automatic1111)
        XCTAssertEqual(config.type, .automatic1111)
        XCTAssertEqual(config.url, "http://localhost:7860")
        XCTAssertEqual(config.name, "Automatic1111")
        XCTAssertEqual(config.status, .disconnected)
    }

    func testBackendConfigurationCustomURL() {
        let config = BackendConfiguration(type: .comfyUI, url: "http://192.168.1.100:8188", name: "Remote ComfyUI")
        XCTAssertEqual(config.url, "http://192.168.1.100:8188")
        XCTAssertEqual(config.name, "Remote ComfyUI")
    }

    // MARK: - LLMBackendType

    func testLLMBackendTypeAllCases() {
        XCTAssertEqual(LLMBackendType.allCases.count, 6)
    }

    func testLLMBackendTypeDisplayNames() {
        XCTAssertEqual(LLMBackendType.ollama.displayName, "Ollama")
        XCTAssertEqual(LLMBackendType.mlx.displayName, "MLX Native")
        XCTAssertEqual(LLMBackendType.tinyLLM.displayName, "TinyLLM")
        XCTAssertEqual(LLMBackendType.tinyChat.displayName, "TinyChat")
        XCTAssertEqual(LLMBackendType.openWebUI.displayName, "OpenWebUI")
        XCTAssertEqual(LLMBackendType.auto.displayName, "Auto (Prefer Ollama)")
    }

    func testLLMBackendTypeDefaultURLs() {
        XCTAssertEqual(LLMBackendType.ollama.defaultURL, "http://localhost:11434")
        XCTAssertEqual(LLMBackendType.tinyLLM.defaultURL, "http://localhost:8000")
        XCTAssertEqual(LLMBackendType.tinyChat.defaultURL, "http://localhost:8000")
        XCTAssertEqual(LLMBackendType.openWebUI.defaultURL, "http://localhost:8080")
    }

    func testLLMBackendTypeAttribution() {
        XCTAssertNotNil(LLMBackendType.tinyLLM.attribution)
        XCTAssertNotNil(LLMBackendType.tinyChat.attribution)
        XCTAssertNotNil(LLMBackendType.openWebUI.attribution)
        XCTAssertNil(LLMBackendType.ollama.attribution)
        XCTAssertNil(LLMBackendType.mlx.attribution)
    }

    func testLLMBackendConfigurationInit() {
        let config = LLMBackendConfiguration(type: .ollama)
        XCTAssertEqual(config.type, .ollama)
        XCTAssertEqual(config.url, "http://localhost:11434")
        XCTAssertEqual(config.status, .disconnected)
    }

    // MARK: - ChatMessage

    func testChatMessageInit() {
        let msg = ChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNotNil(msg.id)
        XCTAssertNotNil(msg.timestamp)
    }

    func testChatMessageRoles() {
        XCTAssertEqual(ChatRole.system.rawValue, "system")
        XCTAssertEqual(ChatRole.user.rawValue, "user")
        XCTAssertEqual(ChatRole.assistant.rawValue, "assistant")
    }

    func testChatMessageCodable() throws {
        let msg = ChatMessage(role: .user, content: "Test message")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, msg.role)
        XCTAssertEqual(decoded.content, msg.content)
    }

    func testChatConversation() {
        var conv = ChatConversation(title: "Test")
        XCTAssertEqual(conv.title, "Test")
        XCTAssertTrue(conv.messages.isEmpty)

        let msg = ChatMessage(role: .user, content: "Hello")
        conv.addMessage(msg)
        XCTAssertEqual(conv.messages.count, 1)
        XCTAssertEqual(conv.messages[0].content, "Hello")
    }

    func testChatConversationUpdatesTimestamp() {
        var conv = ChatConversation()
        let initialUpdate = conv.updatedAt
        // Small delay to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        conv.addMessage(ChatMessage(role: .user, content: "test"))
        XCTAssertGreaterThan(conv.updatedAt, initialUpdate)
    }

    // MARK: - MediaItem

    func testMediaItemInit() {
        let item = MediaItem(type: .image, filePath: "/tmp/test.png")
        XCTAssertEqual(item.type, .image)
        XCTAssertEqual(item.filePath, "/tmp/test.png")
        XCTAssertNil(item.thumbnailPath)
        XCTAssertTrue(item.metadata.isEmpty)
    }

    func testMediaItemFileName() {
        let item = MediaItem(type: .image, filePath: "/tmp/output/2026-01-01/images/test_image.png")
        XCTAssertEqual(item.fileName, "test_image.png")
    }

    func testMediaTypeIcons() {
        XCTAssertEqual(MediaType.image.icon, "photo")
        XCTAssertEqual(MediaType.video.icon, "film")
        XCTAssertEqual(MediaType.audio.icon, "waveform")
    }

    func testMediaTypeCaseIterable() {
        XCTAssertEqual(MediaType.allCases.count, 3)
    }

    // MARK: - ImageGenerationRequest

    func testImageGenerationRequestDefaults() {
        let request = ImageGenerationRequest(prompt: "a cat")
        XCTAssertEqual(request.prompt, "a cat")
        XCTAssertEqual(request.negativePrompt, "")
        XCTAssertEqual(request.steps, 20)
        XCTAssertEqual(request.samplerName, "Euler a")
        XCTAssertEqual(request.cfgScale, 7.0)
        XCTAssertEqual(request.width, 512)
        XCTAssertEqual(request.height, 512)
        XCTAssertEqual(request.seed, -1)
        XCTAssertEqual(request.batchSize, 1)
        XCTAssertNil(request.checkpointName)
    }

    func testImageGenerationRequestCodable() throws {
        let request = ImageGenerationRequest(
            prompt: "test",
            negativePrompt: "bad",
            steps: 30,
            cfgScale: 9.0,
            width: 1024,
            height: 1024,
            seed: 42
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ImageGenerationRequest.self, from: data)
        XCTAssertEqual(decoded.prompt, "test")
        XCTAssertEqual(decoded.negativePrompt, "bad")
        XCTAssertEqual(decoded.steps, 30)
        XCTAssertEqual(decoded.seed, 42)
    }

    func testImageGenerationRequestCodingKeys() throws {
        let request = ImageGenerationRequest(prompt: "test", negativePrompt: "bad")
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["negative_prompt"])
        XCTAssertNotNil(json?["sampler_name"])
        XCTAssertNotNil(json?["cfg_scale"])
        XCTAssertNotNil(json?["batch_size"])
    }

    // MARK: - TTSRequest

    func testTTSRequestDefaults() {
        let request = TTSRequest(text: "Hello world")
        XCTAssertEqual(request.text, "Hello world")
        XCTAssertEqual(request.voice, "default")
        XCTAssertEqual(request.speed, 1.0)
        XCTAssertEqual(request.engine, "kokoro")
    }

    // MARK: - GenerationMetadata

    func testGenerationMetadataFormattedTime() {
        let metadata = GenerationMetadata(
            prompt: "test", negativePrompt: "", steps: 20,
            samplerName: "Euler a", cfgScale: 7.0,
            width: 512, height: 512, seed: 42,
            backendName: "A1111", generationTime: 3.456
        )
        XCTAssertEqual(metadata.formattedTime, "3.5s")
    }

    func testGenerationMetadataSeedDisplay() {
        let randomSeed = GenerationMetadata(
            prompt: "", negativePrompt: "", steps: 20,
            samplerName: "Euler a", cfgScale: 7.0,
            width: 512, height: 512, seed: -1,
            backendName: "test", generationTime: 0
        )
        XCTAssertEqual(randomSeed.seedDisplay, "Random")

        let fixedSeed = GenerationMetadata(
            prompt: "", negativePrompt: "", steps: 20,
            samplerName: "Euler a", cfgScale: 7.0,
            width: 512, height: 512, seed: 42,
            backendName: "test", generationTime: 0
        )
        XCTAssertEqual(fixedSeed.seedDisplay, "42")
    }

    // MARK: - GeneratedImage

    func testGeneratedImageInit() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let image = GeneratedImage(imageData: data, index: 2)
        XCTAssertEqual(image.index, 2)
        XCTAssertEqual(image.imageData, data)
        XCTAssertNotNil(image.id)
    }

    // MARK: - BackendError

    func testBackendErrorDescriptions() {
        XCTAssertNotNil(BackendError.notConnected.errorDescription)
        XCTAssertNotNil(BackendError.invalidURL("test").errorDescription)
        XCTAssertNotNil(BackendError.requestFailed(500, "error").errorDescription)
        XCTAssertNotNil(BackendError.decodingFailed("detail").errorDescription)
        XCTAssertNotNil(BackendError.invalidImageData.errorDescription)
        XCTAssertNotNil(BackendError.cancelled.errorDescription)
        XCTAssertNotNil(BackendError.timeout.errorDescription)
        XCTAssertNotNil(BackendError.noImagesReturned.errorDescription)
        XCTAssertNotNil(BackendError.backendSpecific("custom").errorDescription)
    }

    func testBackendErrorMessages() {
        let urlError = BackendError.invalidURL("bad://url")
        XCTAssertTrue(urlError.errorDescription!.contains("bad://url"))

        let httpError = BackendError.requestFailed(404, "Not Found")
        XCTAssertTrue(httpError.errorDescription!.contains("404"))
        XCTAssertTrue(httpError.errorDescription!.contains("Not Found"))
    }

    // MARK: - LLMError

    func testLLMErrorDescriptions() {
        XCTAssertNotNil(LLMError.noBackendAvailable.errorDescription)
        XCTAssertNotNil(LLMError.invalidURL.errorDescription)
        XCTAssertNotNil(LLMError.invalidResponse.errorDescription)
        XCTAssertNotNil(LLMError.httpError(500).errorDescription)
        XCTAssertNotNil(LLMError.noResponse.errorDescription)
        XCTAssertNotNil(LLMError.mlxNotAvailable.errorDescription)
    }

    func testLLMErrorHttpErrorContainsCode() {
        let error = LLMError.httpError(429)
        XCTAssertTrue(error.errorDescription!.contains("429"))
    }

    // MARK: - PromptEntry

    func testPromptEntryInit() {
        let entry = PromptEntry(
            prompt: "a beautiful sunset",
            negativePrompt: "ugly",
            tags: ["landscape", "sunset"]
        )
        XCTAssertEqual(entry.prompt, "a beautiful sunset")
        XCTAssertEqual(entry.negativePrompt, "ugly")
        XCTAssertFalse(entry.isFavorite)
        XCTAssertEqual(entry.useCount, 1)
        XCTAssertEqual(entry.tags, ["landscape", "sunset"])
    }

    func testPromptParametersDefaults() {
        let params = PromptParameters()
        XCTAssertEqual(params.steps, 20)
        XCTAssertEqual(params.cfgScale, 7.0)
        XCTAssertEqual(params.width, 512)
        XCTAssertEqual(params.height, 512)
        XCTAssertEqual(params.seed, -1)
        XCTAssertEqual(params.samplerName, "Euler a")
    }

    func testPromptSortOrderCases() {
        XCTAssertEqual(PromptSortOrder.allCases.count, 5)
    }

    // MARK: - QueuedGeneration

    func testQueuedGenerationInit() {
        let item = QueuedGeneration(
            prompt: "a cat",
            negativePrompt: "bad quality",
            parameters: GenerationParameters(),
            type: .textToImage
        )
        XCTAssertEqual(item.prompt, "a cat")
        XCTAssertEqual(item.negativePrompt, "bad quality")
        XCTAssertEqual(item.status, .pending)
        XCTAssertNil(item.result)
        XCTAssertNil(item.error)
        XCTAssertNil(item.startedAt)
        XCTAssertNil(item.completedAt)
    }

    func testGenerationParametersDefaults() {
        let params = GenerationParameters()
        XCTAssertEqual(params.steps, 20)
        XCTAssertEqual(params.cfgScale, 7.0)
        XCTAssertEqual(params.width, 512)
        XCTAssertEqual(params.height, 512)
        XCTAssertEqual(params.seed, -1)
        XCTAssertEqual(params.samplerName, "Euler a")
        XCTAssertEqual(params.batchSize, 1)
    }

    func testQueueStatusRawValues() {
        XCTAssertEqual(QueuedGeneration.QueueStatus.pending.rawValue, "Pending")
        XCTAssertEqual(QueuedGeneration.QueueStatus.running.rawValue, "Running")
        XCTAssertEqual(QueuedGeneration.QueueStatus.completed.rawValue, "Completed")
        XCTAssertEqual(QueuedGeneration.QueueStatus.failed.rawValue, "Failed")
        XCTAssertEqual(QueuedGeneration.QueueStatus.cancelled.rawValue, "Cancelled")
    }

    // MARK: - A1111 Response Models

    func testA1111ModelCodable() throws {
        let json = """
        {"title": "v1-5-pruned.safetensors", "model_name": "v1-5-pruned", "hash": "abc123", "filename": "v1-5-pruned.safetensors"}
        """
        let model = try JSONDecoder().decode(A1111Model.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(model.title, "v1-5-pruned.safetensors")
        XCTAssertEqual(model.modelName, "v1-5-pruned")
        XCTAssertEqual(model.id, "v1-5-pruned")
    }

    func testA1111SamplerCodable() throws {
        let json = """
        {"name": "Euler a", "aliases": ["euler_a"]}
        """
        let sampler = try JSONDecoder().decode(A1111Sampler.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(sampler.name, "Euler a")
        XCTAssertEqual(sampler.id, "Euler a")
    }
}
