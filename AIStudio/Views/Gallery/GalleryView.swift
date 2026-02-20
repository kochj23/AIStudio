//
//  GalleryView.swift
//  AIStudio
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()

    var body: some View {
        HSplitView {
            // Grid + filters
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .onChange(of: viewModel.searchText) { _, _ in
                                viewModel.applyFilters()
                            }
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                    // Type filter
                    Picker("", selection: Binding(
                        get: { viewModel.filterType ?? .image },
                        set: { viewModel.filterType = $0 }
                    )) {
                        Text("All").tag(Optional<MediaType>.none)
                        ForEach(MediaType.allCases, id: \.self) { type in
                            Label(type.rawValue.capitalized, systemImage: type.icon)
                                .tag(Optional(type))
                        }
                    }
                    .frame(width: 120)
                    .onChange(of: viewModel.filterType) { _, _ in
                        viewModel.applyFilters()
                    }

                    // Sort
                    Picker("", selection: $viewModel.sortOrder) {
                        ForEach(GalleryViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .frame(width: 120)
                    .onChange(of: viewModel.sortOrder) { _, _ in
                        viewModel.applyFilters()
                    }

                    Spacer()

                    Button(action: { viewModel.loadGallery() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.openOutputFolder() }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)

                    Text("\(viewModel.filteredItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)

                Divider()

                // Grid
                GalleryGridView(
                    items: viewModel.filteredItems,
                    selectedItem: $viewModel.selectedItem
                )
            }

            // Detail panel
            if let item = viewModel.selectedItem {
                MediaDetailView(
                    item: item,
                    onDelete: { viewModel.deleteSelected() },
                    onReveal: { viewModel.revealInFinder() }
                )
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            }
        }
        .onAppear {
            viewModel.loadGallery()
        }
    }
}
