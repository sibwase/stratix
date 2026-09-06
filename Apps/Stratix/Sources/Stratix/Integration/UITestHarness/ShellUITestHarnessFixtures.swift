// ShellUITestHarnessFixtures.swift
// Defines shell ui test harness fixtures for the Integration / UITestHarness surface.
//

import Foundation
import StratixModels

@MainActor
enum ShellUITestHarnessFixtures {
    static let profileName = "Stratix Preview"
    static let gamertag = "stratix.preview"
    static let gamerscore = "24310"
    static let profileImageURL: URL? = nil
    static let presenceState = "Online"
    static let featuredItemName = CloudLibraryPreviewData.cloudSections.flatMap(\.items).first?.name ?? "Preview Home"
    static let cloudLibraryCount = CloudLibraryPreviewData.cloudSections.flatMap(\.items).count
    static let consoleCount = 2
    static let friendsCount = 3

    static var libraryState: CloudLibraryLibraryViewState {
        CloudLibraryPreviewData.library
    }

    static var libraryTileLookup: [TitleID: MediaTileViewState] {
        Dictionary(
            uniqueKeysWithValues: libraryState.gridItems.map {
                ($0.titleID, $0)
            }
        )
    }

    static func detailState(for tile: MediaTileViewState) -> CloudLibraryTitleDetailViewState {
        CloudLibraryPreviewData.cloudItems.first(where: { $0.titleId == tile.titleID.rawValue })
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
}
