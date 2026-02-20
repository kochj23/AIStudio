//
//  ImagePreviewView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ImagePreviewView: View {
    let images: [GeneratedImage]
    @Binding var selectedIndex: Int
    let metadata: GenerationMetadata?
    let isGenerating: Bool
    let onSave: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Image display
            ZStack {
                Color(nsColor: .controlBackgroundColor)

                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if let selectedImage = currentImage, let nsImage = selectedImage.nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .contextMenu {
                            Button("Copy Image") { onCopy() }
                            Button("Save As...") { onSave() }
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No image generated yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text("Enter a prompt and click Generate")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom bar: image strip + actions + metadata
            if !images.isEmpty {
                Divider()

                VStack(spacing: 8) {
                    // Image strip (if batch > 1)
                    if images.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                                    if let nsImage = image.nsImage {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipped()
                                            .border(index == selectedIndex ? Color.accentColor : Color.clear, width: 2)
                                            .onTapGesture { selectedIndex = index }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 68)
                    }

                    // Actions + metadata
                    HStack {
                        Button(action: onCopy) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        Button(action: onSave) {
                            Label("Save As", systemImage: "square.and.arrow.down")
                        }

                        Spacer()

                        if let metadata {
                            Text("\(metadata.width)x\(metadata.height) | \(metadata.steps) steps | Seed: \(metadata.seedDisplay) | \(metadata.formattedTime)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var currentImage: GeneratedImage? {
        guard selectedIndex >= 0 && selectedIndex < images.count else { return nil }
        return images[selectedIndex]
    }
}
