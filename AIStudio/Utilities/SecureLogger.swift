//
//  SecureLogger.swift
//  AIStudio
//
//  Adapted from MLX Code. Created on 2025-11-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import os.log

/// Secure logging utility that sanitizes sensitive information before logging
/// Prevents accidental exposure of API keys, passwords, tokens, and PII
actor SecureLogger {
    static let shared = SecureLogger()

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.jkoch.aistudio"

    enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    private var minimumLogLevel: LogLevel = .debug

    private let sensitivePatterns: [(pattern: String, replacement: String)] = [
        ("sk-[a-zA-Z0-9]{32,}", "[API_KEY_REDACTED]"),
        ("pk-[a-zA-Z0-9]{32,}", "[PUBLIC_KEY_REDACTED]"),
        ("['\"]?token['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "token=[TOKEN_REDACTED]"),
        ("['\"]?secret['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "secret=[SECRET_REDACTED]"),
        ("['\"]?api_key['\"]?\\s*[:=]\\s*['\"]?[a-zA-Z0-9_-]{20,}", "api_key=[KEY_REDACTED]"),
        ("['\"]?password['\"]?\\s*[:=]\\s*['\"]?[^'\"\\s]{6,}", "password=[PASSWORD_REDACTED]"),
        ("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "[EMAIL_REDACTED]"),
        ("\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b", "[PHONE_REDACTED]"),
        ("\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b", "[CARD_REDACTED]"),
        ("eyJ[a-zA-Z0-9_-]*\\.eyJ[a-zA-Z0-9_-]*\\.[a-zA-Z0-9_-]*", "[JWT_REDACTED]"),
        ("-----BEGIN\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----[\\s\\S]*?-----END\\s+(?:RSA\\s+)?PRIVATE\\s+KEY-----", "[PRIVATE_KEY_REDACTED]")
    ]

    private let maxLogLength = 1000

    private init() {}

    func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }

    func logError(_ error: Error, context: String? = nil, category: String = "Error", file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Error: \(type(of: error))"
        if let context { message += " - Context: \(context)" }
        message += " - \(error.localizedDescription)"
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    private func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int) {
        guard level >= minimumLogLevel else { return }
        let sanitized = sanitize(message)
        let logger = Logger(subsystem: subsystem, category: category)
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(sanitized)"
        logger.log(level: level.osLogType, "\(formattedMessage)")
    }

    private func sanitize(_ message: String) -> String {
        var sanitized = message
        for (pattern, replacement) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(sanitized.startIndex..., in: sanitized)
                sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: replacement)
            }
        }
        if sanitized.count > maxLogLength {
            sanitized = String(sanitized.prefix(maxLogLength)) + "... [TRUNCATED]"
        }
        return sanitized
    }
}

// MARK: - Global Convenience Functions

func logDebug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    Task { await SecureLogger.shared.debug(message, category: category, file: file, function: function, line: line) }
}

func logInfo(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    Task { await SecureLogger.shared.info(message, category: category, file: file, function: function, line: line) }
}

func logWarning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    Task { await SecureLogger.shared.warning(message, category: category, file: file, function: function, line: line) }
}

func logError(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    Task { await SecureLogger.shared.error(message, category: category, file: file, function: function, line: line) }
}

func logCritical(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
    Task { await SecureLogger.shared.critical(message, category: category, file: file, function: function, line: line) }
}
