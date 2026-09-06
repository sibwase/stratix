// CloudLibraryBrowseRouteHost.swift
// Defines cloud library browse route host for the Features / CloudLibrary surface.
//

import SwiftUI
import StratixCore

/// Renders the active browse destination and handles load-state gating for each route.
struct CloudLibraryBrowseRouteHost: View {
    let presentation: CloudLibraryBrowseRoutePresentation
    let searchText: Binding<String>
    let isLibrarySearchActive: Bool
    let actions: CloudLibraryBrowseRouteActions

    var body: some View {
        switch presentation.browseRoute {
        case .consoles:
            CloudLibraryConsolesView(onRequestSideRailEntry: actions.requestSideRailEntry)
        case .library:
            loadStateGatedContent { libraryScreen }
        }
    }

    @ViewBuilder
    /// Applies the shared load-state gate used by library before rendering live content.
    private func loadStateGatedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if presentation.loadState.showsBrowseContent {
            content()
        } else if case .failedNoCache(let error) = presentation.loadState {
            errorPanel(error)
        } else {
            loadingPanel
        }
    }

    private var loadingPanel: some View {
        CloudLibraryStatusPanel(
            state: .init(
                kind: .loading,
                title: "Updating Library",
                message: "",
                primaryActionTitle: nil
            )
        )
    }

    private func errorPanel(_ error: String) -> some View {
        CloudLibraryStatusPanel(
            state: .init(
                kind: .error,
                title: "Couldn't load library",
                message: error,
                primaryActionTitle: "Try Again"
            ),
            onPrimaryAction: actions.refreshCloudLibrary
        )
    }

    private var libraryScreen: some View {
        CloudLibraryLibraryScreen(
            state: presentation.libraryState,
            tileLookup: presentation.combinedLibraryTileLookup,
            queryText: searchText,
            searchQuerySnapshot: searchText.wrappedValue,
            isLibrarySearchActive: isLibrarySearchActive,
            preferredTitleID: presentation.preferredLibraryTileID,
            onSelectTile: actions.librarySelectTile,
            onPlayTile: actions.libraryPlayTile,
            onActivateSearch: actions.libraryActivateSearch,
            onFocusTileID: actions.libraryFocusTileID,
            onSettledTileID: actions.librarySettledTileID,
            onSelectTab: actions.librarySelectTab,
            onSelectFilter: actions.librarySelectFilter,
            onSelectSort: actions.librarySelectSort,
            onClearFilters: actions.libraryClearFilters,
            onClearSearch: actions.searchClearQuery,
            onRemoveTileFromMRU: actions.libraryRemoveTileFromMRU ?? { _ in },
            onRequestSideRailEntry: actions.requestSideRailEntry
        )
        .equatable()
    }
}
