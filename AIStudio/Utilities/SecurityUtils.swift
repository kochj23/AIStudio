//
//  SecurityUtils.swift
//  AIStudio
//
//  Adapted from MLX Code. Created on 2025-11-18.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Utility class for input validation and sanitization
enum SecurityUtils {

    // MARK: - Input Validation

    static func validateFilePath(_ path: String) -> Bool {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let expandedPath = (path as NSString).expandingTildeInPath
        let resolvedPath = (expandedPath as NSString).resolvingSymlinksInPath
        let dangerousPatterns = ["../", "..\\", "%2e%2e/", "%2e%2e\\"]
        let lowercasedPath = resolvedPath.lowercased()
        for pattern in dangerousPatterns {
            if lowercasedPath.contains(pattern.lowercased()) { return false }
        }
        guard resolvedPath.utf8.count < 4096 else { return false }
        return true
    }

    static func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let safeProtocols = ["http", "https", "file"]
        guard let scheme = url.scheme?.lowercased(), safeProtocols.contains(scheme) else { return false }
        return true
    }

    static func validatePort(_ port: Int) -> Bool {
        return port >= 1 && port <= 65535
    }

    static func validateLength(_ string: String, min minLength: Int = 0, max maxLength: Int) -> Bool {
        let length = string.count
        return length >= minLength && length <= maxLength
    }

    // MARK: - Input Sanitization

    static func sanitizeFilePath(_ path: String) -> String {
        var sanitized = path
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined()
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "/")
        while sanitized.contains("//") {
            sanitized = sanitized.replacingOccurrences(of: "//", with: "/")
        }
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }

    static func sanitizeHTML(_ string: String) -> String {
        var sanitized = string
        let replacements: [String: String] = [
            "&": "&amp;", "<": "&lt;", ">": "&gt;",
            "\"": "&quot;", "'": "&#x27;", "/": "&#x2F;"
        ]
        for (char, entity) in replacements {
            sanitized = sanitized.replacingOccurrences(of: char, with: entity)
        }
        return sanitized
    }

    static func sanitizeUserInput(_ string: String) -> String {
        var sanitized = string
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        sanitized = sanitized.components(separatedBy: .controlCharacters).joined(separator: " ")
        sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }

    /// Sanitize a prompt for Stable Diffusion (preserve SD syntax like parentheses, brackets)
    static func sanitizePrompt(_ prompt: String) -> String {
        var sanitized = prompt
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        // Remove control characters but keep newlines for multi-line prompts
        sanitized = sanitized.filter { char in
            !char.isNewline || char == "\n" ? true : !char.unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) }
        }
        // Keep SD syntax: () for emphasis, [] for de-emphasis, : for weights
        // Only strip truly dangerous control characters
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func truncate(_ string: String, to maxLength: Int, suffix: String = "...") -> String {
        guard string.count > maxLength else { return string }
        let truncatedLength = maxLength - suffix.count
        guard truncatedLength > 0 else { return String(string.prefix(maxLength)) }
        return String(string.prefix(truncatedLength)) + suffix
    }

    // MARK: - Secure Random

    static func generateSecureRandomString(length: Int) -> String? {
        var bytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard result == errSecSuccess else { return nil }
        return Data(bytes).base64EncodedString()
    }
}
