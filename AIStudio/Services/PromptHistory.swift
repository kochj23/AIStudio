//
//  PromptHistory.swift
//  AIStudio
//
//  Indexes and manages prompt history from generation metadata for search and reuse.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// A saved prompt entry with metadata
struct PromptEntry: Identifiable, Codable {
    let id: UUID
    let prompt: String
    let negativePrompt: String
    let parameters: PromptParameters
    let timestamp: Date
    var isFavorite: Bool
    var useCount: Int
    var lastUsed: Date
    var tags: [String]

    init(
        prompt: String,
        negativePrompt: String = "",
        parameters: PromptParameters = PromptParameters(),
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.parameters = parameters
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.useCount = 1
        self.lastUsed = Date()
        self.tags = tags
    }
}

/// Parameters snapshot for a prompt entry
struct PromptParameters: Codable {
    var steps: Int = 20
    var cfgScale: Double = 7.0
    var width: Int = 512
    var height: Int = 512
    var seed: Int = -1
    var samplerName: String = "Euler a"
}

/// Sort options for prompt history
enum PromptSortOrder: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case mostUsed = "Most Used"
    case alphabetical = "A-Z"
    case favorites = "Favorites"
}

/// Manages prompt history — indexes, searches, and provides reuse
@MainActor
class PromptHistory: ObservableObject {
    static let shared = PromptHistory()

    @Published var entries: [PromptEntry] = []
    @Published var searchText: String = ""
    @Published var sortOrder: PromptSortOrder = .newest
    @Published var filterTag: String?

    private let storageURL: URL
    private let maxEntries: Int = 1000

    var filteredEntries: [PromptEntry] {
        var result = entries

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.prompt.lowercased().contains(query) ||
                $0.negativePrompt.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Filter by tag
        if let tag = filterTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Sort
        switch sortOrder {
        case .newest:
            result.sort { $0.lastUsed > $1.lastUsed }
        case .oldest:
            result.sort { $0.timestamp < $1.timestamp }
        case .mostUsed:
            result.sort { $0.useCount > $1.useCount }
        case .alphabetical:
            result.sort { $0.prompt.lowercased() < $1.prompt.lowercased() }
        case .favorites:
            result.sort { ($0.isFavorite ? 0 : 1) < ($1.isFavorite ? 0 : 1) }
        }

        return result
    }

    /// All unique tags across all entries
    var allTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AIStudio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("prompt_history.json")
        load()
    }

    // MARK: - Recording

    /// Record a prompt that was used for generation
    func record(
        prompt: String,
        negativePrompt: String = "",
        steps: Int = 20,
        cfgScale: Double = 7.0,
        width: Int = 512,
        height: Int = 512,
        seed: Int = -1,
        samplerName: String = "Euler a"
    ) {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        // Check for duplicate — if same prompt exists, increment use count
        if let idx = entries.firstIndex(where: { $0.prompt == trimmedPrompt }) {
            entries[idx].useCount += 1
            entries[idx].lastUsed = Date()
            save()
            return
        }

        let params = PromptParameters(
            steps: steps,
            cfgScale: cfgScale,
            width: width,
            height: height,
            seed: seed,
            samplerName: samplerName
        )

        let entry = PromptEntry(
            prompt: trimmedPrompt,
            negativePrompt: negativePrompt,
            parameters: params
        )
        entries.insert(entry, at: 0)

        // Trim to max entries (remove oldest non-favorites)
        if entries.count > maxEntries {
            let nonFavorites = entries.filter { !$0.isFavorite }
            if let oldest = nonFavorites.last {
                entries.removeAll { $0.id == oldest.id }
            }
        }

        save()
    }

    /// Scan output directory for existing metadata and import prompts
    func importFromMetadata(outputPath: String) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: outputPath) else { return }

        var imported = 0
        while let file = enumerator.nextObject() as? String {
            guard file.hasSuffix("_metadata.json") else { continue }

            let fullPath = (outputPath as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: fullPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let prompt = json["prompt"] as? String, !prompt.isEmpty else {
                continue
            }

            let negative = json["negative_prompt"] as? String ?? ""
            let steps = json["steps"] as? Int ?? 20
            let cfg = json["cfg_scale"] as? Double ?? 7.0
            let width = json["width"] as? Int ?? 512
            let height = json["height"] as? Int ?? 512
            let seed = json["seed"] as? Int ?? -1
            let sampler = json["sampler"] as? String ?? "Euler a"

            // Only add if not already in history
            if !entries.contains(where: { $0.prompt == prompt }) {
                let params = PromptParameters(
                    steps: steps, cfgScale: cfg, width: width,
                    height: height, seed: seed, samplerName: sampler
                )
                let entry = PromptEntry(prompt: prompt, negativePrompt: negative, parameters: params)
                entries.append(entry)
                imported += 1
            }
        }

        if imported > 0 {
            save()
            logInfo("Imported \(imported) prompts from metadata", category: "PromptHistory")
        }
    }

    // MARK: - Management

    func toggleFavorite(id: UUID) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].isFavorite.toggle()
            save()
        }
    }

    func addTag(_ tag: String, to id: UUID) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanTag.isEmpty && !entries[idx].tags.contains(cleanTag) {
                entries[idx].tags.append(cleanTag)
                save()
            }
        }
    }

    func removeTag(_ tag: String, from id: UUID) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].tags.removeAll { $0 == tag }
            save()
        }
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([PromptEntry].self, from: data)
        } catch {
            logWarning("Failed to load prompt history: \(error.localizedDescription)", category: "PromptHistory")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL)
        } catch {
            logWarning("Failed to save prompt history: \(error.localizedDescription)", category: "PromptHistory")
        }
    }
}
