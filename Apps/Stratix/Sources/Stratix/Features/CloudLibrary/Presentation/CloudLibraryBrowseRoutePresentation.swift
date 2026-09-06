// CloudLibraryBrowseRoutePresentation.swift
// Defines cloud library browse route presentation for the Features / CloudLibrary surface.
//

import Foundation
import StratixModels

struct CloudLibraryBrowseRoutePresentation: Hashable {
    let browseRoute: CloudLibraryBrowseRoute
    let loadState: CloudLibraryLoadState
    let homeState: CloudLibraryHomeViewState
    let homeTileLookup: [TitleID: MediaTileViewState]
    let libraryState: CloudLibraryLibraryViewState
    let libraryTileLookup: [TitleID: MediaTileViewState]
    let totalLibraryCount: Int
    let searchBrowseItems: [MediaTileViewState]
    let searchResultItems: [MediaTileViewState]
    let searchTileLookup: [TitleID: MediaTileViewState]
    let combinedLibraryTileLookup: [TitleID: MediaTileViewState]
    let preferredHomeTileID: TitleID?
    let preferredLibraryTileID: TitleID?

    init(
        browseRoute: CloudLibraryBrowseRoute,
        loadState: CloudLibraryLoadState,
        homeState: CloudLibraryHomeViewState,
        homeTileLookup: [TitleID: MediaTileViewState],
        libraryState: CloudLibraryLibraryViewState,
        libraryTileLookup: [TitleID: MediaTileViewState],
        totalLibraryCount: Int,
        searchBrowseItems: [MediaTileViewState],
        searchResultItems: [MediaTileViewState],
        searchTileLookup: [TitleID: MediaTileViewState],
        combinedLibraryTileLookup: [TitleID: MediaTileViewState],
        preferredHomeTileID: TitleID?,
        preferredLibraryTileID: TitleID?
    ) {
        self.browseRoute = browseRoute
        self.loadState = loadState
        self.homeState = homeState
        self.homeTileLookup = homeTileLookup
        self.libraryState = libraryState
        self.libraryTileLookup = libraryTileLookup
        self.totalLibraryCount = totalLibraryCount
        self.searchBrowseItems = searchBrowseItems
        self.searchResultItems = searchResultItems
        self.searchTileLookup = searchTileLookup
        self.combinedLibraryTileLookup = combinedLibraryTileLookup
        self.preferredHomeTileID = preferredHomeTileID
        self.preferredLibraryTileID = preferredLibraryTileID
    }

    static let empty = CloudLibraryBrowseRoutePresentation(
        browseRoute: .library,
        loadState: .notLoaded,
        homeState: CloudLibraryHomeViewState(
            heroBackgroundURL: nil,
            carouselItems: [],
            sections: []
        ),
        homeTileLookup: [:],
        libraryState: CloudLibraryLibraryViewState(
            heroBackdropURL: nil,
            tabs: [],
            selectedTabID: "",
            filters: [],
            sortLabel: "",
            displayMode: .grid,
            gridItems: []
        ),
        libraryTileLookup: [:],
        totalLibraryCount: 0,
        searchBrowseItems: [],
        searchResultItems: [],
        searchTileLookup: [:],
        combinedLibraryTileLookup: [:],
        preferredHomeTileID: nil,
        preferredLibraryTileID: nil
    )
}

@MainActor
struct CloudLibraryBrowseRoutePresentationBuilder {
    func makeBrowseRoutePresentation(
        loadState: CloudLibraryLoadState,
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState,
        homeState: CloudLibraryHomeViewState,
        libraryState: CloudLibraryLibraryViewState,
        totalLibraryCount: Int,
        searchBrowseItems: [MediaTileViewState],
        searchResultItems: [MediaTileViewState],
        homeTileLookup: [TitleID: MediaTileViewState],
        libraryTileLookup: [TitleID: MediaTileViewState],
        searchTileLookup: [TitleID: MediaTileViewState],
        combinedLibraryTileLookup: [TitleID: MediaTileViewState]
    ) -> CloudLibraryBrowseRoutePresentation {
        CloudLibraryBrowseRoutePresentation(
            browseRoute: routeState.browseRoute,
            loadState: loadState,
            homeState: homeState,
            homeTileLookup: homeTileLookup,
            libraryState: libraryState,
            libraryTileLookup: libraryTileLookup,
            totalLibraryCount: totalLibraryCount,
            searchBrowseItems: searchBrowseItems,
            searchResultItems: searchResultItems,
            searchTileLookup: searchTileLookup,
            combinedLibraryTileLookup: combinedLibraryTileLookup,
            preferredHomeTileID: nil,
            preferredLibraryTileID: focusState.settledHeroTileID(for: .library)
        )
    }

    func makeBrowseRoutePresentation(
        loadState: CloudLibraryLoadState,
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState,
        homeState: CloudLibraryHomeViewState,
        libraryState: CloudLibraryLibraryViewState,
        totalLibraryCount: Int,
        searchBrowseItems: [MediaTileViewState],
        searchResultItems: [MediaTileViewState]
    ) -> CloudLibraryBrowseRoutePresentation {
        let homeTileLookup: [TitleID: MediaTileViewState] = [:]
        let libraryTileLookup = Self.libraryTileLookup(from: libraryState)
        let searchTileLookup = Self.searchTileLookup(
            searchBrowseItems: searchBrowseItems,
            searchResultItems: searchResultItems
        )
        return makeBrowseRoutePresentation(
            loadState: loadState,
            routeState: routeState,
            focusState: focusState,
            homeState: homeState,
            libraryState: libraryState,
            totalLibraryCount: totalLibraryCount,
            searchBrowseItems: searchBrowseItems,
            searchResultItems: searchResultItems,
            homeTileLookup: homeTileLookup,
            libraryTileLookup: libraryTileLookup,
            searchTileLookup: searchTileLookup,
            combinedLibraryTileLookup: CloudLibraryDataSource.combinedLibraryTileLookup(
                libraryTileLookup: libraryTileLookup,
                searchBrowseItems: searchBrowseItems,
                searchResultItems: searchResultItems
            )
        )
    }

    private static func libraryTileLookup(
        from libraryState: CloudLibraryLibraryViewState
    ) -> [TitleID: MediaTileViewState] {
        Dictionary(
            libraryState.gridItems.map { ($0.titleID, $0) },
            uniquingKeysWith: { current, _ in current }
        )
    }

    private static func searchTileLookup(
        searchBrowseItems: [MediaTileViewState],
        searchResultItems: [MediaTileViewState]
    ) -> [TitleID: MediaTileViewState] {
        Dictionary(
            (searchBrowseItems + searchResultItems).map { ($0.titleID, $0) },
            uniquingKeysWith: { current, _ in current }
        )
    }
}