//
//  SharedDataManager.swift
//  AIStudio Widget
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Reads widget data from the shared Application Support directory.
class SharedDataManager {
    static let shared = SharedDataManager()

    private let dataFileName = "widget_data.json"
    private let appSupportFolder = "AIStudio"

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

    func loadWidgetData() -> AIStudioWidgetData {
        guard let url = dataFileURL else {
            return AIStudioWidgetData()
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AIStudioWidgetData()
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AIStudioWidgetData.self, from: data)
        } catch {
            print("[Widget] Failed to load widget data: \(error)")
            return AIStudioWidgetData()
        }
    }

    func saveWidgetData(_ widgetData: AIStudioWidgetData) {
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
            print("[SharedData] Failed to save widget data: \(error)")
        }
    }
}
