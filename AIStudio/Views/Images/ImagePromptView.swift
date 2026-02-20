//
//  ImagePromptView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ImagePromptView: View {
    @Binding var prompt: String
    @Binding var negativePrompt: String
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt")
                .font(.headline)

            TextEditor(text: $prompt)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 160)
                .border(Color.secondary.opacity(0.3), width: 1)
                .scrollContentBackground(.hidden)

            if settings.showNegativePrompt {
                HStack {
                    Text("Negative Prompt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { settings.showNegativePrompt = false }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $negativePrompt)
                    .font(.body)
                    .frame(minHeight: 50, maxHeight: 100)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .scrollContentBackground(.hidden)
            } else {
                Button("Show Negative Prompt") {
                    settings.showNegativePrompt = true
                }
                .font(.caption)
            }
        }
    }
}
