//
//  LLMSettingsView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Settings tab for LLM backend configuration.
struct LLMSettingsView: View {
    @EnvironmentObject var llmManager: LLMBackendManager
    @EnvironmentObject var settings: AppSettings
    @State private var testingBackend: LLMBackendType?

    var body: some View {
        Form {
            Section("Ollama") {
                backendRow(type: .ollama, url: $settings.ollamaURL)

                if llmManager.backends[.ollama]?.status.isConnected == true && !llmManager.ollamaModels.isEmpty {
                    Picker("Model", selection: $llmManager.selectedOllamaModel) {
                        ForEach(llmManager.ollamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: llmManager.selectedOllamaModel) { newValue in
                        settings.selectedOllamaModel = newValue
                    }
                }

                if llmManager.ollamaModels.isEmpty && llmManager.backends[.ollama]?.status.isConnected == true {
                    Text("No models found. Run: ollama pull mistral")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("TinyLLM") {
                backendRow(type: .tinyLLM, url: $settings.tinyLLMURL)
                attributionView("TinyLLM by Jason Cox", url: "https://github.com/jasonacox/TinyLLM")
            }

            Section("TinyChat") {
                backendRow(type: .tinyChat, url: $settings.tinyChatURL)
                attributionView("TinyChat by Jason Cox", url: "https://github.com/jasonacox/tinychat")
            }

            Section("OpenWebUI") {
                backendRow(type: .openWebUI, url: $settings.openWebUIURL)
                Text("Ports: 8080 (default) or 3000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("MLX Native") {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                    Text("Uses Python with mlx-lm for local inference")
                    Spacer()
                    statusDot(for: .mlx)
                    Text(llmManager.backends[.mlx]?.status.displayText ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(statusColor(for: .mlx))
                }
            }

            Section("Chat Defaults") {
                HStack {
                    Text("Temperature")
                    Spacer()
                    TextField("", value: $settings.chatTemperature, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Max Tokens")
                    Spacer()
                    TextField("", value: $settings.chatMaxTokens, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default System Prompt")
                    TextEditor(text: $settings.defaultSystemPrompt)
                        .font(.system(size: 11))
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.3), width: 1)
                }
            }

            Section("Setup Instructions") {
                DisclosureGroup("Ollama") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Install: brew install ollama")
                        Text("2. Start: ollama serve")
                        Text("3. Pull model: ollama pull mistral")
                        Text("Default: http://localhost:11434")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                DisclosureGroup("TinyLLM") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("By Jason Cox (github.com/jasonacox/TinyLLM)")
                        Text("1. Clone: git clone https://github.com/jasonacox/TinyLLM")
                        Text("2. Run: docker-compose up -d")
                        Text("Default: http://localhost:8000")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                DisclosureGroup("TinyChat") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("By Jason Cox (github.com/jasonacox/tinychat)")
                        Text("1. Docker: docker run -d -p 8000:8000 jasonacox/tinychat:latest")
                        Text("Default: http://localhost:8000")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                DisclosureGroup("OpenWebUI") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Community Project (github.com/open-webui/open-webui)")
                        Text("1. Docker: docker run -d -p 3000:8080 ghcr.io/open-webui/open-webui:main")
                        Text("2. Or: pip install open-webui && open-webui serve")
                        Text("Default: http://localhost:8080 or :3000")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                DisclosureGroup("MLX") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Install Python: brew install python")
                        Text("2. Install MLX: pip install mlx-lm")
                        Text("3. Path: /opt/homebrew/bin/python3")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func backendRow(type: LLMBackendType, url: Binding<String>) -> some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(.secondary)
            TextField("URL", text: url)
                .textFieldStyle(.roundedBorder)
            statusDot(for: type)

            Button("Test") {
                testingBackend = type
                Task {
                    await llmManager.refreshBackend(type)
                    testingBackend = nil
                }
            }
            .disabled(testingBackend == type)
        }
    }

    @ViewBuilder
    private func statusDot(for type: LLMBackendType) -> some View {
        Circle()
            .fill(statusColor(for: type))
            .frame(width: 8, height: 8)
    }

    private func statusColor(for type: LLMBackendType) -> Color {
        switch llmManager.backends[type]?.status {
        case .connected: return .green
        case .checking: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        case .none: return .gray
        }
    }

    @ViewBuilder
    private func attributionView(_ text: String, url: String) -> some View {
        if let linkURL = URL(string: url) {
            Link(text, destination: linkURL)
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
}
