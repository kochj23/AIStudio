//
//  AIStudioApp.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct AIStudioApp: App {
    @StateObject private var backendManager = BackendManager()
    @StateObject private var llmBackendManager = LLMBackendManager()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var generationQueue = GenerationQueue()
    @StateObject private var promptHistory = PromptHistory.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backendManager)
                .environmentObject(llmBackendManager)
                .environmentObject(settings)
                .environmentObject(generationQueue)
                .environmentObject(promptHistory)
                .onAppear {
                    generationQueue.configure(with: backendManager)
                    Task {
                        await backendManager.refreshAllBackends()
                        await llmBackendManager.refreshAllBackends()
                    }
                }
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Tab navigation shortcuts
            CommandMenu("Navigate") {
                Button("Images Tab") {
                    NotificationCenter.default.post(name: .switchTab, object: ContentView.StudioTab.images)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Videos Tab") {
                    NotificationCenter.default.post(name: .switchTab, object: ContentView.StudioTab.videos)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Audio Tab") {
                    NotificationCenter.default.post(name: .switchTab, object: ContentView.StudioTab.audio)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Chat Tab") {
                    NotificationCenter.default.post(name: .switchTab, object: ContentView.StudioTab.chat)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Gallery Tab") {
                    NotificationCenter.default.post(name: .switchTab, object: ContentView.StudioTab.gallery)
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            // Generation shortcuts
            CommandMenu("Generation") {
                Button("Generate") {
                    NotificationCenter.default.post(name: .triggerGenerate, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Cancel Generation") {
                    NotificationCenter.default.post(name: .triggerCancel, object: nil)
                }
                .keyboardShortcut(.escape)

                Divider()

                Button("Randomize Seed") {
                    NotificationCenter.default.post(name: .randomizeSeed, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Swap Dimensions") {
                    NotificationCenter.default.post(name: .swapDimensions, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Add to Queue") {
                    NotificationCenter.default.post(name: .addToQueue, object: nil)
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            }

            // Image shortcuts
            CommandMenu("Image") {
                Button("Save Image") {
                    NotificationCenter.default.post(name: .saveImage, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Copy to Clipboard") {
                    NotificationCenter.default.post(name: .copyImage, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(backendManager)
                .environmentObject(llmBackendManager)
                .environmentObject(settings)
        }
    }
}

// MARK: - Notification Names for Keyboard Shortcuts

extension Notification.Name {
    static let switchTab = Notification.Name("AIStudio.switchTab")
    static let triggerGenerate = Notification.Name("AIStudio.triggerGenerate")
    static let triggerCancel = Notification.Name("AIStudio.triggerCancel")
    static let randomizeSeed = Notification.Name("AIStudio.randomizeSeed")
    static let swapDimensions = Notification.Name("AIStudio.swapDimensions")
    static let addToQueue = Notification.Name("AIStudio.addToQueue")
    static let saveImage = Notification.Name("AIStudio.saveImage")
    static let copyImage = Notification.Name("AIStudio.copyImage")
}
