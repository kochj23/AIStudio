//
//  ImageComparisonView.swift
//  AIStudio
//
//  Side-by-side and overlay comparison for generated images.
//  Created on 2026-02-20.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import AppKit

// MARK: - Comparison Mode

enum ComparisonMode: String, CaseIterable {
    case sideBySide = "Side by Side"
    case sliderOverlay = "Slider Overlay"

    var icon: String {
        switch self {
        case .sideBySide: return "rectangle.split.2x1"
        case .sliderOverlay: return "slider.horizontal.below.rectangle"
        }
    }
}

// MARK: - ImageComparisonView

struct ImageComparisonView: View {
    let leftImage: GeneratedImage
    let rightImage: GeneratedImage
    let leftMetadata: GenerationMetadata?
    let rightMetadata: GenerationMetadata?

    @State private var comparisonMode: ComparisonMode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5
    @State private var zoomScale: CGFloat = 1.0
    @State private var showLeftMetadata: Bool = false
    @State private var showRightMetadata: Bool = false

    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 10.0
    private let zoomStep: CGFloat = 0.25

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            comparisonContent
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Mode toggle
            modeToggle

            Divider()
                .frame(height: 20)

            // Zoom controls
            zoomControls

            Spacer()

            // Metadata toggles
            metadataToggles
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(ComparisonMode.allCases, id: \.self) { mode in
                Button(action: { comparisonMode = mode }) {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .tint(comparisonMode == mode ? .accentColor : .secondary)
                .controlSize(.small)
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")
            .disabled(zoomScale <= minZoom)

            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .center)

            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
            .disabled(zoomScale >= maxZoom)

            Divider()
                .frame(height: 16)

            Button("Fit") {
                zoomToFit()
            }
            .font(.caption)
            .help("Zoom to Fit")

            Button("1:1") {
                zoomToActual()
            }
            .font(.caption)
            .help("Actual Size")
        }
        .controlSize(.small)
    }

    private var metadataToggles: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $showLeftMetadata) {
                Text("Left Info")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Show metadata for left image")

            Toggle(isOn: $showRightMetadata) {
                Text("Right Info")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Show metadata for right image")
        }
    }

    // MARK: - Comparison Content

    @ViewBuilder
    private var comparisonContent: some View {
        switch comparisonMode {
        case .sideBySide:
            sideBySideView
        case .sliderOverlay:
            sliderOverlayView
        }
    }

    // MARK: - Side by Side

    private var sideBySideView: some View {
        HSplitView {
            imagePanel(image: leftImage, metadata: leftMetadata, showMetadata: showLeftMetadata, label: "Left")
            imagePanel(image: rightImage, metadata: rightMetadata, showMetadata: showRightMetadata, label: "Right")
        }
    }

    private func imagePanel(image: GeneratedImage, metadata: GenerationMetadata?, showMetadata: Bool, label: String) -> some View {
        VStack(spacing: 0) {
            // Label
            HStack {
                Text("Image \(image.index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Image
            ZStack {
                Color(nsColor: .controlBackgroundColor)

                if let nsImage = image.nsImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomScale)
                            .frame(
                                width: nsImage.size.width * zoomScale,
                                height: nsImage.size.height * zoomScale
                            )
                    }
                } else {
                    Text("Unable to load image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Metadata panel
            if showMetadata, let metadata {
                Divider()
                metadataPanel(metadata: metadata)
            }
        }
    }

    // MARK: - Slider Overlay

    private var sliderOverlayView: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .controlBackgroundColor)

                if let leftNS = leftImage.nsImage, let rightNS = rightImage.nsImage {
                    let dividerX = geometry.size.width * sliderPosition

                    // Right image (full, behind)
                    Image(nsImage: rightNS)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Left image (clipped to left of divider)
                    Image(nsImage: leftNS)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(
                            HorizontalClipShape(splitX: dividerX)
                        )

                    // Divider line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: geometry.size.height)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                        .position(x: dividerX, y: geometry.size.height / 2)

                    // Drag handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        )
                        .position(x: dividerX, y: geometry.size.height / 2)

                    // Labels
                    overlayLabels(geometry: geometry, dividerX: dividerX)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPosition = value.location.x / geometry.size.width
                        sliderPosition = min(max(newPosition, 0.0), 1.0)
                    }
            )
            .overlay(alignment: .bottom) {
                overlayMetadata
            }
        }
    }

    private func overlayLabels(geometry: GeometryProxy, dividerX: CGFloat) -> some View {
        ZStack {
            // Left label
            if dividerX > 60 {
                Text("Image \(leftImage.index + 1)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: dividerX / 2, y: 20)
            }

            // Right label
            if geometry.size.width - dividerX > 60 {
                Text("Image \(rightImage.index + 1)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: dividerX + (geometry.size.width - dividerX) / 2, y: 20)
            }
        }
    }

    @ViewBuilder
    private var overlayMetadata: some View {
        if showLeftMetadata || showRightMetadata {
            HStack(alignment: .top, spacing: 12) {
                if showLeftMetadata, let leftMetadata {
                    metadataCard(metadata: leftMetadata, label: "Left")
                }
                if showRightMetadata, let rightMetadata {
                    metadataCard(metadata: rightMetadata, label: "Right")
                }
            }
            .padding(8)
        }
    }

    // MARK: - Metadata Views

    private func metadataPanel(metadata: GenerationMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataRow("Prompt", metadata.prompt, lineLimit: 2)
            if !metadata.negativePrompt.isEmpty {
                metadataRow("Negative", metadata.negativePrompt, lineLimit: 1)
            }
            HStack(spacing: 12) {
                metadataTag("Steps", "\(metadata.steps)")
                metadataTag("CFG", String(format: "%.1f", metadata.cfgScale))
                metadataTag("Size", "\(metadata.width)x\(metadata.height)")
                metadataTag("Seed", metadata.seedDisplay)
                metadataTag("Sampler", metadata.samplerName)
            }
            HStack(spacing: 12) {
                metadataTag("Backend", metadata.backendName)
                metadataTag("Time", metadata.formattedTime)
            }
        }
        .padding(8)
        .font(.caption2)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func metadataCard(metadata: GenerationMetadata, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            metadataRow("Prompt", metadata.prompt, lineLimit: 1)
            HStack(spacing: 8) {
                metadataTag("Steps", "\(metadata.steps)")
                metadataTag("CFG", String(format: "%.1f", metadata.cfgScale))
                metadataTag("Seed", metadata.seedDisplay)
                metadataTag("Time", metadata.formattedTime)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private func metadataRow(_ label: String, _ value: String, lineLimit: Int = 1) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            Text(value)
                .lineLimit(lineLimit)
                .textSelection(.enabled)
        }
        .font(.caption2)
    }

    private func metadataTag(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption2)
    }

    // MARK: - Zoom Actions

    private func zoomIn() {
        let newScale = min(zoomScale + zoomStep, maxZoom)
        withAnimation(.easeInOut(duration: 0.15)) {
            zoomScale = newScale
        }
    }

    private func zoomOut() {
        let newScale = max(zoomScale - zoomStep, minZoom)
        withAnimation(.easeInOut(duration: 0.15)) {
            zoomScale = newScale
        }
    }

    private func zoomToFit() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = 1.0
        }
    }

    private func zoomToActual() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // Calculate scale for 1:1 pixel mapping based on the left image
            if let nsImage = leftImage.nsImage {
                let pixelWidth = nsImage.representations.first?.pixelsWide ?? Int(nsImage.size.width)
                if nsImage.size.width > 0 {
                    zoomScale = CGFloat(pixelWidth) / nsImage.size.width
                } else {
                    zoomScale = 1.0
                }
            } else {
                zoomScale = 1.0
            }
        }
    }
}

// MARK: - Horizontal Clip Shape

/// Clips content to the left side of a vertical divider at `splitX`.
struct HorizontalClipShape: Shape {
    var splitX: CGFloat

    var animatableData: CGFloat {
        get { splitX }
        set { splitX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: splitX, height: rect.height))
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct ImageComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview requires valid GeneratedImage instances
        Text("ImageComparisonView requires GeneratedImage data")
            .frame(width: 800, height: 600)
    }
}
#endif
