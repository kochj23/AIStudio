//
//  RetryHandler.swift
//  AIStudio
//
//  Retry with exponential backoff for backend resilience.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Configurable retry handler with exponential backoff
struct RetryHandler {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let retryableErrors: (Error) -> Bool

    init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        retryableErrors: @escaping (Error) -> Bool = { _ in true }
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableErrors = retryableErrors
    }

    /// Execute an operation with automatic retry on failure
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry cancellation or non-retryable errors
                if error is CancellationError || !retryableErrors(error) {
                    throw error
                }

                // Don't sleep after the last attempt
                if attempt < maxAttempts - 1 {
                    let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                    let jitter = Double.random(in: 0...0.5)
                    try await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
                    logInfo("Retry attempt \(attempt + 2)/\(maxAttempts) after \(String(format: "%.1f", delay))s", category: "Retry")
                }
            }
        }

        throw lastError ?? BackendError.backendSpecific("All retry attempts failed")
    }

    // MARK: - Presets

    /// Standard retry for HTTP backend calls (retries on connection errors, not 4xx)
    static let httpBackend = RetryHandler(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        retryableErrors: { error in
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                     .notConnectedToInternet, .cannotFindHost:
                    return true
                default:
                    return false
                }
            }
            // Retry backend-specific errors that indicate transient issues
            if let backendError = error as? BackendError {
                switch backendError {
                case .notConnected, .backendSpecific:
                    return true
                default:
                    return false
                }
            }
            return false
        }
    )

    /// Aggressive retry for Python daemon operations
    static let pythonDaemon = RetryHandler(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 5.0,
        retryableErrors: { error in
            if let backendError = error as? BackendError {
                switch backendError {
                case .backendSpecific(let msg):
                    return msg.contains("terminated") || msg.contains("daemon")
                default:
                    return false
                }
            }
            return false
        }
    )

    /// Quick retry for health checks
    static let healthCheck = RetryHandler(
        maxAttempts: 2,
        baseDelay: 0.5,
        maxDelay: 2.0,
        retryableErrors: { _ in true }
    )
}
