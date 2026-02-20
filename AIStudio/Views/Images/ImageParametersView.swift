//
//  ImageParametersView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ImageParametersView: View {
    @Binding var steps: Int
    @Binding var cfgScale: Double
    @Binding var width: Int
    @Binding var height: Int
    @Binding var seed: Int
    @Binding var samplerName: String
    @Binding var batchSize: Int
    @Binding var selectedCheckpoint: String
    let availableModels: [A1111Model]
    let availableSamplers: [A1111Sampler]
    let onSwapDimensions: () -> Void
    let onRandomizeSeed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)

            // Model/Checkpoint
            if !availableModels.isEmpty {
                HStack {
                    Text("Model")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $selectedCheckpoint) {
                        ForEach(availableModels) { model in
                            Text(model.title).tag(model.modelName)
                        }
                    }
                    .labelsHidden()
                }
            }

            // Sampler
            if !availableSamplers.isEmpty {
                HStack {
                    Text("Sampler")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $samplerName) {
                        ForEach(availableSamplers) { sampler in
                            Text(sampler.name).tag(sampler.name)
                        }
                    }
                    .labelsHidden()
                }
            } else {
                HStack {
                    Text("Sampler")
                        .frame(width: 80, alignment: .leading)
                    TextField("Sampler", text: $samplerName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Steps
            HStack {
                Text("Steps")
                    .frame(width: 80, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(steps) },
                    set: { steps = Int($0) }
                ), in: 1...150, step: 1)
                Text("\(steps)")
                    .frame(width: 35, alignment: .trailing)
                    .monospacedDigit()
            }

            // CFG Scale
            HStack {
                Text("CFG")
                    .frame(width: 80, alignment: .leading)
                Slider(value: $cfgScale, in: 1...30, step: 0.5)
                Text(String(format: "%.1f", cfgScale))
                    .frame(width: 35, alignment: .trailing)
                    .monospacedDigit()
            }

            // Size
            HStack {
                Text("Size")
                    .frame(width: 80, alignment: .leading)
                Menu {
                    ForEach(ImageGenerationViewModel.standardSizes, id: \.0) { label, w, h in
                        Button(label) {
                            width = w
                            height = h
                        }
                    }
                } label: {
                    Text("\(width) x \(height)")
                        .monospacedDigit()
                }

                Button(action: onSwapDimensions) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Swap width and height")
            }

            // Seed
            HStack {
                Text("Seed")
                    .frame(width: 80, alignment: .leading)
                TextField("Random (-1)", value: $seed, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)

                Button(action: onRandomizeSeed) {
                    Image(systemName: "dice")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Random seed")
            }

            // Batch size
            HStack {
                Text("Batch")
                    .frame(width: 80, alignment: .leading)
                Stepper("\(batchSize)", value: $batchSize, in: 1...8)
            }
        }
    }
}
