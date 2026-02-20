//
//  BackendSelectorView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Dropdown for selecting the active image generation backend + connection status indicator.
struct BackendSelectorView: View {
    @EnvironmentObject var backendManager: BackendManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Backend")
                    .font(.headline)

                Spacer()

                Button(action: {
                    Task { await backendManager.refreshAllBackends() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(backendManager.isRefreshing)
                .help("Refresh connection status")
            }

            Picker("Backend", selection: Binding(
                get: { backendManager.activeBackendType },
                set: { backendManager.setActiveBackend($0) }
            )) {
                ForEach(BackendType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if let config = backendManager.activeBackendConfig {
                    Text(config.status.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if config.status.isConnected {
                        Text("- \(config.url)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        guard let config = backendManager.activeBackendConfig else { return .gray }
        switch config.status {
        case .connected: return .green
        case .disconnected: return .gray
        case .checking: return .yellow
        case .error: return .red
        }
    }
}
