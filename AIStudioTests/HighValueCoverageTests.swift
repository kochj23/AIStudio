//
//  HighValueCoverageTests.swift
//  AIStudioTests
//
//  High-value tests for previously-uncovered, high-risk deterministic logic:
//   - GenerationQueue: FIFO ordering, 50-item cap, pending-only removal,
//     reordering boundaries, status counts, clear/pause behavior.
//   - ComfyUIService: SafeTensors-only checkpoint enforcement (.ckpt/.bin/.pt
//     blocking) enforced before any network call.
//   - PromptHistory: search across prompt/negative/tags, tag filtering,
//     tag dedup, and sort orderings.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

// MARK: - GenerationQueue

@MainActor
final class GenerationQueueLogicTests: XCTestCase {

    /// Returns a paused queue so no auto-processing task runs — queue state stays
    /// fully deterministic for FIFO/reorder/count assertions.
    private func makePausedQueue() -> GenerationQueue {
        let queue = GenerationQueue()
        queue.pause()
        return queue
    }

    func testEnqueuePreservesFIFOOrder() {
        let queue = makePausedQueue()
        XCTAssertTrue(queue.enqueue(prompt: "first"))
        XCTAssertTrue(queue.enqueue(prompt: "second"))
        XCTAssertTrue(queue.enqueue(prompt: "third"))

        XCTAssertEqual(queue.queue.map { $0.prompt }, ["first", "second", "third"])
        XCTAssertEqual(queue.pendingCount, 3)
        XCTAssertFalse(queue.isProcessing, "Paused queue must not auto-start processing")
    }

    func testEnqueueEnforcesFiftyItemCap() {
        let queue = makePausedQueue()
        for i in 0..<queue.maxQueueSize {
            XCTAssertTrue(queue.enqueue(prompt: "item \(i)"), "First \(queue.maxQueueSize) must be accepted")
        }
        XCTAssertEqual(queue.queue.count, 50)
        XCTAssertFalse(queue.enqueue(prompt: "overflow"), "51st item must be rejected")
        XCTAssertEqual(queue.queue.count, 50, "Queue must not grow past cap")
    }

    func testRemoveOnlyAffectsPendingItems() {
        let queue = makePausedQueue()
        queue.enqueue(prompt: "a")
        queue.enqueue(prompt: "b")

        let firstId = queue.queue[0].id
        queue.remove(id: firstId)
        XCTAssertEqual(queue.queue.map { $0.prompt }, ["b"])

        // A running item must not be removable.
        queue.queue[0].status = .running
        let runningId = queue.queue[0].id
        queue.remove(id: runningId)
        XCTAssertEqual(queue.queue.count, 1, "Running item must not be removed")
    }

    func testMoveUpAndMoveDownReorderPendingItems() {
        let queue = makePausedQueue()
        queue.enqueue(prompt: "a")
        queue.enqueue(prompt: "b")
        queue.enqueue(prompt: "c")

        let idB = queue.queue[1].id
        queue.moveUp(id: idB)
        XCTAssertEqual(queue.queue.map { $0.prompt }, ["b", "a", "c"])

        queue.moveDown(id: idB)
        XCTAssertEqual(queue.queue.map { $0.prompt }, ["a", "b", "c"])
    }

    func testMoveBoundariesAreNoOps() {
        let queue = makePausedQueue()
        queue.enqueue(prompt: "a")
        queue.enqueue(prompt: "b")
        queue.enqueue(prompt: "c")

        let firstId = queue.queue[0].id
        queue.moveUp(id: firstId) // already at top
        XCTAssertEqual(queue.queue.map { $0.prompt }, ["a", "b", "c"])

        let lastId = queue.queue[2].id
        queue.moveDown(id: lastId) // already at bottom
        XCTAssertEqual(queue.queue.map { $0.prompt }, ["a", "b", "c"])
    }

