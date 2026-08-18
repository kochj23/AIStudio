//
//  LLMSettingsView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Settings tab for LLM backend configuration.
///
/// Top section is written for an average user: pick "Local AI" (free & private,
/// auto-detected) or "Frontier models" (paste an OpenRouter key). Raw base-URL
/// fields live under the collapsible "Advanced" disclosure.
struct LLMSettingsView: View {
    @EnvironmentObject var llmManager: LLMBackendManager
    @EnvironmentObject var settings: AppSettings
    @State private var testingBackend: LLMBackendType?
    @State private var openRouterKeyDraft: String = ""
    @State private var keySaved: Bool = false

    var body: some View {
        Form {
            // MARK: Simple, average-user chooser

            Section("Choose your AI") {
                Picker("Mode", selection: modeBinding) {
                    Text("Automatic — pick the best available").tag(LLMBackendType.auto)
                    Text("Local AI — free & private").tag(LLMBackendType.ollama)
                    Text("Frontier models — OpenRouter").tag(LLMBackendType.openRouter)
                }
                .pickerStyle(.radioGroup)

                Text("Automatic tries your local AI first, then falls back to frontier models. Nothing leaves your Mac unless a local model is unavailable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: Local AI card

            Section("Local AI — free & private") {
                HStack {
                    statusDot(for: .ollama)
                    Text("Ollama")
                    Spacer()
                    Text(llmManager.backends[.ollama]?.status.isConnected == true ? "Detected" : "Not running")
                        .font(.caption)
                        .foregroundColor(llmManager.backends[.ollama]?.status.isConnected == true ? .green : .orange)
                }
                HStack {
                    statusDot(for: .mlx)
                    Text("MLX (Apple Silicon)")
                    Spacer()
                    Text(llmManager.backends[.mlx]?.status.isConnected == true ? "Detected" : "Not available")
                        .font(.caption)
                        .foregroundColor(llmManager.backends[.mlx]?.status.isConnected == true ? .green : .secondary)
                }

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

                Button("Re-check local AI") {
                    Task { await llmManager.refreshAllBackends() }
                }
            }

            // MARK: Frontier models (OpenRouter)

            Section("Frontier models — paste your OpenRouter key") {
                HStack {
                    statusDot(for: .openRouter)
                    SecureField("sk-or-...", text: $openRouterKeyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(keySaved ? "Saved" : "Save") {
                        llmManager.setOpenRouterAPIKey(openRouterKeyDraft)
                        keySaved = true
                        Task {
                            await llmManager.fetchOpenRouterModels()
                            await llmManager.refreshBackend(.openRouter)
                        }
                    }
                    .disabled(openRouterKeyDraft.isEmpty)
                }

                Text("Your key is stored securely in the macOS Keychain — never in plain settings. Get one at openrouter.ai/keys.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if llmManager.hasOpenRouterKey {
                    Picker("Model", selection: $llmManager.selectedOpenRouterModel) {
                        ForEach(llmManager.openRouterModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: llmManager.selectedOpenRouterModel) { newValue in
                        settings.selectedOpenRouterModel = newValue
                    }

                    Button("Remove key") {
                        llmManager.setOpenRouterAPIKey("")
                        openRouterKeyDraft = ""
                        keySaved = false
                        Task { await llmManager.refreshBackend(.openRouter) }
                    }
                    .foregroundColor(.red)
                }
            }

            // MARK: Chat defaults

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

            // MARK: Advanced (raw base-URL fields)

            Section("Advanced") {
                DisclosureGroup("Backend URLs & other servers") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledURL("Ollama", url: $settings.ollamaURL, type: .ollama)
                        labeledURL("OpenRouter base URL", url: $settings.openRouterURL, type: .openRouter)
                        labeledURL("TinyLLM", url: $settings.tinyLLMURL, type: .tinyLLM)
                        labeledURL("TinyChat", url: $settings.tinyChatURL, type: .tinyChat)
                        labeledURL("OpenWebUI", url: $settings.openWebUIURL, type: .openWebUI)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .onAppear {
            openRouterKeyDraft = llmManager.openRouterAPIKey() ?? ""
        }
    }

    // MARK: - Reusable Components

    /// Binding that maps the picker onto the manager's active backend selection.
    private var modeBinding: Binding<LLMBackendType> {
        Binding(
            get: { llmManager.activeLLMBackendType },
            set: { llmManager.setActiveBackend($0) }
        )
    }

    @ViewBuilder
    private func labeledURL(_ label: String, url: Binding<String>, type: LLMBackendType) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
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
        case .disconnected: return .orange
        case .error: return .red
        case .none: return .gray
        }
    }
}
