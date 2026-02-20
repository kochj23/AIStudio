//
//  MediaDetailView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import AppKit

struct MediaDetailView: View {
    let item: MediaItem
    let onDelete: () -> Void
    let onReveal: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            previewSection
                .frame(maxHeight: 400)

            Divider()

            // Metadata
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // File info
                    Group {
                        detailRow("File", item.fileName)
                        detailRow("Type", item.type.rawValue.capitalized)
                        detailRow("Created", formattedDate(item.createdAt))

                        if let fileSize = fileSize(item.filePath) {
                            detailRow("Size", fileSize)
                        }
                    }

                    if !item.metadata.isEmpty {
                        Divider()
                        Text("Generation Metadata")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(item.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            detailRow(key.capitalized, value)
                        }
                    }

                    Divider()

                    // Actions
                    HStack {
                        Button(action: onReveal) {
                            Label("Reveal", systemImage: "folder")
                        }

                        Spacer()

                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .padding()
            }
        }
        .alert("Delete this file?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(item.fileName) and its metadata.")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        switch item.type {
        case .image:
            if let image = NSImage(contentsOfFile: item.filePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            }
        case .video:
            VStack {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Video preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.05))
        case .audio:
            VStack {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Audio file")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.05))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func fileSize(_ path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
