//
//  GenerationQueue.swift
//  AIStudio
//
//  FIFO generation queue — lets users stack multiple generations and walk away.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// A queued generation request
struct QueuedGeneration: Identifiable {
    let id = UUID()
    let prompt: String
    let negativePrompt: String
    let parameters: GenerationParameters
    let type: GenerationType
    var status: QueueStatus = .pending
    var result: GenerationQueueResult?
    var error: String?
    let createdAt = Date()
    var startedAt: Date?
    var completedAt: Date?

    enum GenerationType: String {
        case textToImage = "txt2img"
        case imageToImage = "img2img"
        case audio = "audio"
        case video = "video"
    }

    enum QueueStatus: String {
        case pending = "Pending"
        case running = "Running"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }
}

/// Parameters for a queued generation
struct GenerationParameters {
    var steps: Int = 20
    var cfgScale: Double = 7.0
    var width: Int = 512
    var height: Int = 512
    var seed: Int = -1
    var samplerName: String = "Euler a"
    var batchSize: Int = 1
}

/// Result from a completed queued generation
struct GenerationQueueResult {
    let imagePaths: [String]
    let metadata: [String: Any]
}

/// FIFO generation queue with concurrent execution control
@MainActor
class GenerationQueue: ObservableObject {

    @Published var queue: [QueuedGeneration] = []
    @Published var isProcessing: Bool = false
    @Published var currentItem: QueuedGeneration?

    /// Maximum items allowed in queue
    let maxQueueSize: Int = 50

    private weak var backendManager: BackendManager?
    private var processingTask: Task<Void, Never>?
    @Published private(set) var isPaused: Bool = false

    func configure(with backendManager: BackendManager) {
        self.backendManager = backendManager
    }

    var pendingCount: Int {
        queue.filter { $0.status == .pending }.count
    }

    var completedCount: Int {
        queue.filter { $0.status == .completed }.count
    }

    var failedCount: Int {
        queue.filter { $0.status == .failed }.count
    }

    // MARK: - Queue Management

    /// Add a generation to the queue
    func enqueue(
        prompt: String,
        negativePrompt: String = "",
        parameters: GenerationParameters = GenerationParameters(),
        type: QueuedGeneration.GenerationType = .textToImage
    ) -> Bool {
        guard queue.count < maxQueueSize else {
            logWarning("Queue full (\(maxQueueSize) items)", category: "Queue")
            return false
        }

        let item = QueuedGeneration(
            prompt: prompt,
            negativePrompt: negativePrompt,
            parameters: parameters,
            type: type
        )
        queue.append(item)
        logInfo("Queued: \(prompt.prefix(50))... (\(pendingCount) pending)", category: "Queue")

        // Auto-start processing if not already running
        if !isProcessing && !isPaused {
            startProcessing()
        }

        return true
    }

    /// Remove an item from the queue (only pending items)
    func remove(id: UUID) {
        queue.removeAll { $0.id == id && $0.status == .pending }
    }

    /// Cancel the currently running item
    func cancelCurrent() {
        if let idx = queue.firstIndex(where: { $0.id == currentItem?.id }) {
            queue[idx].status = .cancelled
            queue[idx].completedAt = Date()
        }
        currentItem = nil
    }

    /// Clear all completed and failed items
    func clearFinished() {
        queue.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }

    /// Clear entire queue (cancels processing)
    func clearAll() {
        stopProcessing()
        queue.removeAll()
    }

    /// Pause queue processing (current item finishes, no new items start)
    func pause() {
        isPaused = true
    }

    /// Resume queue processing
    func resume() {
        isPaused = false
        if !isProcessing && pendingCount > 0 {
            startProcessing()
        }
    }

    /// Move an item up in the queue
    func moveUp(id: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == id && $0.status == .pending }),
              idx > 0 else { return }
        let prevIdx = queue.index(before: idx)
        if queue[prevIdx].status == .pending {
            queue.swapAt(idx, prevIdx)
        }
    }

    /// Move an item down in the queue
    func moveDown(id: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == id && $0.status == .pending }) else { return }
        let nextIdx = queue.index(after: idx)
        guard nextIdx < queue.count, queue[nextIdx].status == .pending else { return }
        queue.swapAt(idx, nextIdx)
    }

    // MARK: - Processing

    private func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true

        processingTask = Task {
            while !isPaused {
                guard let nextIndex = queue.firstIndex(where: { $0.status == .pending }) else {
                    break
                }

                queue[nextIndex].status = .running
                queue[nextIndex].startedAt = Date()
                currentItem = queue[nextIndex]

                let item = queue[nextIndex]

                do {
                    try await processItem(item)
                    if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                        queue[idx].status = .completed
                        queue[idx].completedAt = Date()
                    }
                    logInfo("Queue item completed: \(item.prompt.prefix(40))", category: "Queue")
                } catch is CancellationError {
                    if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                        queue[idx].status = .cancelled
                        queue[idx].completedAt = Date()
                    }
                } catch {
                    if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                        queue[idx].status = .failed
                        queue[idx].error = error.localizedDescription
                        queue[idx].completedAt = Date()
                    }
                    logWarning("Queue item failed: \(error.localizedDescription)", category: "Queue")
                }

                currentItem = nil
            }

            isProcessing = false
        }
    }

    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        currentItem = nil
    }

    private func processItem(_ item: QueuedGeneration) async throws {
        guard let backendManager else {
            throw BackendError.backendSpecific("No backend manager configured")
        }

        guard let backend = backendManager.activeBackend else {
            throw BackendError.notConnected
        }

        let request = ImageGenerationRequest(
            prompt: item.prompt,
            negativePrompt: item.negativePrompt,
            steps: item.parameters.steps,
            samplerName: item.parameters.samplerName,
            cfgScale: item.parameters.cfgScale,
            width: item.parameters.width,
            height: item.parameters.height,
            seed: item.parameters.seed,
            batchSize: item.parameters.batchSize
        )

        let result = try await backend.textToImage(request)

        // Auto-save results
        for (index, image) in result.images.enumerated() {
            let path = try FileOrganizer.saveGeneratedImage(
                image.imageData,
                prompt: result.metadata.prompt,
                seed: result.metadata.seed,
                index: result.images.count > 1 ? index : 0
            )
            FileOrganizer.saveMetadata(result.metadata, alongside: path)
        }
    }
}
