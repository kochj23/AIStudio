//
//  BackendManager.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Manages all image generation backends.
/// Owns backend instances, exposes active backend, runs concurrent health checks.
@MainActor
class BackendManager: ObservableObject {
    @Published var backends: [BackendType: BackendConfiguration] = [:]
    @Published var activeBackendType: BackendType = .automatic1111
    @Published var isRefreshing: Bool = false

    private var a1111Service: Automatic1111Service
    private var comfyUIService: ComfyUIService
    private var swarmUIService: SwarmUIService
    private var mlxImageService: MLXImageService

    let pythonDaemon: PythonDaemonService

    private var cancellables = Set<AnyCancellable>()

    var activeBackend: (any ImageBackendProtocol)? {
        switch activeBackendType {
        case .automatic1111: return a1111Service
        case .comfyUI: return comfyUIService
        case .swarmUI: return swarmUIService
        case .mlxNative: return mlxImageService
        }
    }

    var activeBackendConfig: BackendConfiguration? {
        backends[activeBackendType]
    }

    var isActiveBackendConnected: Bool {
        backends[activeBackendType]?.status.isConnected ?? false
    }

    init() {
        let settings = AppSettings.shared
        self.a1111Service = Automatic1111Service(baseURL: settings.a1111URL)
        self.comfyUIService = ComfyUIService(baseURL: settings.comfyUIURL)
        self.swarmUIService = SwarmUIService(baseURL: settings.swarmUIURL)
        self.pythonDaemon = PythonDaemonService(pythonPath: settings.pythonPath)
        self.mlxImageService = MLXImageService(daemon: pythonDaemon)

        // Initialize backend configurations
        backends[.automatic1111] = BackendConfiguration(type: .automatic1111, url: settings.a1111URL)
        backends[.comfyUI] = BackendConfiguration(type: .comfyUI, url: settings.comfyUIURL)
        backends[.swarmUI] = BackendConfiguration(type: .swarmUI, url: settings.swarmUIURL)
        backends[.mlxNative] = BackendConfiguration(type: .mlxNative)

        if let savedType = BackendType(rawValue: settings.activeBackendType) {
            activeBackendType = savedType
        }

        // Listen for settings changes
        settings.$a1111URL
            .removeDuplicates()
            .sink { [weak self] url in
                guard let self else { return }
                Task { await self.a1111Service.updateBaseURL(url) }
                self.backends[.automatic1111]?.url = url
            }
            .store(in: &cancellables)

        settings.$comfyUIURL
            .removeDuplicates()
            .sink { [weak self] url in
                guard let self else { return }
                Task { await self.comfyUIService.updateBaseURL(url) }
                self.backends[.comfyUI]?.url = url
            }
            .store(in: &cancellables)

        settings.$swarmUIURL
            .removeDuplicates()
            .sink { [weak self] url in
                guard let self else { return }
                Task { await self.swarmUIService.updateBaseURL(url) }
                self.backends[.swarmUI]?.url = url
            }
            .store(in: &cancellables)
    }

    // MARK: - Health Checks

    func refreshAllBackends() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: (BackendType, BackendStatus).self) { group in
            group.addTask { [a1111Service] in
                let status = await a1111Service.checkHealth()
                return (.automatic1111, status)
            }

            group.addTask { [comfyUIService] in
                let status = await comfyUIService.checkHealth()
                return (.comfyUI, status)
            }

            group.addTask { [swarmUIService] in
                let status = await swarmUIService.checkHealth()
                return (.swarmUI, status)
            }

            group.addTask { [mlxImageService] in
                let status = await mlxImageService.checkHealth()
                return (.mlxNative, status)
            }

            for await (type, status) in group {
                backends[type]?.status = status
            }
        }
    }

    func refreshBackend(_ type: BackendType) async {
        backends[type]?.status = .checking

        let status: BackendStatus
        switch type {
        case .automatic1111:
            status = await a1111Service.checkHealth()
        case .comfyUI:
            status = await comfyUIService.checkHealth()
        case .swarmUI:
            status = await swarmUIService.checkHealth()
        case .mlxNative:
            status = await mlxImageService.checkHealth()
        }
        backends[type]?.status = status
    }

    // MARK: - Backend Selection

    func setActiveBackend(_ type: BackendType) {
        activeBackendType = type
        AppSettings.shared.activeBackendType = type.rawValue
    }

    // MARK: - Model/Sampler Listing

    func listModels() async throws -> [A1111Model] {
        guard let backend = activeBackend else {
            throw BackendError.notConnected
        }
        return try await backend.listModels()
    }

    func listSamplers() async throws -> [A1111Sampler] {
        guard let backend = activeBackend else {
            throw BackendError.notConnected
        }
        return try await backend.listSamplers()
    }
}