    func testStatusCountsAndClearFinished() {
        let queue = makePausedQueue()
        queue.enqueue(prompt: "a")
        queue.enqueue(prompt: "b")
        queue.enqueue(prompt: "c")
        queue.enqueue(prompt: "d")

        queue.queue[0].status = .completed
        queue.queue[1].status = .failed
        queue.queue[2].status = .cancelled
        // queue[3] stays .pending

        XCTAssertEqual(queue.completedCount, 1)
        XCTAssertEqual(queue.failedCount, 1)
        XCTAssertEqual(queue.pendingCount, 1)

        queue.clearFinished()
        XCTAssertEqual(queue.queue.count, 1, "Completed/failed/cancelled must be cleared")
        XCTAssertEqual(queue.queue[0].status, .pending, "Pending item must survive clearFinished")
    }

    func testClearAllEmptiesQueueAndStopsProcessing() {
        let queue = makePausedQueue()
        queue.enqueue(prompt: "a")
        queue.enqueue(prompt: "b")

        queue.clearAll()
        XCTAssertTrue(queue.queue.isEmpty)
        XCTAssertFalse(queue.isProcessing)
    }

    func testPauseSuppressesAutoProcessing() {
        let queue = GenerationQueue()
        XCTAssertFalse(queue.isPaused)

        queue.pause()
        XCTAssertTrue(queue.isPaused)

        // Enqueue while paused must not begin processing.
        XCTAssertTrue(queue.enqueue(prompt: "x"))
        XCTAssertFalse(queue.isProcessing)

        queue.resume()
        XCTAssertFalse(queue.isPaused)

        queue.clearAll() // cancel any processing task spawned by resume
    }
}

// MARK: - ComfyUI SafeTensors enforcement

final class ComfyUISafeTensorsTests: XCTestCase {

    /// Runs textToImage with a given checkpoint and returns the thrown error (if any).
    /// Rejection happens before any network call, so no live backend is required.
    private func errorForCheckpoint(_ checkpoint: String) async -> Error? {
        let service = ComfyUIService(baseURL: "http://127.0.0.1:8188")
        let request = ImageGenerationRequest(prompt: "a test prompt", checkpointName: checkpoint)
        do {
            _ = try await service.textToImage(request)
            return nil
        } catch {
            return error
        }
    }

    private func assertRejectedAsUnsafe(_ checkpoint: String) async {
        guard let error = await errorForCheckpoint(checkpoint) else {
            return XCTFail("Expected rejection for unsafe checkpoint '\(checkpoint)'")
        }
        guard let backendError = error as? BackendError,
              case .decodingFailed(let message) = backendError else {
            return XCTFail("Expected BackendError.decodingFailed for '\(checkpoint)', got \(error)")
        }
        XCTAssertTrue(
            message.contains("Unsafe model format rejected"),
            "Rejection message should name the unsafe format for '\(checkpoint)': \(message)"
        )
    }

    func testRejectsPickleFormatCheckpoints() async {
        await assertRejectedAsUnsafe("model.ckpt")
        await assertRejectedAsUnsafe("weights.bin")
        await assertRejectedAsUnsafe("model.pt")
    }

    func testRejectsUnknownExtensionsByDefault() async {
        // Safe-by-default: anything that is not .safetensors is excluded.
        await assertRejectedAsUnsafe("legacy.pth")
        await assertRejectedAsUnsafe("model.zip")
    }

    func testRejectionIsCaseInsensitive() async {
        await assertRejectedAsUnsafe("MODEL.CKPT")
        await assertRejectedAsUnsafe("Weights.Bin")
    }

    func testSafeTensorsCheckpointPassesFormatValidation() async {
        // A .safetensors name must clear the SafeTensors guard. It then hits the
        // (unavailable) backend, so any resulting error must NOT be the unsafe-format rejection.
        guard let error = await errorForCheckpoint("sd_xl_base_1.0.safetensors") else {
            return // No error at all also means it was not rejected as unsafe.
        }
        if let backendError = error as? BackendError,
           case .decodingFailed(let message) = backendError {
            XCTAssertFalse(
                message.contains("Unsafe model format rejected"),
                "A .safetensors checkpoint must not be rejected as unsafe"
            )
        }
    }
}

// MARK: - PromptHistory filtering & sorting

@MainActor
final class PromptHistoryFilterTests: XCTestCase {

    private var savedEntries: [PromptEntry] = []

    override func setUp() {
        super.setUp()
        // Snapshot the singleton's in-memory entries. Tests only assign `entries`
        // directly (never call record/delete/clearAll), so nothing is written to disk.
        savedEntries = PromptHistory.shared.entries
    }

