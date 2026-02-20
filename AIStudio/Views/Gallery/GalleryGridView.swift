//
//  GalleryGridView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import AppKit

struct GalleryGridView: View {
    let items: [MediaItem]
    @Binding var selectedItem: MediaItem?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No media found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Generated media will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { item in
                        GalleryThumbnail(item: item, isSelected: selectedItem?.id == item.id)
                            .onTapGesture {
                                selectedItem = item
                            }
                    }
                }
                .padding(8)
            }
        }
    }
}

struct GalleryThumbnail: View {
    let item: MediaItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)

                thumbnailContent
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            Text(item.fileName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        switch item.type {
        case .image:
            if let thumbPath = item.thumbnailPath, let image = NSImage(contentsOfFile: thumbPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .cornerRadius(6)
            } else if let image = NSImage(contentsOfFile: item.filePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        case .video:
            ZStack {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
        case .audio:
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }
}
