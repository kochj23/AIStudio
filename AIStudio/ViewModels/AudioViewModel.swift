//
//  AudioViewModel.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioViewModel: ObservableObject {
    // MARK: - TTS
    @Published var ttsText: String = ""
    @Published var ttsEngine: String = "kokoro"
    @Published var ttsVoice: String = "default"
    @Published var ttsSpeed: Double = 1.0
    @Published var availableEngines: [String] = ["kokoro", "csm", "chatterbox", "dia", "spark", "breeze", "mars5"]
    @Published var availableVoices: [String] = []

    // MARK: - Voice Cloning
    @Published var cloneText: String = ""
    @Published var referenceAudioPath: String = ""
    @Published var cloneSpeed: Double = 1.0

    // MARK: - Music Generation
    @Published var musicPrompt: String = ""
    @Published var musicDuration: Double = 10.0
    @Published var musicModelSize: String = "small"

    // MARK: - Speech to Text
    @Published var sttAudioPath: String = ""
    @Published var sttModel: String = "base"
    @Published var sttLanguage: String = ""
    @Published var transcriptionText: String = ""
    @Published var transcriptionSegments: [TranscriptionSegment] = []

    // MARK: - State
    @Published var isGenerating: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var generatedAudioData: Data?
    @Published var generatedAudioPath: String?

    // MARK: - Audio Player
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0.0
    @Published var playbackDuration: Double = 0.0
    private var playbackTimer: Timer?

    private var audioService: MLXAudioService?
    private var generationTask: Task<Void, Never>?

    func configure(daemon: PythonDaemonService) {
        self.audioService = MLXAudioService(daemon: daemon)
    }

    // MARK: - TTS

    func generateSpeech() {
        guard !ttsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let audioService else {
            errorMessage = "Audio service not configured. Check Python daemon settings."
            return
        }

        let request = TTSRequest(text: ttsText, voice: ttsVoice, speed: ttsSpeed, engine: ttsEngine)

        isGenerating = true
        errorMessage = nil
        statusMessage = "Generating speech..."

        generationTask = Task {
            do {
                let result = try await audioService.textToSpeech(request)
                generatedAudioData = result.audioData
                statusMessage = "Done in \(result.formattedTime) | Duration: \(result.formattedDuration)"

                if AppSettings.shared.autoSaveImages {
                    let path = try MediaExportService.saveAudio(result.audioData, type: "tts", label: ttsEngine)
                    generatedAudioPath = path
                }
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
            }
            isGenerating = false
        }
    }

    // MARK: - Voice Cloning

    func cloneVoice() {
        guard !cloneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !referenceAudioPath.isEmpty else { return }
        guard let audioService else {
            errorMessage = "Audio service not configured."
            return
        }

        let request = VoiceCloneRequest(text: cloneText, referenceAudioPath: referenceAudioPath, speed: cloneSpeed)

        isGenerating = true
        errorMessage = nil
        statusMessage = "Cloning voice..."

        generationTask = Task {
            do {
                let result = try await audioService.cloneVoice(request)
                generatedAudioData = result.audioData
                statusMessage = "Done in \(result.formattedTime) | Duration: \(result.formattedDuration)"

                if AppSettings.shared.autoSaveImages {
                    let path = try MediaExportService.saveAudio(result.audioData, type: "clone", label: "f5tts")
                    generatedAudioPath = path
                }
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
            }
            isGenerating = false
        }
    }

    // MARK: - Music Generation

    func generateMusic() {
        guard !musicPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let audioService else {
            errorMessage = "Audio service not configured."
            return
        }

        let request = MusicGenRequest(prompt: musicPrompt, duration: musicDuration, modelSize: musicModelSize)

        isGenerating = true
        errorMessage = nil
        statusMessage = "Generating music..."

        generationTask = Task {
            do {
                let result = try await audioService.generateMusic(request)
                generatedAudioData = result.audioData
                statusMessage = "Done in \(result.formattedTime) | Duration: \(result.formattedDuration)"

                if AppSettings.shared.autoSaveImages {
                    let path = try MediaExportService.saveAudio(result.audioData, type: "music", label: musicPrompt)
                    generatedAudioPath = path
                }
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
            }
            isGenerating = false
        }
    }

    // MARK: - Speech to Text

    func transcribe() {
        guard !sttAudioPath.isEmpty else { return }
        guard let audioService else {
            errorMessage = "Audio service not configured."
            return
        }

        let request = TranscriptionRequest(
            audioFilePath: sttAudioPath,
            model: sttModel,
            language: sttLanguage.isEmpty ? nil : sttLanguage
        )

        isGenerating = true
        errorMessage = nil
        statusMessage = "Transcribing..."

        generationTask = Task {
            do {
                let result = try await audioService.transcribe(request)
                transcriptionText = result.text
                transcriptionSegments = result.segments
                statusMessage = "Transcribed in \(result.formattedTime) | Language: \(result.language)"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Failed"
            }
            isGenerating = false
        }
    }

    // MARK: - Cancel

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        statusMessage = "Cancelled"
    }

    // MARK: - Playback

    func playGeneratedAudio() {
        guard let data = generatedAudioData else { return }

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            playbackDuration = audioPlayer?.duration ?? 0

            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let player = self.audioPlayer else { return }
                    self.playbackProgress = player.currentTime / max(player.duration, 0.01)
                    if !player.isPlaying {
                        self.isPlaying = false
                        self.playbackTimer?.invalidate()
                    }
                }
            }
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
    }

    func loadVoices() {
        guard let audioService else { return }
        Task {
            do {
                let voices = try await audioService.listVoices(engine: ttsEngine)
                self.availableVoices = voices
                if !voices.contains(ttsVoice) {
                    ttsVoice = voices.first ?? "default"
                }
            } catch {
                logWarning("Failed to load voices: \(error)", category: "Audio")
            }
        }
    }
}
