//
//  GenerationQueueView.swift
//  AIStudio
//
//  Queue management UI for batch image generation.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Displays the generation queue with status, controls, and per-item management.
struct GenerationQueueView: View {
    @ObservedObject var queue: GenerationQueue

    @State private var showFinished: Bool = true
    @State private var hoveredItemID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            queueHeader
            Divider()

            if queue.queue.isEmpty {
                emptyState
            } else {
                queueList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var queueHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Generation Queue", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                Text("\(queue.queue.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Status counts
            HStack(spacing: 16) {
                statusBadge(count: queue.pendingCount, label: "Pending", color: .orange)
                statusBadge(count: queue.completedCount, label: "Done", color: .green)
                statusBadge(count: queue.failedCount, label: "Failed", color: .red)
                Spacer()
            }

            // Control buttons
            HStack(spacing: 8) {
                if queue.isPaused {
                    Button {
                        queue.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button {
                        queue.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .controlSize(.small)
                    .disabled(queue.pendingCount == 0 && !queue.isProcessing)
                }

                Spacer()

                Button {
                    queue.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(queue.completedCount == 0 && queue.failedCount == 0)

                Button(role: .destructive) {
                    queue.clearAll()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .controlSize(.small)
                .disabled(queue.queue.isEmpty)
            }
        }
        .padding(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Queue is empty")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Add generations to the queue to process them in batch.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Queue List

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Running item (if any)
                if let current = queue.currentItem,
                   let liveItem = queue.queue.first(where: { $0.id == current.id }) {
                    runningItemRow(liveItem)
                    Divider()
                }

                // Pending items
                let pendingItems = queue.queue.filter { $0.status == .pending }
                if !pendingItems.isEmpty {
                    sectionHeader("Pending (\(pendingItems.count))")
                    ForEach(pendingItems) { item in
                        pendingItemRow(item)
                        Divider()
                    }
                }

                // Finished items (collapsible)
                let finishedItems = queue.queue.filter {
                    $0.status == .completed || $0.status == .failed || $0.status == .cancelled
                }
                if !finishedItems.isEmpty {
                    finishedSection(items: finishedItems)
                }
            }
        }
    }

    // MARK: - Running Item

    private func runningItemRow(_ item: QueuedGeneration) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.prompt)
                    .font(.callout)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)

                    if let started = item.startedAt {
                        Text(elapsedString(from: started))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text("\(item.parameters.width) x \(item.parameters.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("\(item.parameters.steps) steps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                queue.cancelCurrent()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Cancel current generation")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }

    // MARK: - Pending Item

    private func pendingItemRow(_ item: QueuedGeneration) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundColor(.orange)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.prompt)
                    .font(.callout)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)

                    Text("\(item.parameters.width) x \(item.parameters.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("\(item.parameters.steps) steps")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(relativeTimeString(from: item.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Reorder buttons
            HStack(spacing: 2) {
                Button {
                    queue.moveUp(id: item.id)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Move up in queue")

                Button {
                    queue.moveDown(id: item.id)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Move down in queue")
            }
            .opacity(hoveredItemID == item.id ? 1 : 0.3)

            Button {
                queue.remove(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Remove from queue")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : nil
        }
    }

    // MARK: - Finished Section

    private func finishedSection(items: [QueuedGeneration]) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFinished.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showFinished ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 12)
                    Text("Finished (\(items.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showFinished {
                ForEach(items) { item in
                    finishedItemRow(item)
                    Divider()
                }
            }
        }
    }

    private func finishedItemRow(_ item: QueuedGeneration) -> some View {
        HStack(spacing: 10) {
            statusIcon(for: item.status)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.prompt)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text(item.status.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusBackgroundColor(for: item.status))
                        .cornerRadius(4)

                    if let duration = durationString(from: item.startedAt, to: item.completedAt) {
                        Text(duration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let error = item.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .help(error)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .opacity(0.8)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .separatorColor).opacity(0.2))
    }

    private func statusBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(count > 0 ? color : color.opacity(0.3))
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func statusIcon(for status: QueuedGeneration.QueueStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.orange)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.gray)
        }
    }

    private func statusBackgroundColor(for status: QueuedGeneration.QueueStatus) -> Color {
        switch status {
        case .pending: return .orange.opacity(0.15)
        case .running: return .blue.opacity(0.15)
        case .completed: return .green.opacity(0.15)
        case .failed: return .red.opacity(0.15)
        case .cancelled: return .gray.opacity(0.15)
        }
    }

    /// Returns a live elapsed-time string like "12s" from a start date.
    private func elapsedString(from start: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(start))
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }

    /// Returns a human-readable relative timestamp like "2 min ago".
    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) min ago"
        }
        let hours = minutes / 60
        return "\(hours)h ago"
    }

    /// Returns a formatted duration string between two optional dates.
    private func durationString(from start: Date?, to end: Date?) -> String? {
        guard let start, let end else { return nil }
        let seconds = Int(end.timeIntervalSince(start))
        if seconds < 1 { return "<1s" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }
}

// MARK: - Preview

#Preview("Queue with items") {
    GenerationQueueView(queue: GenerationQueue())
        .frame(width: 380, height: 500)
}
