//
//  BackendConfiguration.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Backend type identifier
enum BackendType: String, CaseIterable, Codable, Sendable {
    case automatic1111 = "automatic1111"
    case comfyUI = "comfyui"
    case swarmUI = "swarmui"
    case mlxNative = "mlx_native"

    var displayName: String {
        switch self {
        case .automatic1111: return "Automatic1111"
        case .comfyUI: return "ComfyUI"
        case .swarmUI: return "SwarmUI"
        case .mlxNative: return "MLX Native"
        }
    }

    var defaultURL: String {
        switch self {
        case .automatic1111: return "http://localhost:7860"
        case .comfyUI: return "http://localhost:8188"
        case .swarmUI: return "http://localhost:7801"
        case .mlxNative: return ""
        }
    }

    var icon: String {
        switch self {
        case .automatic1111: return "server.rack"
        case .comfyUI: return "point.3.connected.trianglepath.dotted"
        case .swarmUI: return "ant"
        case .mlxNative: return "apple.logo"
        }
    }
}

/// Connection status for a backend
enum BackendStatus: Sendable, Equatable {
    case connected
    case disconnected
    case checking
    case error(String)

    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .checking: return "Checking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusColor: String {
        switch self {
        case .connected: return "green"
        case .disconnected: return "gray"
        case .checking: return "yellow"
        case .error: return "red"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Configuration for a single backend
struct BackendConfiguration: Identifiable, Sendable {
    let id: UUID
    let type: BackendType
    var url: String
    var name: String
    var status: BackendStatus

    init(type: BackendType, url: String? = nil, name: String? = nil) {
        self.id = UUID()
        self.type = type
        self.url = url ?? type.defaultURL
        self.name = name ?? type.displayName
        self.status = .disconnected
    }
}
