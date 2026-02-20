//
//  LLMBackendStatusMenu.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// LLM backend selector with status indicator and model picker.
struct LLMBackendStatusMenu: View {
    @EnvironmentObject var llmManager: LLMBackendManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LLM Backend")
                    .font(.headline)
                Spacer()

                Button(action: {
                    Task { await llmManager.refreshAllBackends() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .rotationEffect(.degrees(llmManager.isRefreshing ? 360 : 0))
                        .animation(llmManager.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: llmManager.isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(llmManager.isRefreshing)
                .help("Refresh backend status")
            }

            // Backend Picker
            Picker("Backend", selection: Binding(
                get: { llmManager.activeLLMBackendType },
                set: { llmManager.setActiveBackend($0) }
            )) {
                ForEach(LLMBackendType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            // Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if let resolved = llmManager.resolvedBackend {
                    Text(resolved.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("No backend available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // All backends status
            VStack(alignment: .leading, spacing: 4) {
                ForEach(LLMBackendType.allCases.filter { $0 != .auto }, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(backendStatusColor(type))
                            .frame(width: 6, height: 6)
                        Image(systemName: type.icon)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(type.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(llmManager.backends[type]?.status.displayText ?? "Unknown")
                            .font(.system(size: 10))
                            .foregroundColor(backendStatusColor(type))
                    }
                }
            }
            .padding(.top, 2)

            // Ollama Model Picker
            if llmManager.resolvedBackend == .ollama && !llmManager.ollamaModels.isEmpty {
                Divider()
                Picker("Model", selection: $llmManager.selectedOllamaModel) {
                    ForEach(llmManager.ollamaModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: llmManager.selectedOllamaModel) { newValue in
                    AppSettings.shared.selectedOllamaModel = newValue
                }
            }
        }
    }

    private var statusColor: Color {
        if llmManager.resolvedBackend != nil {
            return .green
        } else if llmManager.backends.values.contains(where: { $0.status.isConnected }) {
            return .yellow
        } else {
            return .red
        }
    }

    private func backendStatusColor(_ type: LLMBackendType) -> Color {
        switch llmManager.backends[type]?.status {
        case .connected: return .green
        case .checking: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        case .none: return .gray
        }
    }
}
