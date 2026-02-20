//
//  AppSettings.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let a1111URL = "a1111URL"
        static let comfyUIURL = "comfyUIURL"
        static let swarmUIURL = "swarmUIURL"
        static let outputDirectory = "outputDirectory"
        static let pythonPath = "pythonPath"
        static let activeBackendType = "activeBackendType"
        static let defaultSteps = "defaultSteps"
        static let defaultCFGScale = "defaultCFGScale"
        static let defaultWidth = "defaultWidth"
        static let defaultHeight = "defaultHeight"
        static let defaultSampler = "defaultSampler"
        static let autoSaveImages = "autoSaveImages"
        static let showNegativePrompt = "showNegativePrompt"
        // LLM Backend Settings
        static let ollamaURL = "ollamaURL"
        static let tinyLLMURL = "tinyLLMURL"
        static let tinyChatURL = "tinyChatURL"
        static let openWebUIURL = "openWebUIURL"
        static let activeLLMBackendType = "activeLLMBackendType"
        static let selectedOllamaModel = "selectedOllamaModel"
        static let chatTemperature = "chatTemperature"
        static let chatMaxTokens = "chatMaxTokens"
        static let defaultSystemPrompt = "defaultSystemPrompt"
    }

    // MARK: - Backend URLs

    @Published var a1111URL: String {
        didSet { UserDefaults.standard.set(a1111URL, forKey: Keys.a1111URL) }
    }

    @Published var comfyUIURL: String {
        didSet { UserDefaults.standard.set(comfyUIURL, forKey: Keys.comfyUIURL) }
    }

    @Published var swarmUIURL: String {
        didSet { UserDefaults.standard.set(swarmUIURL, forKey: Keys.swarmUIURL) }
    }

    // MARK: - Paths

    @Published var outputDirectory: String {
        didSet { UserDefaults.standard.set(outputDirectory, forKey: Keys.outputDirectory) }
    }

    @Published var pythonPath: String {
        didSet { UserDefaults.standard.set(pythonPath, forKey: Keys.pythonPath) }
    }

    // MARK: - Active Backend

    @Published var activeBackendType: String {
        didSet { UserDefaults.standard.set(activeBackendType, forKey: Keys.activeBackendType) }
    }

    // MARK: - Default Generation Parameters

    @Published var defaultSteps: Int {
        didSet { UserDefaults.standard.set(defaultSteps, forKey: Keys.defaultSteps) }
    }

    @Published var defaultCFGScale: Double {
        didSet { UserDefaults.standard.set(defaultCFGScale, forKey: Keys.defaultCFGScale) }
    }

    @Published var defaultWidth: Int {
        didSet { UserDefaults.standard.set(defaultWidth, forKey: Keys.defaultWidth) }
    }

    @Published var defaultHeight: Int {
        didSet { UserDefaults.standard.set(defaultHeight, forKey: Keys.defaultHeight) }
    }

    @Published var defaultSampler: String {
        didSet { UserDefaults.standard.set(defaultSampler, forKey: Keys.defaultSampler) }
    }

    // MARK: - UI Preferences

    @Published var autoSaveImages: Bool {
        didSet { UserDefaults.standard.set(autoSaveImages, forKey: Keys.autoSaveImages) }
    }

    @Published var showNegativePrompt: Bool {
        didSet { UserDefaults.standard.set(showNegativePrompt, forKey: Keys.showNegativePrompt) }
    }

    // MARK: - LLM Backend URLs

    @Published var ollamaURL: String {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: Keys.ollamaURL) }
    }

    @Published var tinyLLMURL: String {
        didSet { UserDefaults.standard.set(tinyLLMURL, forKey: Keys.tinyLLMURL) }
    }

    @Published var tinyChatURL: String {
        didSet { UserDefaults.standard.set(tinyChatURL, forKey: Keys.tinyChatURL) }
    }

    @Published var openWebUIURL: String {
        didSet { UserDefaults.standard.set(openWebUIURL, forKey: Keys.openWebUIURL) }
    }

    @Published var activeLLMBackendType: String {
        didSet { UserDefaults.standard.set(activeLLMBackendType, forKey: Keys.activeLLMBackendType) }
    }

    @Published var selectedOllamaModel: String {
        didSet { UserDefaults.standard.set(selectedOllamaModel, forKey: Keys.selectedOllamaModel) }
    }

    @Published var chatTemperature: Float {
        didSet { UserDefaults.standard.set(chatTemperature, forKey: Keys.chatTemperature) }
    }

    @Published var chatMaxTokens: Int {
        didSet { UserDefaults.standard.set(chatMaxTokens, forKey: Keys.chatMaxTokens) }
    }

    @Published var defaultSystemPrompt: String {
        didSet { UserDefaults.standard.set(defaultSystemPrompt, forKey: Keys.defaultSystemPrompt) }
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        self.a1111URL = defaults.string(forKey: Keys.a1111URL) ?? "http://localhost:7860"
        self.comfyUIURL = defaults.string(forKey: Keys.comfyUIURL) ?? "http://localhost:8188"
        self.swarmUIURL = defaults.string(forKey: Keys.swarmUIURL) ?? "http://localhost:7801"

        let defaultOutput = NSHomeDirectory() + "/Documents/AIStudio/output"
        self.outputDirectory = defaults.string(forKey: Keys.outputDirectory) ?? defaultOutput
        self.pythonPath = defaults.string(forKey: Keys.pythonPath) ?? "/usr/bin/python3"

        self.activeBackendType = defaults.string(forKey: Keys.activeBackendType) ?? "automatic1111"

        self.defaultSteps = defaults.object(forKey: Keys.defaultSteps) as? Int ?? 20
        self.defaultCFGScale = defaults.object(forKey: Keys.defaultCFGScale) as? Double ?? 7.0
        self.defaultWidth = defaults.object(forKey: Keys.defaultWidth) as? Int ?? 512
        self.defaultHeight = defaults.object(forKey: Keys.defaultHeight) as? Int ?? 512
        self.defaultSampler = defaults.string(forKey: Keys.defaultSampler) ?? "Euler a"

        self.autoSaveImages = defaults.object(forKey: Keys.autoSaveImages) as? Bool ?? true
        self.showNegativePrompt = defaults.object(forKey: Keys.showNegativePrompt) as? Bool ?? true

        // LLM Backend Settings
        self.ollamaURL = defaults.string(forKey: Keys.ollamaURL) ?? "http://localhost:11434"
        self.tinyLLMURL = defaults.string(forKey: Keys.tinyLLMURL) ?? "http://localhost:8000"
        self.tinyChatURL = defaults.string(forKey: Keys.tinyChatURL) ?? "http://localhost:8000"
        self.openWebUIURL = defaults.string(forKey: Keys.openWebUIURL) ?? "http://localhost:8080"
        self.activeLLMBackendType = defaults.string(forKey: Keys.activeLLMBackendType) ?? "auto"
        self.selectedOllamaModel = defaults.string(forKey: Keys.selectedOllamaModel) ?? "mistral:latest"
        self.chatTemperature = defaults.object(forKey: Keys.chatTemperature) as? Float ?? 0.7
        self.chatMaxTokens = defaults.object(forKey: Keys.chatMaxTokens) as? Int ?? 2048
        self.defaultSystemPrompt = defaults.string(forKey: Keys.defaultSystemPrompt) ?? "You are a helpful creative assistant specializing in art, image generation, and creative writing. Help users craft better prompts, describe images, and explore creative ideas."

        // Ensure output directory exists
        try? FileManager.default.createDirectory(
            atPath: outputDirectory,
            withIntermediateDirectories: true
        )
    }

    func resetToDefaults() {
        a1111URL = "http://localhost:7860"
        comfyUIURL = "http://localhost:8188"
        swarmUIURL = "http://localhost:7801"
        outputDirectory = NSHomeDirectory() + "/Documents/AIStudio/output"
        pythonPath = "/usr/bin/python3"
        activeBackendType = "automatic1111"
        defaultSteps = 20
        defaultCFGScale = 7.0
        defaultWidth = 512
        defaultHeight = 512
        defaultSampler = "Euler a"
        autoSaveImages = true
        showNegativePrompt = true
        // LLM defaults
        ollamaURL = "http://localhost:11434"
        tinyLLMURL = "http://localhost:8000"
        tinyChatURL = "http://localhost:8000"
        openWebUIURL = "http://localhost:8080"
        activeLLMBackendType = "auto"
        selectedOllamaModel = "mistral:latest"
        chatTemperature = 0.7
        chatMaxTokens = 2048
        defaultSystemPrompt = "You are a helpful creative assistant specializing in art, image generation, and creative writing. Help users craft better prompts, describe images, and explore creative ideas."
    }
}
