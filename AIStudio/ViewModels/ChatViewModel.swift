//
//  ChatViewModel.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Conversation

    @Published var conversation: ChatConversation = ChatConversation()
    @Published var inputText: String = ""
    @Published var systemPrompt: String = "You are a helpful creative assistant for an AI media studio. Help with prompt refinement, image descriptions, and creative direction."

    // MARK: - Parameters

    @Published var temperature: Float = 0.7
    @Published var maxTokens: Int = 2048

    // MARK: - State

    @Published var isGenerating: Bool = false
    @Published var streamingResponse: String = ""
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""

    private weak var llmManager: LLMBackendManager?
    private var generationTask: Task<Void, Never>?

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func configure(with llmManager: LLMBackendManager) {
        self.llmManager = llmManager
        let settings = AppSettings.shared
        temperature = settings.chatTemperature
        maxTokens = settings.chatMaxTokens
        if !settings.defaultSystemPrompt.isEmpty {
            systemPrompt = settings.defaultSystemPrompt
        }
    }

    // MARK: - Send Message

    func sendMessage() {
        guard canSend, let llmManager else { return }

        let sanitizedInput = SecurityUtils.sanitizePrompt(inputText)
        let userMessage = ChatMessage(role: .user, content: sanitizedInput)
        conversation.addMessage(userMessage)
        let sentPrompt = inputText
        inputText = ""
        isGenerating = true
        streamingResponse = ""
        errorMessage = nil
        statusMessage = "Generating..."

        generationTask = Task {
            do {
                let stream = llmManager.generateStream(
                    prompt: sanitizedInput,
                    systemPrompt: systemPrompt,
                    messages: conversation.messages,
                    temperature: temperature,
                    maxTokens: maxTokens
                )

                for try await chunk in stream {
                    streamingResponse += chunk
                }

                let assistantMessage = ChatMessage(role: .assistant, content: streamingResponse)
                conversation.addMessage(assistantMessage)
                streamingResponse = ""
                statusMessage = "Done"

                logInfo("Chat response received", category: "Chat")
            } catch is CancellationError {
                statusMessage = "Cancelled"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
                logError("Chat generation failed: \(error.localizedDescription)", category: "Chat")
            }

            isGenerating = false
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil

        // Preserve any partial streaming response as an assistant message
        if !streamingResponse.isEmpty {
            let partial = ChatMessage(role: .assistant, content: streamingResponse + "\n\n[Cancelled]")
            conversation.addMessage(partial)
            streamingResponse = ""
        }

        isGenerating = false
        statusMessage = "Cancelled"
    }

    func newConversation() {
        conversation = ChatConversation()
        errorMessage = nil
        statusMessage = ""
    }

    func clearConversation() {
        conversation.messages.removeAll()
        conversation.updatedAt = Date()
        errorMessage = nil
        statusMessage = ""
    }

    // MARK: - Prompt Templates

    struct PromptTemplate: Identifiable {
        let id = UUID()
        let name: String
        let prompt: String
        let icon: String
    }

    static let promptTemplates: [PromptTemplate] = [
        PromptTemplate(name: "Improve Prompt", prompt: "Improve this Stable Diffusion image generation prompt. Make it more detailed and effective:\n\n", icon: "wand.and.stars"),
        PromptTemplate(name: "Negative Prompt", prompt: "Generate a comprehensive negative prompt for Stable Diffusion to avoid common artifacts:\n\n", icon: "minus.circle"),
        PromptTemplate(name: "Describe Image", prompt: "Describe an image in rich detail suitable for use as an AI image generation prompt:\n\n", icon: "text.below.photo"),
        PromptTemplate(name: "Style Transfer", prompt: "Rewrite this image prompt in a specific artistic style (e.g., oil painting, cyberpunk, watercolor):\n\n", icon: "paintpalette"),
    ]

    func applyTemplate(_ template: PromptTemplate) {
        inputText = template.prompt
    }
}
