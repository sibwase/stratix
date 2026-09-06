// CloudLibraryShellHostActionTests.swift
// Exercises cloud library shell host action behavior.
//

import SwiftUI
import Testing
import StratixModels

#if canImport(Stratix)
@testable import Stratix
#endif

struct CloudLibraryShellHostActionTests {
    @Test
    @MainActor
    func browseActions_routeTypedIDsThroughClosures() {
        let focusState = CloudLibraryFocusState()
        var queryState = LibraryQueryState()
        var openedTitleID: TitleID?
        var launchedStream: (TitleID, String)?
        let actions = CloudLibraryBrowseRouteActions(
            refreshCloudLibrary: {},
            requestSideRailEntry: { focusState.requestSideRailEntry() },
            librarySelectTile: { tile in
                openedTitleID = tile.titleID
            },
            libraryPlayTile: { tile in
                launchedStream = (tile.titleID, tile.title)
            },
            libraryFocusTileID: { focusState.setFocusedTileID($0, for: .library) },
            librarySettledTileID: { focusState.setSettledHeroTileID($0, for: .library) },
            librarySelectTab: {
                queryState.selectedTabID = $0
            },
            libraryActivateSearch: {
                queryState.isLibrarySearchActive = true
            },
            librarySelectFilter: { _ in },
            librarySelectSort: { _ in },
            libraryClearFilters: {},
            searchClearQuery: {},
            searchSelectTile: { tile in
                openedTitleID = tile.titleID
            },
            searchFocusTileID: { focusState.setFocusedTileID($0, for: .library) }
        )

        let libraryID = TitleID(rawValue: "library-title")
        let searchID = TitleID(rawValue: "search-title")
        actions.libraryFocusTileID(libraryID)
        actions.searchFocusTileID(searchID)
        actions.librarySettledTileID(libraryID)
        #expect(focusState.focusedTileID(for: .library) == searchID)
        #expect(focusState.settledHeroTileID(for: .library) == libraryID)

        let libraryTile = MediaTileViewState(
            id: "library-tile",
            titleID: libraryID,
            title: "Halo Infinite"
        )
        actions.librarySelectTile(libraryTile)
        #expect(openedTitleID == libraryID)

    }

    @Test
    @MainActor
    func detailActions_launchStreamKeepsTypedTitleIDs() {
        var launchedStream: (TitleID, String)?
        let actions = CloudLibraryDetailRouteActions(
            launchStream: { launchedStream = ($0, $1) },
            secondaryAction: { _ in }
        )

        actions.launchStream(TitleID(rawValue: "avowed-title"), "detail_primary")

        #expect(launchedStream?.0 == TitleID(rawValue: "avowed-title"))
        #expect(launchedStream?.1 == "detail_primary")
    }

    @Test
    @MainActor
    func utilityActions_routeThroughThinHostClosures() async {
        let focusState = CloudLibraryFocusState()
        var openedConsoles = false
        var openedSettings = false

        let actions = CloudLibraryUtilityRouteActions(
            openConsoles: { openedConsoles = true },
            openSettings: { openedSettings = true },
            refreshProfileMetadata: {},
            refreshProfileData: {},
            refreshFriends: {},
            refreshCloudLibrary: {},
            refreshConsoles: {},
            signOut: {},
            requestSideRailEntry: { focusState.requestSideRailEntry() },
            exportPreviewDump: { "ok" }
        )

        actions.openSettings()
        #expect(openedSettings == true)

        actions.openConsoles()
        #expect(openedConsoles == true)

        actions.requestSideRailEntry()
        #expect(focusState.isSideRailExpanded == true)

        let exportResult = await actions.exportPreviewDump()
        #expect(exportResult == "ok")
    }
}
