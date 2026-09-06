// CloudLibraryUITestHarnessView.swift
// Defines the cloud library ui test harness view used in the Integration / UITestHarness surface.
//

import SwiftUI

struct CloudLibraryUITestHarnessView: View {
    @State private var selectedTile: MediaTileViewState?
    @State private var autoDetailScheduled = false
    @State private var queryText = ""

    private var libraryState: CloudLibraryLibraryViewState {
        CloudLibraryPreviewData.library
    }

    private var detailState: CloudLibraryTitleDetailViewState {
        guard let selectedTile else {
            return CloudLibraryPreviewData.detail
        }

        return CloudLibraryPreviewData.cloudItems.first(where: { $0.titleId == selectedTile.titleID.rawValue })
            .map { item in
                CloudLibraryTitleDetailViewState(
                    id: "uitest-\(item.titleId)",
                    title: item.name,
                    subtitle: item.publisherName,
                    heroImageURL: item.heroImageURL,
                    posterImageURL: item.posterImageURL,
                    ratingText: "UI Test",
                    legalText: nil,
                    descriptionText: item.shortDescription,
                    primaryAction: .init(id: "play", title: "Play", systemImage: "play.fill", style: .primary),
                    secondaryActions: [],
                    capabilityChips: [],
                    gallery: [],
                    achievementSummary: nil,
                    achievementItems: [],
                    achievementErrorText: nil,
                    detailPanels: [
                        .init(id: "about", title: "About", body: item.shortDescription ?? item.name)
                    ]
                )
            } ?? CloudLibraryPreviewData.detail
    }

    private var continueBadgeCount: Int {
        libraryState.gridItems.filter { $0.badgeText != nil }.count
    }

    var body: some View {
        Group {
            if selectedTile == nil {
                ZStack(alignment: .topTrailing) {
                    CloudLibraryLibraryScreen(
                        state: libraryState,
                        tileLookup: Dictionary(uniqueKeysWithValues: libraryState.gridItems.map { ($0.titleID, $0) }),
                        queryText: $queryText,
                        isLibrarySearchActive: false,
                        onSelectTile: { tile in
                            selectedTile = tile
                        },
                        onPlayTile: { tile in
                            selectedTile = tile
                        }
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("route_library_root")

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                if let fallbackTile = libraryState.gridItems.first {
                                    selectedTile = fallbackTile
                                }
                            } label: {
                                Text("Open Detail (UI Test) [\(continueBadgeCount)]")
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.black.opacity(0.7), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("gamepass_open_detail_button")
                        }
                    }
                    .padding(28)
                }
                .onAppear {
                    guard StratixLaunchMode.isGamePassHomeAutoDetailUITestEnabled else { return }
                    guard !autoDetailScheduled else { return }
                    autoDetailScheduled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        guard selectedTile == nil else { return }
                        if let fallbackTile = libraryState.gridItems.first {
                            selectedTile = fallbackTile
                        }
                    }
                }
            } else {
                ZStack(alignment: .topTrailing) {
                    CloudLibraryTitleDetailScreen(
                        state: detailState,
                        onPrimaryAction: {},
                        onBack: {
                            selectedTile = nil
                        },
                        onSecondaryAction: { _ in },
                        showsAmbientBackground: false,
                        showsHeroArtwork: true,
                        usesOuterPadding: true,
                        interceptExitCommand: false
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("gamepass_detail_screen")
                }
            }
        }
    }
}