    override func tearDown() {
        let history = PromptHistory.shared
        history.entries = savedEntries
        history.searchText = ""
        history.filterTag = nil
        history.sortOrder = .newest
        super.tearDown()
    }

    private func makeEntry(
        _ prompt: String,
        negative: String = "",
        tags: [String] = [],
        favorite: Bool = false,
        useCount: Int = 1,
        lastUsed: Date? = nil
    ) -> PromptEntry {
        var entry = PromptEntry(prompt: prompt, negativePrompt: negative, isFavorite: favorite, tags: tags)
        entry.useCount = useCount
        if let lastUsed { entry.lastUsed = lastUsed }
        return entry
    }

    func testSearchMatchesPromptText() {
        let history = PromptHistory.shared
        history.entries = [makeEntry("a cat in space"), makeEntry("a dog on grass")]
        history.searchText = "cat"

        XCTAssertEqual(history.filteredEntries.count, 1)
        XCTAssertEqual(history.filteredEntries.first?.prompt, "a cat in space")
    }

    func testSearchMatchesNegativePromptAndTags() {
        let history = PromptHistory.shared
        history.entries = [
            makeEntry("landscape", negative: "blurry, lowres"),
            makeEntry("portrait", tags: ["headshot", "studio"])
        ]

        history.searchText = "blurry"
        XCTAssertEqual(history.filteredEntries.count, 1, "Should match negative prompt")

        history.searchText = "studio"
        XCTAssertEqual(history.filteredEntries.count, 1, "Should match a tag")
    }

    func testSearchIsCaseInsensitive() {
        let history = PromptHistory.shared
        history.entries = [makeEntry("Majestic Mountain")]
        history.searchText = "MAJESTIC"
        XCTAssertEqual(history.filteredEntries.count, 1)
    }

    func testTagFilterKeepsOnlyMatchingEntries() {
        let history = PromptHistory.shared
        history.entries = [
            makeEntry("a", tags: ["x"]),
            makeEntry("b", tags: ["y"]),
            makeEntry("c", tags: ["x", "y"])
        ]
        history.filterTag = "x"
        XCTAssertEqual(Set(history.filteredEntries.map { $0.prompt }), ["a", "c"])
    }

    func testAllTagsIsDedupedAndSorted() {
        let history = PromptHistory.shared
        history.entries = [
            makeEntry("a", tags: ["blue", "art"]),
            makeEntry("b", tags: ["art", "cinematic"])
        ]
        XCTAssertEqual(history.allTags, ["art", "blue", "cinematic"])
    }

    func testSortMostUsedOrdersByUseCountDescending() {
        let history = PromptHistory.shared
        history.entries = [
            makeEntry("low", useCount: 1),
            makeEntry("high", useCount: 9),
            makeEntry("mid", useCount: 5)
        ]
        history.sortOrder = .mostUsed
        XCTAssertEqual(history.filteredEntries.map { $0.prompt }, ["high", "mid", "low"])
    }

    func testSortAlphabeticalIsCaseInsensitive() {
        let history = PromptHistory.shared
        history.entries = [makeEntry("Zebra"), makeEntry("apple"), makeEntry("Mango")]
        history.sortOrder = .alphabetical
        XCTAssertEqual(history.filteredEntries.map { $0.prompt.lowercased() }, ["apple", "mango", "zebra"])
    }

    func testSortFavoritesPlacesFavoritesFirst() {
        let history = PromptHistory.shared
        history.entries = [makeEntry("plain"), makeEntry("starred", favorite: true)]
        history.sortOrder = .favorites
        XCTAssertTrue(history.filteredEntries.first?.isFavorite ?? false)
    }

    func testSortNewestUsesLastUsed() {
        let history = PromptHistory.shared
        history.entries = [
            makeEntry("older", lastUsed: Date(timeIntervalSince1970: 1_000)),
            makeEntry("newer", lastUsed: Date(timeIntervalSince1970: 2_000))
        ]
        history.sortOrder = .newest
        XCTAssertEqual(history.filteredEntries.first?.prompt, "newer")
    }
}
