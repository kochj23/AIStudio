//
//  PromptHistoryView.swift
//  AIStudio
//
//  Browse, search, and reuse previously used prompts.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// A browsable, searchable prompt history panel for selecting and managing saved prompts.
struct PromptHistoryView: View {
    @ObservedObject var history: PromptHistory
    let onSelectPrompt: (PromptEntry) -> Void

    @State private var showingClearConfirmation = false
    @State private var showingAddTagSheet = false
    @State private var tagEntryID: UUID?
    @State private var newTagText: String = ""
    @State private var hoveredEntryID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search & Sort Toolbar

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Search bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField("Search prompts...", text: $history.searchText)
                            .textFieldStyle(.plain)
                            .font(.body)
                        if !history.searchText.isEmpty {
                            Button(action: { history.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                    // Sort picker
                    Picker("", selection: $history.sortOrder) {
                        ForEach(PromptSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 120)

                    // Clear all
                    Button(action: { showingClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all prompt history")
                    .disabled(history.entries.isEmpty)
                }

                // MARK: - Tag Filter Chips

                if !history.allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // "All" chip
                            TagChipView(
                                label: "All",
                                isSelected: history.filterTag == nil,
                                action: { history.filterTag = nil }
                            )

                            ForEach(history.allTags, id: \.self) { tag in
                                TagChipView(
                                    label: tag,
                                    isSelected: history.filterTag == tag,
                                    action: {
                                        if history.filterTag == tag {
                                            history.filterTag = nil
                                        } else {
                                            history.filterTag = tag
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(8)

            Divider()

            // MARK: - Entry Count

            HStack {
                Text("\(history.filteredEntries.count) prompt\(history.filteredEntries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if history.filterTag != nil {
                    Button("Clear Filter") {
                        history.filterTag = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // MARK: - Prompt List

            if history.filteredEntries.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(history.filteredEntries) { entry in
                        PromptEntryRow(
                            entry: entry,
                            isHovered: hoveredEntryID == entry.id,
                            onToggleFavorite: { history.toggleFavorite(id: entry.id) },
                            onSelect: { onSelectPrompt(entry) }
                        )
                        .onHover { isHovered in
                            hoveredEntryID = isHovered ? entry.id : nil
                        }
                        .contextMenu {
                            contextMenuContent(for: entry)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .alert("Clear All History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                history.clearAll()
            }
        } message: {
            Text("This will permanently delete all \(history.entries.count) prompt entries including favorites. This cannot be undone.")
        }
        .sheet(isPresented: $showingAddTagSheet) {
            addTagSheet
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            if !history.searchText.isEmpty || history.filterTag != nil {
                Text("No prompts match your search")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Try a different search term or clear the filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Clear Search & Filters") {
                    history.searchText = ""
                    history.filterTag = nil
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)
            } else {
                Text("No prompt history yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Prompts will appear here after you generate images.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for entry: PromptEntry) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.prompt, forType: .string)
        } label: {
            Label("Copy Prompt", systemImage: "doc.on.doc")
        }

        if !entry.negativePrompt.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.negativePrompt, forType: .string)
            } label: {
                Label("Copy Negative Prompt", systemImage: "doc.on.doc.fill")
            }
        }

        Divider()

        Button {
            history.toggleFavorite(id: entry.id)
        } label: {
            Label(
                entry.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: entry.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Button {
            tagEntryID = entry.id
            newTagText = ""
            showingAddTagSheet = true
        } label: {
            Label("Add Tag...", systemImage: "tag")
        }

        if !entry.tags.isEmpty {
            Menu("Remove Tag") {
                ForEach(entry.tags, id: \.self) { tag in
                    Button(tag) {
                        history.removeTag(tag, from: entry.id)
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            history.delete(id: entry.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Add Tag Sheet

    private var addTagSheet: some View {
        VStack(spacing: 16) {
            Text("Add Tag")
                .font(.headline)

            TextField("Tag name", text: $newTagText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit {
                    commitNewTag()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showingAddTagSheet = false
                }
                .keyboardShortcut(.escape)

                Button("Add") {
                    commitNewTag()
                }
                .keyboardShortcut(.return)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 280)
    }

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let id = tagEntryID else { return }
        history.addTag(trimmed, to: id)
        showingAddTagSheet = false
    }
}

// MARK: - Prompt Entry Row

private struct PromptEntryRow: View {
    let entry: PromptEntry
    let isHovered: Bool
    let onToggleFavorite: () -> Void
    let onSelect: () -> Void

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Top row: prompt text + favorite star
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.prompt)
                        .font(.body)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onToggleFavorite) {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(entry.isFavorite ? .yellow : .secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
                }

                // Negative prompt (if present)
                if !entry.negativePrompt.isEmpty {
                    Text("Neg: \(entry.negativePrompt)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Bottom row: metadata
                HStack(spacing: 8) {
                    // Parameters summary
                    Text("\(entry.parameters.width)x\(entry.parameters.height) | \(entry.parameters.steps) steps | \(entry.parameters.samplerName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Use count badge
                    if entry.useCount > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8))
                            Text("\(entry.useCount)")
                                .font(.caption2)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                    }

                    // Last used date
                    Text(Self.dateFormatter.localizedString(for: entry.lastUsed, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Tags
                if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(entry.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.secondary.opacity(0.06) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Tag Chip View

private struct TagChipView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
