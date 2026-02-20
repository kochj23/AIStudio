//
//  LLMBackendManager.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Manages all LLM backends: Ollama, MLX, TinyLLM, TinyChat, OpenWebUI.
/// Owns backend configurations, runs health checks, provides unified generate interface.
@MainActor
class LLMBackendManager: ObservableObject {
    @Published var backends: [LLMBackendType: LLMBackendConfiguration] = [:]
    @Published var activeLLMBackendType: LLMBackendType = .auto
    @Published var resolvedBackend: LLMBackendType? = nil
    @Published var isRefreshing: Bool = false

    // Ollama-specific
    @Published var ollamaModels: [String] = []
    @Published var selectedOllamaModel: String = "mistral:latest"

    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        let settings = AppSettings.shared

        backends[.ollama] = LLMBackendConfiguration(type: .ollama, url: settings.ollamaURL)
        backends[.tinyLLM] = LLMBackendConfiguration(type: .tinyLLM, url: settings.tinyLLMURL)
        backends[.tinyChat] = LLMBackendConfiguration(type: .tinyChat, url: settings.tinyChatURL)
        backends[.openWebUI] = LLMBackendConfiguration(type: .openWebUI, url: settings.openWebUIURL)
        backends[.mlx] = LLMBackendConfiguration(type: .mlx)

        if let savedType = LLMBackendType(rawValue: settings.activeLLMBackendType) {
            activeLLMBackendType = savedType
        }
        selectedOllamaModel = settings.selectedOllamaModel

        // Listen for settings changes
        settings.$ollamaURL.removeDuplicates().sink { [weak self] url in
            self?.backends[.ollama]?.url = url
        }.store(in: &cancellables)

        settings.$tinyLLMURL.removeDuplicates().sink { [weak self] url in
            self?.backends[.tinyLLM]?.url = url
        }.store(in: &cancellables)

        settings.$tinyChatURL.removeDuplicates().sink { [weak self] url in
            self?.backends[.tinyChat]?.url = url
        }.store(in: &cancellables)

