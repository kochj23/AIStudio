//
//  ProgressOverlayView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Overlay view showing generation progress.
struct ProgressOverlayView: View {
    let progress: Double
    let message: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if progress > 0 && progress < 1 {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }

            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)

            Button("Cancel") {
                onCancel()
            }
            .controlSize(.small)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
