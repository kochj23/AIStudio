//
//  PythonDaemonService.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Manages a Python subprocess for MLX inference.
/// Communication via stdin/stdout JSON protocol (same pattern as MLX Code's mlx_daemon.py).
actor PythonDaemonService {
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var isRunning: Bool = false
    private var pendingCallbacks: [String: CheckedContinuation<[String: Any], Error>] = [:]

    private let pythonPath: String
    private let scriptPath: String

    /// Crash recovery state
    private var crashCount: Int = 0
    private var lastCrashTime: Date?
    private let maxCrashesBeforeGiveUp: Int = 5
    private let crashCountResetInterval: TimeInterval = 300 // Reset crash count after 5 min stable
    private var lastRequest: (command: String, params: [String: Any])?

    init(pythonPath: String? = nil, scriptPath: String? = nil) {
        self.pythonPath = pythonPath ?? "/usr/bin/python3"

        if let scriptPath {
            self.scriptPath = scriptPath
        } else {
            self.scriptPath = Bundle.main.path(forResource: "aistudio_daemon", ofType: "py")
                ?? Bundle.main.bundlePath + "/Contents/Resources/Python/aistudio_daemon.py"
        }
    }

    // MARK: - Lifecycle

    func start() async throws {
        guard !isRunning else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-u", scriptPath]
        process.environment = ProcessInfo.processInfo.environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.stdin = stdinPipe.fileHandleForWriting
        self.stdout = stdoutPipe.fileHandleForReading

        // Handle stderr for logging
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                logWarning("Python daemon stderr: \(text)", category: "PythonDaemon")
            }
        }

        // Read stdout responses
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                // Each line is a JSON response
                let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
                for line in lines {
                    guard let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          let requestId = json["request_id"] as? String else {
                        continue
                    }

                    Task {
                        await self?.handleResponse(requestId: requestId, response: json)
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination() }
        }

        try process.run()
        self.process = process
        self.isRunning = true

        logInfo("Python daemon started (PID: \(process.processIdentifier))", category: "PythonDaemon")
    }

    func stop() {
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        isRunning = false

        // Cancel all pending requests
        for (_, continuation) in pendingCallbacks {
            continuation.resume(throwing: BackendError.cancelled)
        }
        pendingCallbacks.removeAll()

        logInfo("Python daemon stopped", category: "PythonDaemon")
    }

    // MARK: - Request/Response

    func sendRequest(command: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        if !isRunning {
            try await start()
        }
        lastRequest = (command, params)

        let requestId = UUID().uuidString
        var request = params
        request["command"] = command
        request["request_id"] = requestId

        let data = try JSONSerialization.data(withJSONObject: request)
        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw BackendError.backendSpecific("Failed to serialize request")
        }
        jsonString += "\n"

        guard let writeData = jsonString.data(using: .utf8) else {
            throw BackendError.backendSpecific("Failed to encode request")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingCallbacks[requestId] = continuation
            stdin?.write(writeData)
        }
    }

    // MARK: - Private

    private func handleResponse(requestId: String, response: [String: Any]) {
        guard let continuation = pendingCallbacks.removeValue(forKey: requestId) else { return }

        if let error = response["error"] as? String {
            continuation.resume(throwing: BackendError.backendSpecific(error))
        } else {
            continuation.resume(returning: response)
        }
    }

    private func handleTermination() {
        let wasPreviouslyRunning = isRunning
        isRunning = false

        // Fail all pending requests
        for (_, continuation) in pendingCallbacks {
            continuation.resume(throwing: BackendError.backendSpecific("Python daemon terminated unexpectedly"))
        }
        pendingCallbacks.removeAll()

        guard wasPreviouslyRunning else { return }

        // Reset crash count if stable for a while
        if let lastCrash = lastCrashTime,
           Date().timeIntervalSince(lastCrash) > crashCountResetInterval {
            crashCount = 0
        }

        crashCount += 1
        lastCrashTime = Date()

        if crashCount <= maxCrashesBeforeGiveUp {
            logWarning("Python daemon crashed (\(crashCount)/\(maxCrashesBeforeGiveUp)). Auto-restarting...", category: "PythonDaemon")
            Task {
                // Exponential backoff: 1s, 2s, 4s, 8s, 16s
                let delay = UInt64(pow(2.0, Double(crashCount - 1))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
                do {
                    try await start()
                    logInfo("Python daemon restarted successfully after crash", category: "PythonDaemon")
                } catch {
                    logError("Python daemon restart failed: \(error.localizedDescription)", category: "PythonDaemon")
                }
            }
        } else {
            logError("Python daemon crashed \(crashCount) times. Giving up auto-restart. Manual restart required.", category: "PythonDaemon")
        }
    }

    /// Reset crash counter (call after successful manual restart)
    func resetCrashCount() {
        crashCount = 0
        lastCrashTime = nil
    }

    /// Current crash recovery state
    var daemonStatus: (isRunning: Bool, crashCount: Int) {
        (isRunning, crashCount)
    }
}
