//
//  AppSettings.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Errors thrown when setting invalid URL values
enum AppSettingsError: LocalizedError {
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: '\(value)'. Must be a valid http:// or https:// URL with a valid host."
        }
    }
}

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let settingsKey = "AppSettingsJSON"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties (auto-saved via Combine debounce)

    @Published var a1111URL: String
    @Published var comfyUIURL: String
    @Published var swarmUIURL: String
    @Published var outputDirectory: String
    @Published var pythonPath: String
    @Published var activeBackendType: String
    @Published var defaultSteps: Int
    @Published var defaultCFGScale: Double
    @Published var defaultWidth: Int
    @Published var defaultHeight: Int
    @Published var defaultSampler: String
    @Published var autoSaveImages: Bool
    @Published var showNegativePrompt: Bool
    @Published var ollamaURL: String
    @Published var tinyLLMURL: String
    @Published var tinyChatURL: String
    @Published var openWebUIURL: String
    @Published var activeLLMBackendType: String
    @Published var selectedOllamaModel: String
    @Published var chatTemperature: Float
    @Published var chatMaxTokens: Int
    @Published var defaultSystemPrompt: String

    // MARK: - URL Validation

    /// Validate that a string is a well-formed http/https URL with a valid host.
    /// Returns true if valid, false otherwise.
    static func isValidBackendURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }

    /// Set a backend URL after validation. Throws if the URL is malformed.
    func setBackendURL(_ value: String, for keyPath: ReferenceWritableKeyPath<AppSettings, String>) throws {
        guard AppSettings.isValidBackendURL(value) else {
            throw AppSettingsError.invalidURL(value)
        }
        self[keyPath: keyPath] = value
        save()
    }

    // MARK: - Persistence (single JSON write)

    /// Codable snapshot of all settings for single-write persistence
    private struct SettingsSnapshot: Codable {
        var a1111URL: String
        var comfyUIURL: String
        var swarmUIURL: String
        var outputDirectory: String
        var pythonPath: String
        var activeBackendType: String
        var defaultSteps: Int
        var defaultCFGScale: Double
        var defaultWidth: Int
        var defaultHeight: Int
        var defaultSampler: String
        var autoSaveImages: Bool
        var showNegativePrompt: Bool
        var ollamaURL: String
        var tinyLLMURL: String
        var tinyChatURL: String
        var openWebUIURL: String
        var activeLLMBackendType: String
        var selectedOllamaModel: String
        var chatTemperature: Float
        var chatMaxTokens: Int
        var defaultSystemPrompt: String
    }

    /// Persist all settings as a single JSON blob to UserDefaults.
    func save() {
        let snapshot = SettingsSnapshot(
            a1111URL: a1111URL,
            comfyUIURL: comfyUIURL,
            swarmUIURL: swarmUIURL,
            outputDirectory: outputDirectory,
            pythonPath: pythonPath,
            activeBackendType: activeBackendType,
            defaultSteps: defaultSteps,
            defaultCFGScale: defaultCFGScale,
            defaultWidth: defaultWidth,
            defaultHeight: defaultHeight,
            defaultSampler: defaultSampler,
            autoSaveImages: autoSaveImages,
            showNegativePrompt: showNegativePrompt,
            ollamaURL: ollamaURL,
            tinyLLMURL: tinyLLMURL,
            tinyChatURL: tinyChatURL,
            openWebUIURL: openWebUIURL,
            activeLLMBackendType: activeLLMBackendType,
            selectedOllamaModel: selectedOllamaModel,
            chatTemperature: chatTemperature,
            chatMaxTokens: chatMaxTokens,
            defaultSystemPrompt: defaultSystemPrompt
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: AppSettings.settingsKey)
        }
    }

    // MARK: - Initialization

    private init() {
        // Try loading from single JSON blob first
        if let data = UserDefaults.standard.data(forKey: AppSettings.settingsKey),
           let snapshot = try? JSONDecoder().decode(SettingsSnapshot.self, from: data) {
            self.a1111URL = snapshot.a1111URL
            self.comfyUIURL = snapshot.comfyUIURL
            self.swarmUIURL = snapshot.swarmUIURL
            self.outputDirectory = snapshot.outputDirectory
            self.pythonPath = snapshot.pythonPath
            self.activeBackendType = snapshot.activeBackendType
            self.defaultSteps = snapshot.defaultSteps
            self.defaultCFGScale = snapshot.defaultCFGScale
            self.defaultWidth = snapshot.defaultWidth
            self.defaultHeight = snapshot.defaultHeight
            self.defaultSampler = snapshot.defaultSampler
            self.autoSaveImages = snapshot.autoSaveImages
            self.showNegativePrompt = snapshot.showNegativePrompt
            self.ollamaURL = snapshot.ollamaURL
            self.tinyLLMURL = snapshot.tinyLLMURL
            self.tinyChatURL = snapshot.tinyChatURL
            self.openWebUIURL = snapshot.openWebUIURL
            self.activeLLMBackendType = snapshot.activeLLMBackendType
            self.selectedOllamaModel = snapshot.selectedOllamaModel
            self.chatTemperature = snapshot.chatTemperature
            self.chatMaxTokens = snapshot.chatMaxTokens
            self.defaultSystemPrompt = snapshot.defaultSystemPrompt
        } else {
            // Fall back to legacy per-key defaults for migration
            let defaults = UserDefaults.standard
            let defaultOutput = NSHomeDirectory() + "/Documents/AIStudio/output"

            self.a1111URL = defaults.string(forKey: "a1111URL") ?? "http://localhost:7860"
            self.comfyUIURL = defaults.string(forKey: "comfyUIURL") ?? "http://localhost:8188"
            self.swarmUIURL = defaults.string(forKey: "swarmUIURL") ?? "http://localhost:7801"
            self.outputDirectory = defaults.string(forKey: "outputDirectory") ?? defaultOutput
            self.pythonPath = defaults.string(forKey: "pythonPath") ?? "/Volumes/Data/xcode/AIStudio/venv/bin/python3"
            self.activeBackendType = defaults.string(forKey: "activeBackendType") ?? "automatic1111"
            self.defaultSteps = defaults.object(forKey: "defaultSteps") as? Int ?? 20
            self.defaultCFGScale = defaults.object(forKey: "defaultCFGScale") as? Double ?? 7.0
            self.defaultWidth = defaults.object(forKey: "defaultWidth") as? Int ?? 512
            self.defaultHeight = defaults.object(forKey: "defaultHeight") as? Int ?? 512
            self.defaultSampler = defaults.string(forKey: "defaultSampler") ?? "Euler a"
            self.autoSaveImages = defaults.object(forKey: "autoSaveImages") as? Bool ?? true
            self.showNegativePrompt = defaults.object(forKey: "showNegativePrompt") as? Bool ?? true
            self.ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
            self.tinyLLMURL = defaults.string(forKey: "tinyLLMURL") ?? "http://localhost:8000"
            self.tinyChatURL = defaults.string(forKey: "tinyChatURL") ?? "http://localhost:8000"
            self.openWebUIURL = defaults.string(forKey: "openWebUIURL") ?? "http://localhost:8080"
            self.activeLLMBackendType = defaults.string(forKey: "activeLLMBackendType") ?? "auto"
            self.selectedOllamaModel = defaults.string(forKey: "selectedOllamaModel") ?? "mistral:latest"
            self.chatTemperature = defaults.object(forKey: "chatTemperature") as? Float ?? 0.7
            self.chatMaxTokens = defaults.object(forKey: "chatMaxTokens") as? Int ?? 2048
            self.defaultSystemPrompt = defaults.string(forKey: "defaultSystemPrompt") ?? "You are a helpful creative assistant specializing in art, image generation, and creative writing. Help users craft better prompts, describe images, and explore creative ideas."

            // Migrate legacy keys to single JSON blob
            save()
        }

        // Ensure output directory exists
        try? FileManager.default.createDirectory(
            atPath: outputDirectory,
            withIntermediateDirectories: true
        )

        // Auto-save whenever any @Published property changes (debounced to batch rapid edits)
        objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    func resetToDefaults() {
        a1111URL = "http://localhost:7860"
        comfyUIURL = "http://localhost:8188"
        swarmUIURL = "http://localhost:7801"
        outputDirectory = NSHomeDirectory() + "/Documents/AIStudio/output"
        pythonPath = "/Volumes/Data/xcode/AIStudio/venv/bin/python3"
        activeBackendType = "automatic1111"
        defaultSteps = 20
        defaultCFGScale = 7.0
        defaultWidth = 512
        defaultHeight = 512
        defaultSampler = "Euler a"
        autoSaveImages = true
        showNegativePrompt = true
        ollamaURL = "http://localhost:11434"
        tinyLLMURL = "http://localhost:8000"
        tinyChatURL = "http://localhost:8000"
        openWebUIURL = "http://localhost:8080"
        activeLLMBackendType = "auto"
        selectedOllamaModel = "mistral:latest"
        chatTemperature = 0.7
        chatMaxTokens = 2048
        defaultSystemPrompt = "You are a helpful creative assistant specializing in art, image generation, and creative writing. Help users craft better prompts, describe images, and explore creative ideas."
        save()
    }
}
