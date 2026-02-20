//
//  BackendSettingsView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct BackendSettingsView: View {
    @EnvironmentObject var backendManager: BackendManager
    @EnvironmentObject var settings: AppSettings

    @State private var testingBackend: BackendType?

    var body: some View {
        Form {
            Section("Automatic1111") {
                backendRow(
                    type: .automatic1111,
                    url: $settings.a1111URL,
                    defaultURL: "http://localhost:7860"
                )
            }

            Section("ComfyUI") {
                backendRow(
                    type: .comfyUI,
                    url: $settings.comfyUIURL,
                    defaultURL: "http://localhost:8188"
                )
            }

            Section("SwarmUI") {
                backendRow(
                    type: .swarmUI,
                    url: $settings.swarmUIURL,
                    defaultURL: "http://localhost:7801"
                )
            }

            Section("MLX Native") {
                HStack {
                    Image(systemName: BackendType.mlxNative.icon)
                        .foregroundColor(.secondary)
                    Text("Runs locally via Python daemon")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Phase 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func backendRow(type: BackendType, url: Binding<String>, defaultURL: String) -> some View {
        HStack {
            TextField("URL", text: url)
                .textFieldStyle(.roundedBorder)

            // Connection status dot
            if let config = backendManager.backends[type] {
                Circle()
                    .fill(colorForStatus(config.status))
                    .frame(width: 8, height: 8)
            }

            Button("Test") {
                testConnection(type)
            }
            .disabled(testingBackend == type)
        }

        if let config = backendManager.backends[type] {
            Text(config.status.displayText)
                .font(.caption)
                .foregroundColor(config.status.isConnected ? .green : .secondary)
        }
    }

    private func testConnection(_ type: BackendType) {
        testingBackend = type
        Task {
            await backendManager.refreshBackend(type)
            testingBackend = nil
        }
    }

    private func colorForStatus(_ status: BackendStatus) -> Color {
        switch status {
        case .connected: return .green
        case .disconnected: return .gray
        case .checking: return .yellow
        case .error: return .red
        }
    }
}
