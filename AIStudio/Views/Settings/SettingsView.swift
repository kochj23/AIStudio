//
//  SettingsView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var backendManager: BackendManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            BackendSettingsView()
                .tabItem {
                    Label("Backends", systemImage: "server.rack")
                }

            outputSettings
                .tabItem {
                    Label("Output", systemImage: "folder")
                }

            pythonSettings
                .tabItem {
                    Label("Python", systemImage: "terminal")
                }

            defaultsSettings
                .tabItem {
                    Label("Defaults", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 520, height: 400)
    }

    // MARK: - Output Settings

    private var outputSettings: some View {
        Form {
            Section("Output Directory") {
                HStack {
                    TextField("Path", text: $settings.outputDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.outputDirectory = url.path
                        }
                    }
                }

                Text("Images saved to: {output}/{date}/images/")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Auto-Save") {
                Toggle("Automatically save generated images", isOn: $settings.autoSaveImages)
            }
        }
        .padding()
    }

    // MARK: - Python Settings

    private var pythonSettings: some View {
        Form {
            Section("Python Executable") {
                HStack {
                    TextField("Path", text: $settings.pythonPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.pythonPath = url.path
                        }
                    }
                }

                Text("Used for MLX native inference (Phase 2)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Generation Defaults

    private var defaultsSettings: some View {
        Form {
            Section("Default Generation Parameters") {
                HStack {
                    Text("Steps")
                    Spacer()
                    TextField("Steps", value: $settings.defaultSteps, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("CFG Scale")
                    Spacer()
                    TextField("CFG", value: $settings.defaultCFGScale, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Width")
                    Spacer()
                    TextField("Width", value: $settings.defaultWidth, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("Height", value: $settings.defaultHeight, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Sampler")
                    Spacer()
                    TextField("Sampler", text: $settings.defaultSampler)
                        .frame(width: 160)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .padding()
    }
}
