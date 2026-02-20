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
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backendManager)
                .environmentObject(settings)
                .onAppear {
                    Task {
                        await backendManager.refreshAllBackends()
                    }
                }
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(backendManager)
                .environmentObject(settings)
        }
    }
}
