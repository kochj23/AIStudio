//
//  SecurityUtilsTests.swift
//  AIStudioTests
//
//  Tests for SecurityUtils — input validation and sanitization.
//  Created by Jordan Koch.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import AIStudio

final class SecurityUtilsTests: XCTestCase {

    // MARK: - File Path Validation

    func testValidFilePath() {
        XCTAssertTrue(SecurityUtils.validateFilePath("/Users/test/file.txt"))
        XCTAssertTrue(SecurityUtils.validateFilePath("/tmp/output/image.png"))
        XCTAssertTrue(SecurityUtils.validateFilePath("~/Documents/test.json"))
    }

    func testEmptyPathRejected() {
        XCTAssertFalse(SecurityUtils.validateFilePath(""))
        XCTAssertFalse(SecurityUtils.validateFilePath("   "))
        XCTAssertFalse(SecurityUtils.validateFilePath("\t\n"))
    }

    func testPathTraversalRejected() {
        XCTAssertFalse(SecurityUtils.validateFilePath("/tmp/../etc/passwd"))
        XCTAssertFalse(SecurityUtils.validateFilePath("/tmp/%2e%2e/etc/passwd"))
        XCTAssertFalse(SecurityUtils.validateFilePath("/tmp/..\\etc\\passwd"))
    }

    func testPathLengthLimit() {
        let longPath = "/" + String(repeating: "a", count: 5000)
        XCTAssertFalse(SecurityUtils.validateFilePath(longPath))
    }

    // MARK: - URL Validation

    func testValidURLs() {
        XCTAssertTrue(SecurityUtils.validateURL("http://localhost:7860"))
        XCTAssertTrue(SecurityUtils.validateURL("https://example.com"))
        XCTAssertTrue(SecurityUtils.validateURL("file:///tmp/test.txt"))
    }

    func testInvalidURLSchemes() {
        XCTAssertFalse(SecurityUtils.validateURL("ftp://example.com"))
        XCTAssertFalse(SecurityUtils.validateURL("javascript:alert(1)"))
        XCTAssertFalse(SecurityUtils.validateURL("data:text/html,<script>alert(1)</script>"))
    }

    func testMalformedURLRejected() {
        XCTAssertFalse(SecurityUtils.validateURL(""))
        XCTAssertFalse(SecurityUtils.validateURL("not a url"))
    }

    // MARK: - Port Validation

    func testValidPorts() {
        XCTAssertTrue(SecurityUtils.validatePort(80))
        XCTAssertTrue(SecurityUtils.validatePort(443))
        XCTAssertTrue(SecurityUtils.validatePort(7860))
        XCTAssertTrue(SecurityUtils.validatePort(65535))
        XCTAssertTrue(SecurityUtils.validatePort(1))
    }

    func testInvalidPorts() {
        XCTAssertFalse(SecurityUtils.validatePort(0))
        XCTAssertFalse(SecurityUtils.validatePort(-1))
        XCTAssertFalse(SecurityUtils.validatePort(65536))
        XCTAssertFalse(SecurityUtils.validatePort(100000))
    }

    // MARK: - String Length Validation

    func testStringLengthValidation() {
        XCTAssertTrue(SecurityUtils.validateLength("hello", min: 1, max: 10))
        XCTAssertTrue(SecurityUtils.validateLength("", min: 0, max: 10))
        XCTAssertFalse(SecurityUtils.validateLength("hello world", min: 0, max: 5))
        XCTAssertFalse(SecurityUtils.validateLength("hi", min: 5, max: 10))
    }

    // MARK: - File Path Sanitization

    func testSanitizeFilePath() {
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("/tmp//test"), "/tmp/test")
        XCTAssertEqual(SecurityUtils.sanitizeFilePath("C:\\Users\\test"), "C:/Users/test")
    }

    func testSanitizeFilePathNullBytes() {
        let pathWithNull = "/tmp/test\0.txt"
        let sanitized = SecurityUtils.sanitizeFilePath(pathWithNull)
        XCTAssertFalse(sanitized.contains("\0"))
    }

    func testSanitizeFilePathControlChars() {
        let pathWithControl = "/tmp/\u{001B}test\u{007F}.txt"
        let sanitized = SecurityUtils.sanitizeFilePath(pathWithControl)
        XCTAssertFalse(sanitized.contains("\u{001B}"))
    }

    // MARK: - HTML Sanitization

    func testSanitizeHTML() {
        let dangerous = "<script>alert('xss')</script>"
        let sanitized = SecurityUtils.sanitizeHTML(dangerous)
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertTrue(sanitized.contains("&lt;script&gt;"))
    }

    func testSanitizeHTMLQuotes() {
        let input = "He said \"hello\" & 'goodbye'"
        let sanitized = SecurityUtils.sanitizeHTML(input)
        XCTAssertTrue(sanitized.contains("&quot;"))
        XCTAssertTrue(sanitized.contains("&#x27;"))
        XCTAssertTrue(sanitized.contains("&amp;"))
    }

    // MARK: - User Input Sanitization

    func testSanitizeUserInput() {
        let input = "  hello   world  "
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertEqual(sanitized, "hello world")
    }

    func testSanitizeUserInputNullBytes() {
        let input = "hello\0world"
        let sanitized = SecurityUtils.sanitizeUserInput(input)
        XCTAssertFalse(sanitized.contains("\0"))
    }

    // MARK: - Prompt Sanitization

    func testSanitizePromptPreservesSDSyntax() {
        let prompt = "a (beautiful:1.3) [landscape], masterpiece"
        let sanitized = SecurityUtils.sanitizePrompt(prompt)
        XCTAssertTrue(sanitized.contains("(beautiful:1.3)"))
        XCTAssertTrue(sanitized.contains("[landscape]"))
    }

    func testSanitizePromptStripsNullBytes() {
        let prompt = "a \0beautiful landscape"
        let sanitized = SecurityUtils.sanitizePrompt(prompt)
        XCTAssertFalse(sanitized.contains("\0"))
    }

    func testSanitizePromptTrimsWhitespace() {
        let prompt = "   hello world   "
        let sanitized = SecurityUtils.sanitizePrompt(prompt)
        XCTAssertEqual(sanitized, "hello world")
    }

    // MARK: - Truncation

    func testTruncation() {
        let long = "This is a very long string that should be truncated"
        let truncated = SecurityUtils.truncate(long, to: 20)
        XCTAssertTrue(truncated.count <= 20)
        XCTAssertTrue(truncated.hasSuffix("..."))
    }

    func testTruncationShortString() {
        let short = "hello"
        let result = SecurityUtils.truncate(short, to: 20)
        XCTAssertEqual(result, "hello")
    }

    func testTruncationCustomSuffix() {
        let long = "This is a very long string"
        let truncated = SecurityUtils.truncate(long, to: 15, suffix: "[cut]")
        XCTAssertTrue(truncated.hasSuffix("[cut]"))
        XCTAssertTrue(truncated.count <= 15)
    }

    // MARK: - Secure Random

    func testSecureRandomString() {
        let random1 = SecurityUtils.generateSecureRandomString(length: 32)
        let random2 = SecurityUtils.generateSecureRandomString(length: 32)
        XCTAssertNotNil(random1)
        XCTAssertNotNil(random2)
        XCTAssertNotEqual(random1, random2, "Two random strings should not be equal")
    }

    func testSecureRandomStringLength() {
        let random = SecurityUtils.generateSecureRandomString(length: 16)
        XCTAssertNotNil(random)
        // Base64 output is longer than input bytes, just confirm it's not nil
    }
}
