//
//  AIStudioWidget.swift
//  AIStudio Widget
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct AIStudioWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AIStudioWidgetEntry {
        AIStudioWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AIStudioWidgetEntry) -> Void) {
        if context.isPreview {
            completion(AIStudioWidgetEntry.placeholder)
        } else {
            let data = SharedDataManager.shared.loadWidgetData()
            completion(AIStudioWidgetEntry(date: Date(), data: data))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AIStudioWidgetEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = AIStudioWidgetEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct AIStudioWidgetSmallView: View {
    let entry: AIStudioWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                Text("AI Studio")
                    .font(.caption.bold())
                Spacer()
            }

            Spacer()

            // Backend status
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.data.imageBackendConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(entry.data.imageBackendName ?? "No Backend")
                    .font(.caption2)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(entry.data.llmBackendConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(entry.data.llmBackendName ?? "No LLM")
                    .font(.caption2)
                    .lineLimit(1)
            }

            Spacer()

            // Stats
            HStack {
                Image(systemName: "server.rack")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(entry.data.backendsOnline)/\(entry.data.backendsTotal)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.data.totalGenerations)")
                    .font(.caption2.bold())
                    .foregroundColor(.purple)
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct AIStudioWidgetMediumView: View {
    let entry: AIStudioWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left - Status overview
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("AI Studio")
                        .font(.headline)
                }

                // Image backend
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.data.imageBackendConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "photo.artframe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.data.imageBackendName ?? "No Image Backend")
                        .font(.caption)
                        .lineLimit(1)
                }

                // LLM backend
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.data.llmBackendConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.data.llmBackendName ?? "No LLM Backend")
                        .font(.caption)
                        .lineLimit(1)
                }

                if let model = entry.data.ollamaModel {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(model)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 14)
                }
            }

            Spacer()

            // Right - Activity
            VStack(alignment: .trailing, spacing: 8) {
                // Backends online
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Backends")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(entry.data.backendsOnline)")
                            .font(.title2.bold())
                            .foregroundColor(healthColor)
                        Text("/ \(entry.data.backendsTotal)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Last generation
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Generation")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let time = entry.data.lastGenerationTime {
                        HStack(spacing: 4) {
                            Image(systemName: entry.data.generationTypeIcon)
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text(entry.data.generationTypeLabel)
                                .font(.caption.bold())
                        }
                        Text(time.widgetRelativeTimeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("None yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Total count
                HStack(spacing: 4) {
                    Text("\(entry.data.totalGenerations)")
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                    Text("total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private var healthColor: Color {
        switch entry.data.healthColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }
}

// MARK: - Large Widget View

struct AIStudioWidgetLargeView: View {
    let entry: AIStudioWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("AI Studio")
                    .font(.headline)
                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 8, height: 8)
                    Text("\(entry.data.backendsOnline)/\(entry.data.backendsTotal) online")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(healthColor.opacity(0.15))
                .cornerRadius(8)
            }

            Divider()

            // Image generation backends
            VStack(alignment: .leading, spacing: 4) {
                Text("Image Generation")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.data.imageBackendConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "photo.artframe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.data.imageBackendName ?? "No backend")
                        .font(.caption)
                    if entry.data.imageBackendConnected {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    Spacer()
                }
            }

            // LLM backends
            VStack(alignment: .leading, spacing: 4) {
                Text("LLM Chat")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.data.llmBackendConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.data.llmBackendName ?? "No backend")
                        .font(.caption)
                    if entry.data.llmBackendConnected {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    Spacer()
                }

                if let model = entry.data.ollamaModel {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                        Text("Model: \(model)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Activity summary
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Generations")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(entry.data.totalGenerations)")
                        .font(.title3.bold())
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let time = entry.data.lastGenerationTime {
                        HStack(spacing: 4) {
                            Image(systemName: entry.data.generationTypeIcon)
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text(entry.data.generationTypeLabel)
                                .font(.subheadline.bold())
                        }
                        Text(time.widgetRelativeTimeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No activity yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Spacer()

            // Capabilities
            HStack(spacing: 12) {
                Label("Images", systemImage: "photo.artframe")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Label("Videos", systemImage: "film")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Label("Audio", systemImage: "waveform")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Label("Chat", systemImage: "brain.head.profile")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var healthColor: Color {
        switch entry.data.healthColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }
}

// MARK: - Widget Entry View

struct AIStudioWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: AIStudioWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            AIStudioWidgetSmallView(entry: entry)
        case .systemMedium:
            AIStudioWidgetMediumView(entry: entry)
        case .systemLarge:
            AIStudioWidgetLargeView(entry: entry)
        default:
            AIStudioWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

@main
struct AIStudioWidget: Widget {
    let kind: String = "AIStudioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AIStudioWidgetProvider()) { entry in
            AIStudioWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AI Studio Status")
        .description("Monitor backend connections, LLM status, and generation activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AIStudioWidget()
} timeline: {
    AIStudioWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    AIStudioWidget()
} timeline: {
    AIStudioWidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    AIStudioWidget()
} timeline: {
    AIStudioWidgetEntry.placeholder
}
