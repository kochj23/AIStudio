//
//  StatusBarView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Status bar showing connection status dots for all backends.
struct StatusBarView: View {
    @EnvironmentObject var backendManager: BackendManager

    var body: some View {
        HStack(spacing: 12) {
            ForEach(BackendType.allCases, id: \.self) { type in
                if let config = backendManager.backends[type] {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForStatus(config.status))
                            .frame(width: 6, height: 6)
                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
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