        settings.$openWebUIURL.removeDuplicates().sink { [weak self] url in
            self?.backends[.openWebUI]?.url = url
        }.store(in: &cancellables)
    }

    // MARK: - Health Checks

    func refreshAllBackends() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: (LLMBackendType, BackendStatus).self) { group in
            group.addTask { [weak self] in
                let status = await self?.checkOllama() ?? .disconnected
                return (.ollama, status)
            }
            group.addTask { [weak self] in
                let status = await self?.checkTinyLLM() ?? .disconnected
                return (.tinyLLM, status)
            }
            group.addTask { [weak self] in
                let status = await self?.checkTinyChat() ?? .disconnected
                return (.tinyChat, status)
            }
            group.addTask { [weak self] in
                let status = await self?.checkOpenWebUI() ?? .disconnected
                return (.openWebUI, status)
            }
            group.addTask { [weak self] in
                let status = await self?.checkMLX() ?? .disconnected
                return (.mlx, status)
            }

            for await (type, status) in group {
                backends[type]?.status = status
            }
        }

        determineActiveBackend()
    }

    func refreshBackend(_ type: LLMBackendType) async {
        backends[type]?.status = .checking

        let status: BackendStatus
        switch type {
        case .ollama: status = await checkOllama()
        case .tinyLLM: status = await checkTinyLLM()
        case .tinyChat: status = await checkTinyChat()
        case .openWebUI: status = await checkOpenWebUI()
        case .mlx: status = await checkMLX()
        case .auto: status = .disconnected
        }
        backends[type]?.status = status
        determineActiveBackend()
    }

    // MARK: - Backend Selection

    func setActiveBackend(_ type: LLMBackendType) {
        activeLLMBackendType = type
        AppSettings.shared.activeLLMBackendType = type.rawValue
        determineActiveBackend()
    }

    private func determineActiveBackend() {
        switch activeLLMBackendType {
        case .ollama:
            resolvedBackend = backends[.ollama]?.status.isConnected == true ? .ollama : nil
        case .mlx:
            resolvedBackend = backends[.mlx]?.status.isConnected == true ? .mlx : nil
        case .tinyLLM:
            resolvedBackend = backends[.tinyLLM]?.status.isConnected == true ? .tinyLLM : nil
        case .tinyChat:
            resolvedBackend = backends[.tinyChat]?.status.isConnected == true ? .tinyChat : nil
        case .openWebUI:
            resolvedBackend = backends[.openWebUI]?.status.isConnected == true ? .openWebUI : nil
        case .auto:
            // Priority: Ollama > TinyChat > TinyLLM > OpenWebUI > MLX
            if backends[.ollama]?.status.isConnected == true {
                resolvedBackend = .ollama
            } else if backends[.tinyChat]?.status.isConnected == true {
                resolvedBackend = .tinyChat
            } else if backends[.tinyLLM]?.status.isConnected == true {
                resolvedBackend = .tinyLLM
            } else if backends[.openWebUI]?.status.isConnected == true {
                resolvedBackend = .openWebUI
            } else if backends[.mlx]?.status.isConnected == true {
                resolvedBackend = .mlx
            } else {
                resolvedBackend = nil
            }
        }
    }

    var isAnyBackendConnected: Bool {
        resolvedBackend != nil
    }

    // MARK: - Health Check Implementations

    private func checkOllama() async -> BackendStatus {
        guard let url = URL(string: "\(backends[.ollama]?.url ?? "http://localhost:11434")/api/tags") else {
            return .disconnected
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .disconnected }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["name"] as? String }
                ollamaModels = modelNames
                if !modelNames.isEmpty && !modelNames.contains(selectedOllamaModel) {
                    selectedOllamaModel = modelNames[0]
                    AppSettings.shared.selectedOllamaModel = modelNames[0]
                }
            }
            return .connected
        } catch {
            return .disconnected
        }
    }

    private func checkTinyLLM() async -> BackendStatus {
        guard let url = URL(string: "\(backends[.tinyLLM]?.url ?? "http://localhost:8000")/v1/models") else {
            return .disconnected
        }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200 ? .connected : .disconnected
        } catch {
            return .disconnected
        }
    }

    private func checkTinyChat() async -> BackendStatus {
        guard let url = URL(string: "\(backends[.tinyChat]?.url ?? "http://localhost:8000")/") else {
            return .disconnected
        }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200 ? .connected : .disconnected
        } catch {
            return .disconnected
        }
    }

    private func checkOpenWebUI() async -> BackendStatus {
        let baseURL = backends[.openWebUI]?.url ?? "http://localhost:8080"
        let urls = [
            URL(string: "\(baseURL)/"),
            URL(string: "http://localhost:3000/")
        ].compactMap { $0 }

        for url in urls {
            do {
                let (_, response) = try await session.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    if url.absoluteString.contains(":3000") {
                        backends[.openWebUI]?.url = "http://localhost:3000"
                    }
                    return .connected
                }
            } catch {
                continue
            }
        }
        return .disconnected
    }

    private func checkMLX() async -> BackendStatus {
        let pythonPath = AppSettings.shared.pythonPath
        guard FileManager.default.fileExists(atPath: pythonPath) else { return .disconnected }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-c", "import mlx.core as mx; print('OK')"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? .connected : .disconnected)
            } catch {
                continuation.resume(returning: .disconnected)
            }
        }
    }

    // MARK: - Text Generation (Non-Streaming)

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        messages: [ChatMessage] = [],
        temperature: Float = 0.7,
        maxTokens: Int = 2048
    ) async throws -> String {
        guard let backend = resolvedBackend else {
            throw LLMError.noBackendAvailable
        }

        switch backend {
        case .ollama:
            return try await generateWithOllama(prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .tinyLLM:
            return try await generateWithOpenAICompatible(baseURL: backends[.tinyLLM]?.url ?? "http://localhost:8000", prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .tinyChat:
            return try await generateWithTinyChat(prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature)
        case .openWebUI:
            return try await generateWithOpenAICompatible(baseURL: backends[.openWebUI]?.url ?? "http://localhost:8080", prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .mlx:
            return try await generateWithMLX(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        case .auto:
            throw LLMError.noBackendAvailable
        }
    }

    // MARK: - Streaming Generation

    func generateStream(
        prompt: String,
        systemPrompt: String? = nil,
        messages: [ChatMessage] = [],
        temperature: Float = 0.7,
        maxTokens: Int = 2048
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let backend = resolvedBackend else {
                    continuation.finish(throwing: LLMError.noBackendAvailable)
                    return
                }

                do {
                    switch backend {
                    case .ollama:
                        try await streamOllama(prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens, continuation: continuation)
                    case .tinyLLM:
                        let tinyLLMURL = self.backends[.tinyLLM]?.url ?? "http://localhost:8000"
                        try await self.streamOpenAICompatible(baseURL: tinyLLMURL, prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens, continuation: continuation)
                    case .openWebUI:
                        let openWebUIURL = self.backends[.openWebUI]?.url ?? "http://localhost:8080"
                        try await self.streamOpenAICompatible(baseURL: openWebUIURL, prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens, continuation: continuation)
                    default:
                        // Non-streaming fallback for TinyChat and MLX
                        let result = try await generate(prompt: prompt, systemPrompt: systemPrompt, messages: messages, temperature: temperature, maxTokens: maxTokens)
                        continuation.yield(result)
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Ollama Implementation

    private func generateWithOllama(
        prompt: String,
        systemPrompt: String?,
        messages: [ChatMessage],
        temperature: Float,
        maxTokens: Int
    ) async throws -> String {
        let baseURL = backends[.ollama]?.url ?? "http://localhost:11434"
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw LLMError.invalidURL
        }

        let apiMessages = buildOllamaMessages(prompt: prompt, systemPrompt: systemPrompt, messages: messages)
        let body: [String: Any] = [
            "model": selectedOllamaModel,
            "messages": apiMessages,
            "stream": false,
            "options": [
                "temperature": temperature,
                "num_predict": maxTokens
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.noResponse
        }

        return content
    }

    private func streamOllama(
        prompt: String,
        systemPrompt: String?,
        messages: [ChatMessage],
        temperature: Float,
        maxTokens: Int,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let baseURL = backends[.ollama]?.url ?? "http://localhost:11434"
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw LLMError.invalidURL
        }

        let apiMessages = buildOllamaMessages(prompt: prompt, systemPrompt: systemPrompt, messages: messages)
        let body: [String: Any] = [
            "model": selectedOllamaModel,
            "messages": apiMessages,
            "stream": true,
            "options": [
                "temperature": temperature,
                "num_predict": maxTokens
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        for try await line in bytes.lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                continue
            }

            continuation.yield(content)

            if let done = json["done"] as? Bool, done {
                break
            }
        }

        continuation.finish()
    }

    // MARK: - OpenAI-Compatible Streaming (TinyLLM, OpenWebUI)

    private func streamOpenAICompatible(
        baseURL: String,
        prompt: String,
        systemPrompt: String?,
        messages: [ChatMessage],
        temperature: Float,
        maxTokens: Int,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        var apiMessages: [[String: String]] = []
        if let system = systemPrompt, !system.isEmpty {
            apiMessages.append(["role": "system", "content": system])
        }
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        if messages.last?.role != .user || messages.last?.content != prompt {
            apiMessages.append(["role": "user", "content": prompt])
        }

        let body: [String: Any] = [
            "model": selectedOllamaModel,
            "messages": apiMessages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // SSE format: "data: {json}\n\n" with "data: [DONE]" at end
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))

            if payload == "[DONE]" { break }

            guard let lineData = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            continuation.yield(content)
        }

        continuation.finish()
    }

    private func buildOllamaMessages(prompt: String, systemPrompt: String?, messages: [ChatMessage]) -> [[String: String]] {
        var apiMessages: [[String: String]] = []

        if let system = systemPrompt, !system.isEmpty {
            apiMessages.append(["role": "system", "content": system])
        }

        // Include conversation history (excluding system messages already added)
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Add the new user prompt if not already in messages
        if messages.last?.role != .user || messages.last?.content != prompt {
            apiMessages.append(["role": "user", "content": prompt])
        }

        return apiMessages
    }

    // MARK: - OpenAI-Compatible Implementation (TinyLLM, OpenWebUI)

    private func generateWithOpenAICompatible(
        baseURL: String,
        prompt: String,
        systemPrompt: String?,
        messages: [ChatMessage],
        temperature: Float,
        maxTokens: Int
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        var apiMessages: [[String: String]] = []
        if let system = systemPrompt, !system.isEmpty {
            apiMessages.append(["role": "system", "content": system])
        }
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        if messages.last?.role != .user || messages.last?.content != prompt {
            apiMessages.append(["role": "user", "content": prompt])
        }

        let body: [String: Any] = [
            "model": selectedOllamaModel,
            "messages": apiMessages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return apiResponse.choices.first?.message.content ?? ""
    }

    // MARK: - TinyChat Implementation

    private func generateWithTinyChat(
        prompt: String,
        systemPrompt: String?,
        messages: [ChatMessage],
        temperature: Float
    ) async throws -> String {
        let baseURL = backends[.tinyChat]?.url ?? "http://localhost:8000"
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw LLMError.invalidURL
        }

        let body: [String: Any] = [
            "message": prompt,
            "model": selectedOllamaModel,
            "temperature": temperature
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // TinyChat returns streaming JSON lines — take last complete response
        if let responseText = String(data: data, encoding: .utf8) {
            let lines = responseText.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines.reversed() {
                if let lineData = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let content = json["content"] as? String {
                    return content
                }
            }
        }

        throw LLMError.noResponse
    }

    // MARK: - MLX Implementation

    private func generateWithMLX(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        let pythonPath = AppSettings.shared.pythonPath
        let mlxPath = "/opt/homebrew/bin/mlx_lm.generate"

        guard FileManager.default.fileExists(atPath: mlxPath) || FileManager.default.fileExists(atPath: pythonPath) else {
            throw LLMError.mlxNotAvailable
        }

        var fullPrompt = prompt
        if let system = systemPrompt, !system.isEmpty {
            fullPrompt = "\(system)\n\n\(prompt)"
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            if FileManager.default.fileExists(atPath: mlxPath) {
                process.executableURL = URL(fileURLWithPath: mlxPath)
                process.arguments = ["--model", "mlx-community/Llama-3.2-3B-Instruct-4bit", "--prompt", fullPrompt, "--max-tokens", "\(maxTokens)"]
            } else {
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = ["-c", """
                    from mlx_lm import load, generate
                    model, tokenizer = load("mlx-community/Llama-3.2-3B-Instruct-4bit")
                    response = generate(model, tokenizer, prompt='''\(fullPrompt.replacingOccurrences(of: "'", with: "\\'"))''', max_tokens=\(maxTokens))
                    print(response)
                    """]
            }

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: LLMError.mlxNotAvailable)
                    return
                }

                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                    continuation.resume(throwing: LLMError.noResponse)
                    return
                }
                continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                continuation.resume(throwing: LLMError.mlxNotAvailable)
            }
        }
    }
}

// MARK: - LLM Errors

enum LLMError: LocalizedError, Sendable {
    case noBackendAvailable
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResponse
    case mlxNotAvailable

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "No LLM backend is available. Please start Ollama, TinyLLM, TinyChat, or OpenWebUI."
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .invalidResponse:
            return "Received invalid response from LLM backend."
        case .httpError(let code):
            return "HTTP error \(code) from LLM backend."
        case .noResponse:
            return "No response received from LLM backend."
        case .mlxNotAvailable:
            return "MLX not available. Install: pip install mlx-lm"
        }
    }
}
