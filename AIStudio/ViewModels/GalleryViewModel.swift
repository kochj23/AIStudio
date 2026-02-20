//
//  GalleryViewModel.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var filteredItems: [MediaItem] = []
    @Published var selectedItem: MediaItem?
    @Published var filterType: MediaType?
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var sortOrder: SortOrder = .newest

    private let galleryService = GalleryService()

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case nameAsc = "Name A-Z"
        case nameDesc = "Name Z-A"
    }

    func loadGallery() {
        isLoading = true
        Task {
            let scanned = await galleryService.scanOutputDirectory()
            let withThumbs = await galleryService.generateThumbnails(for: scanned)
            items = withThumbs
            applyFilters()
            isLoading = false
        }
    }

    func applyFilters() {
        var result = items

        // Filter by type
        if let filterType {
            result = result.filter { $0.type == filterType }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                item.fileName.lowercased().contains(query) ||
                item.metadata.values.contains { $0.lowercased().contains(query) }
            }
        }

        // Sort
        switch sortOrder {
        case .newest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .nameAsc:
            result.sort { $0.fileName < $1.fileName }
        case .nameDesc:
            result.sort { $0.fileName > $1.fileName }
        }

        filteredItems = result
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        Task {
            do {
                try await galleryService.deleteItem(item)
                items.removeAll { $0.id == item.id }
                selectedItem = nil
                applyFilters()
            } catch {
                logError("Failed to delete: \(error)", category: "Gallery")
            }
        }
    }

    func revealInFinder() {
        guard let item = selectedItem else { return }
        MediaExportService.revealFileInFinder(item.filePath)
    }

    func openOutputFolder() {
        MediaExportService.revealInFinder()
    }
}
