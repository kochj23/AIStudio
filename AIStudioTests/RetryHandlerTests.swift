//
//  RetryHandlerTests.swift
//  AIStudioTests
//
//  Tests for RetryHandler — exponential backoff, presets, retry logic.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class RetryHandlerTests: XCTestCase {

    // MARK: - Successful Execution

    func testExecuteSucceeds() async throws {
        let handler = RetryHandler(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        var callCount = 0

        let result = try await handler.execute {
            callCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Retry on Failure

    func testRetryOnTransientError() async throws {
        let handler = RetryHandler(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        var callCount = 0

        let result = try await handler.execute {
            callCount += 1
            if callCount < 3 {
                throw BackendError.backendSpecific("transient error")
            }
            return "recovered"
        }

        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(callCount, 3)
    }

    func testExhaustedRetries() async {
        let handler = RetryHandler(maxAttempts: 2, baseDelay: 0.01, maxDelay: 0.1)
        var callCount = 0

        do {
            _ = try await handler.execute {
                callCount += 1
                throw BackendError.backendSpecific("persistent error")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(callCount, 2)
        }
    }

    // MARK: - Non-Retryable Errors

    func testNonRetryableErrorSkipsRetry() async {
        let handler = RetryHandler(
            maxAttempts: 3,
            baseDelay: 0.01,
            maxDelay: 0.1,
            retryableErrors: { _ in false }
        )
        var callCount = 0

        do {
            _ = try await handler.execute {
                callCount += 1
                throw BackendError.invalidImageData
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(callCount, 1, "Should not retry non-retryable errors")
        }
    }

    func testCancellationErrorNeverRetried() async {
        let handler = RetryHandler(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        var callCount = 0

        do {
            _ = try await handler.execute {
                callCount += 1
                throw CancellationError()
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(callCount, 1, "CancellationError should never be retried")
            XCTAssertTrue(error is CancellationError)
        }
    }

    // MARK: - Preset Configurations

    func testHTTPBackendPreset() {
        let preset = RetryHandler.httpBackend
        XCTAssertEqual(preset.maxAttempts, 3)
        XCTAssertEqual(preset.baseDelay, 1.0)
        XCTAssertEqual(preset.maxDelay, 10.0)
    }

    func testHTTPBackendPresetRetryableErrors() {
        let preset = RetryHandler.httpBackend

        // Should retry connection errors
        XCTAssertTrue(preset.retryableErrors(URLError(.timedOut)))
        XCTAssertTrue(preset.retryableErrors(URLError(.cannotConnectToHost)))
        XCTAssertTrue(preset.retryableErrors(URLError(.networkConnectionLost)))
        XCTAssertTrue(preset.retryableErrors(URLError(.notConnectedToInternet)))
        XCTAssertTrue(preset.retryableErrors(URLError(.cannotFindHost)))

        // Should NOT retry non-connection URL errors
        XCTAssertFalse(preset.retryableErrors(URLError(.badURL)))
        XCTAssertFalse(preset.retryableErrors(URLError(.cancelled)))

        // Should retry backend-specific errors
        XCTAssertTrue(preset.retryableErrors(BackendError.notConnected))
        XCTAssertTrue(preset.retryableErrors(BackendError.backendSpecific("something")))

        // Should NOT retry other backend errors
        XCTAssertFalse(preset.retryableErrors(BackendError.invalidImageData))
        XCTAssertFalse(preset.retryableErrors(BackendError.cancelled))
    }

    func testPythonDaemonPreset() {
        let preset = RetryHandler.pythonDaemon
        XCTAssertEqual(preset.maxAttempts, 2)
        XCTAssertEqual(preset.baseDelay, 2.0)
        XCTAssertEqual(preset.maxDelay, 5.0)
    }

    func testPythonDaemonPresetRetryableErrors() {
        let preset = RetryHandler.pythonDaemon

        // Should retry daemon termination
        XCTAssertTrue(preset.retryableErrors(BackendError.backendSpecific("daemon terminated")))
        XCTAssertTrue(preset.retryableErrors(BackendError.backendSpecific("Process terminated unexpectedly")))

        // Should NOT retry unrelated errors
        XCTAssertFalse(preset.retryableErrors(BackendError.backendSpecific("invalid input")))
        XCTAssertFalse(preset.retryableErrors(BackendError.invalidImageData))
    }

    func testHealthCheckPreset() {
        let preset = RetryHandler.healthCheck
        XCTAssertEqual(preset.maxAttempts, 2)
        XCTAssertEqual(preset.baseDelay, 0.5)
        XCTAssertEqual(preset.maxDelay, 2.0)
    }

    func testHealthCheckPresetRetriesEverything() {
        let preset = RetryHandler.healthCheck
        XCTAssertTrue(preset.retryableErrors(BackendError.notConnected))
        XCTAssertTrue(preset.retryableErrors(BackendError.invalidImageData))
        XCTAssertTrue(preset.retryableErrors(URLError(.timedOut)))
    }

    // MARK: - Edge Cases

    func testSingleAttempt() async {
        let handler = RetryHandler(maxAttempts: 1, baseDelay: 0.01, maxDelay: 0.1)
        var callCount = 0

        do {
            _ = try await handler.execute {
                callCount += 1
                throw BackendError.backendSpecific("fail")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(callCount, 1)
        }
    }
}
