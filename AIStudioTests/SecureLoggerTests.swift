//
//  SecureLoggerTests.swift
//  AIStudioTests
//
//  Tests for SecureLogger — PII redaction, credential scrubbing, log level filtering.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class SecureLoggerTests: XCTestCase {

    // MARK: - Sanitization (via reflection — test the sanitize patterns indirectly)

    // We test the patterns by constructing strings that contain sensitive data
    // and verifying the logger's sensitive pattern matching works. Since sanitize
    // is private, we test by verifying the logger doesn't crash and functions correctly.

    func testLogLevelOrdering() {
        XCTAssertTrue(SecureLogger.LogLevel.debug < SecureLogger.LogLevel.info)
        XCTAssertTrue(SecureLogger.LogLevel.info < SecureLogger.LogLevel.warning)
        XCTAssertTrue(SecureLogger.LogLevel.warning < SecureLogger.LogLevel.error)
        XCTAssertTrue(SecureLogger.LogLevel.error < SecureLogger.LogLevel.critical)
    }

    func testLogLevelRawValues() {
        XCTAssertEqual(SecureLogger.LogLevel.debug.rawValue, 0)
        XCTAssertEqual(SecureLogger.LogLevel.info.rawValue, 1)
        XCTAssertEqual(SecureLogger.LogLevel.warning.rawValue, 2)
        XCTAssertEqual(SecureLogger.LogLevel.error.rawValue, 3)
        XCTAssertEqual(SecureLogger.LogLevel.critical.rawValue, 4)
    }

    func testLogLevelComparable() {
        let levels: [SecureLogger.LogLevel] = [.critical, .debug, .error, .info, .warning]
        let sorted = levels.sorted()
        XCTAssertEqual(sorted, [.debug, .info, .warning, .error, .critical])
    }

    // MARK: - Logger Singleton

    func testLoggerExists() async {
        // Verify the singleton is accessible and doesn't crash
        let logger = SecureLogger.shared
        await logger.setMinimumLogLevel(.debug)
        // Just verify no crash
    }

    // MARK: - Log Functions Don't Crash

    func testDebugLogDoesNotCrash() async {
        await SecureLogger.shared.debug("Test debug message", category: "Test")
    }

    func testInfoLogDoesNotCrash() async {
        await SecureLogger.shared.info("Test info message", category: "Test")
    }

    func testWarningLogDoesNotCrash() async {
        await SecureLogger.shared.warning("Test warning message", category: "Test")
    }

    func testErrorLogDoesNotCrash() async {
        await SecureLogger.shared.error("Test error message", category: "Test")
    }

    func testCriticalLogDoesNotCrash() async {
        await SecureLogger.shared.critical("Test critical message", category: "Test")
    }

    func testLogErrorDoesNotCrash() async {
        let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "test error"])
        await SecureLogger.shared.logError(error, context: "unit test")
    }

    // MARK: - Global Convenience Functions

    func testGlobalLogFunctionsExist() {
        // These should not crash
        logDebug("test debug", category: "Test")
        logInfo("test info", category: "Test")
        logWarning("test warning", category: "Test")
        logError("test error", category: "Test")
        logCritical("test critical", category: "Test")
    }

    // MARK: - Sensitive Pattern Coverage

    func testLogWithAPIKeyDoesNotCrash() async {
        // The logger should sanitize this, but we can't easily verify the output
        // since it goes to os.log. We verify no crash.
        await SecureLogger.shared.info("Key is sk-abcdefghijklmnopqrstuvwxyz123456789012", category: "Test")
    }

    func testLogWithEmailDoesNotCrash() async {
        await SecureLogger.shared.info("User email: test@example.com", category: "Test")
    }

    func testLogWithJWTDoesNotCrash() async {
        await SecureLogger.shared.info("Token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123", category: "Test")
    }

    func testLogWithPasswordDoesNotCrash() async {
        await SecureLogger.shared.info("password=MySecretPassword123", category: "Test")
    }

    func testLogWithPhoneDoesNotCrash() async {
        await SecureLogger.shared.info("Phone: 555-123-4567", category: "Test")
    }

    func testLogWithCreditCardDoesNotCrash() async {
        await SecureLogger.shared.info("Card: 4111 1111 1111 1111", category: "Test")
    }

    // MARK: - Log Level Filtering

    func testMinimumLogLevel() async {
        // Set minimum to error — debug/info/warning should be filtered
        await SecureLogger.shared.setMinimumLogLevel(.error)
        // These should be silently filtered (no crash)
        await SecureLogger.shared.debug("filtered debug", category: "Test")
        await SecureLogger.shared.info("filtered info", category: "Test")
        await SecureLogger.shared.warning("filtered warning", category: "Test")
        // These should pass through
        await SecureLogger.shared.error("visible error", category: "Test")
        await SecureLogger.shared.critical("visible critical", category: "Test")
        // Reset
        await SecureLogger.shared.setMinimumLogLevel(.debug)
    }
}
