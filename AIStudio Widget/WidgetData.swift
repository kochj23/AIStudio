//
//  WidgetData.swift
//  AIStudio Widget
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

let appGroupIdentifier = "group.com.jkoch.aistudio"

// MARK: - Widget Data Models

/// Summary data shared between the main app and widget
struct AIStudioWidgetData: Codable {
    var imageBackendName: String?
    var imageBackendConnected: Bool
    var llmBackendName: String?
    var llmBackendConnected: Bool
    var ollamaModel: String?
    var backendsOnline: Int
    var backendsTotal: Int
    var lastGenerationType: String? // "image", "video", "audio", "chat"
    var lastGenerationTime: Date?
    var totalGenerations: Int
    var lastUpdated: Date

    init() {
        self.imageBackendName = nil
        self.imageBackendConnected = false
        self.llmBackendName = nil
        self.llmBackendConnected = false
        self.ollamaModel = nil
        self.backendsOnline = 0
        self.backendsTotal = 0
        self.lastGenerationType = nil
        self.lastGenerationTime = nil
        self.totalGenerations = 0
        self.lastUpdated = Date()
    }
}

/// Individual backend status for large widget
struct WidgetBackendStatus: Codable, Identifiable {
    var id: String
    var name: String
    var category: String // "image" or "llm"
    var connected: Bool
}

// MARK: - Widget Timeline Entry

struct AIStudioWidgetEntry: TimelineEntry {
    let date: Date
    let data: AIStudioWidgetData

    init(date: Date = Date(), data: AIStudioWidgetData = AIStudioWidgetData()) {
        self.date = date
        self.data = data
    }

    static var placeholder: AIStudioWidgetEntry {
        var data = AIStudioWidgetData()
        data.imageBackendName = "Automatic1111"
        data.imageBackendConnected = true
        data.llmBackendName = "Ollama"
        data.llmBackendConnected = true
        data.ollamaModel = "mistral:latest"
        data.backendsOnline = 3
        data.backendsTotal = 8
        data.lastGenerationType = "image"
        data.lastGenerationTime = Date().addingTimeInterval(-1800)
        data.totalGenerations = 42
        return AIStudioWidgetEntry(date: Date(), data: data)
    }
}

// MARK: - Helpers

extension AIStudioWidgetData {
    var healthColorName: String {
        if backendsTotal == 0 { return "gray" }
        let ratio = Double(backendsOnline) / Double(backendsTotal)
        switch ratio {
        case 0.75...1.0: return "green"
        case 0.5..<0.75: return "yellow"
        case 0.25..<0.5: return "orange"
        default: return "red"
        }
    }

    var generationTypeIcon: String {
        switch lastGenerationType {
        case "image": return "photo.artframe"
        case "video": return "film"
        case "audio": return "waveform"
        case "chat": return "brain.head.profile"
        default: return "sparkles"
        }
    }

    var generationTypeLabel: String {
        switch lastGenerationType {
        case "image": return "Image"
        case "video": return "Video"
        case "audio": return "Audio"
        case "chat": return "Chat"
        default: return "None"
        }
    }
}

extension Date {
    var widgetRelativeTimeString: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "\(Int(interval))s ago" }
        else if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        else { return "\(Int(interval / 86400))d ago" }
    }
}
