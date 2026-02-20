//
//  ChatView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Main chat tab view with HSplitView: controls left, conversation right.
struct ChatView: View {
    @EnvironmentObject var llmManager: LLMBackendManager
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        HSplitView {
            // MARK: - Left Panel: Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LLMBackendStatusMenu()

                    Divider()

                    // System Prompt
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt")
                            .font(.headline)
                        TextEditor(text: $viewModel.systemPrompt)
                            .font(.system(size: 12))
                            .frame(minHeight: 80, maxHeight: 120)
                            .border(Color.secondary.opacity(0.3), width: 1)
                    }

                    Divider()

                    // Parameters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parameters")
                            .font(.headline)

                        HStack {
                            Text("Temperature")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f", viewModel.temperature))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.temperature, in: 0.0...2.0, step: 0.1)

                        HStack {
                            Text("Max Tokens")
                                .font(.caption)
                            Spacer()
                            TextField("", value: $viewModel.maxTokens, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                    }

                    Divider()

                    // Prompt Templates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Templates")
                            .font(.headline)

                        ForEach(ChatViewModel.promptTemplates) { template in
                            Button(action: { viewModel.applyTemplate(template) }) {
                                HStack {
                                    Image(systemName: template.icon)
                                        .frame(width: 16)
                                    Text(template.name)
                                        .font(.caption)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }

                    Divider()

                    // Conversation Actions
                    VStack(spacing: 8) {
                        Button(action: { viewModel.newConversation() }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("New Conversation")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)

                        Button(action: { viewModel.clearConversation() }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Messages")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .disabled(viewModel.conversation.messages.isEmpty)
                    }
                }
                .padding()
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

            // MARK: - Right Panel: Chat
            VStack(spacing: 0) {
                // Messages Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.conversation.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }

                            // Streaming response
                            if viewModel.isGenerating && !viewModel.streamingResponse.isEmpty {
                                ChatMessageView(
                                    message: ChatMessage(role: .assistant, content: viewModel.streamingResponse),
                                    isStreaming: true
                                )
                                .id("streaming")
                            }

                            // Generating indicator with no content yet
                            if viewModel.isGenerating && viewModel.streamingResponse.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                                .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.conversation.messages.count) { _ in
                        if let lastId = viewModel.conversation.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.streamingResponse) { _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }

                // Empty state
                if viewModel.conversation.messages.isEmpty && !viewModel.isGenerating {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Start a conversation")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Use the templates on the left, or type your own message below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Dismiss") { viewModel.errorMessage = nil }
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                }

                // Input Area
                HStack(spacing: 8) {
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .frame(minHeight: 40, maxHeight: 100)
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .onSubmit {
                            if viewModel.canSend {
                                viewModel.sendMessage()
                            }
                        }

                    VStack(spacing: 4) {
                        if viewModel.isGenerating {
                            Button(action: { viewModel.cancelGeneration() }) {
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel generation")
                        } else {
                            Button(action: { viewModel.sendMessage() }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.title2)
                                    .foregroundColor(viewModel.canSend ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSend)
                            .help("Send message")
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 400)
        }
        .onAppear {
            viewModel.configure(with: llmManager)
        }
    }
}
