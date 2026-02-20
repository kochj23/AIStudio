//
//  WidgetDataSync.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Syncs main app state to the widget via shared Application Support directory.
class WidgetDataSyncService {
    static let shared = WidgetDataSyncService()

    private let dataFileName = "widget_data.json"
    private let appSupportFolder = "AIStudio"
    private let appGroupIdentifier = "group.com.jkoch.aistudio"

    private var containerURL: URL? {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL
        }
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent(appSupportFolder, isDirectory: true)
    }

    private var dataFileURL: URL? {
        containerURL?.appendingPathComponent(dataFileName)
    }

    private init() {}

    /// Update widget data from current app state
    @MainActor
    func syncFromAppState(
        backendManager: BackendManager,
        llmBackendManager: LLMBackendManager,
        lastGenerationType: String? = nil,
        totalGenerations: Int = 0
    ) {
        var data = WidgetData()
        // Image backend info
        if let activeBackend = backendManager.backends.first(where: { $0.value.status == .connected }) {
            data.imageBackendName = activeBackend.key.displayName
            data.imageBackendConnected = true
        } else {
            data.imageBackendName = nil
            data.imageBackendConnected = false
        }

        // LLM backend info
        if let resolvedLLM = llmBackendManager.resolvedBackend {
            data.llmBackendName = resolvedLLM.displayName
            data.llmBackendConnected = true
        } else {
            data.llmBackendName = nil
            data.llmBackendConnected = false
        }

        data.ollamaModel = llmBackendManager.selectedOllamaModel.isEmpty ? nil : llmBackendManager.selectedOllamaModel

        // Count all backends
        let imageOnline = backendManager.backends.values.filter { $0.status == .connected }.count
        let llmOnline = llmBackendManager.backends.values.filter { $0.status == .connected }.count
        data.backendsOnline = imageOnline + llmOnline
        data.backendsTotal = backendManager.backends.count + llmBackendManager.backends.count

        data.lastGenerationType = lastGenerationType
        if lastGenerationType != nil {
            data.lastGenerationTime = Date()
        }
        data.totalGenerations = totalGenerations
        data.lastUpdated = Date()

        saveWidgetData(data)
    }

    private func saveWidgetData(_ widgetData: WidgetData) {
        guard let url = dataFileURL else { return }
        if let containerURL = containerURL {
            try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(widgetData)
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[WidgetSync] Failed to save widget data: \(error)")
        }
    }

    /// Simple Codable struct matching the widget's data model
    private struct WidgetData: Codable {
        var imageBackendName: String?
        var imageBackendConnected: Bool = false
        var llmBackendName: String?
        var llmBackendConnected: Bool = false
        var ollamaModel: String?
        var backendsOnline: Int = 0
        var backendsTotal: Int = 0
        var lastGenerationType: String?
        var lastGenerationTime: Date?
        var totalGenerations: Int = 0
        var lastUpdated: Date = Date()
    }
}
