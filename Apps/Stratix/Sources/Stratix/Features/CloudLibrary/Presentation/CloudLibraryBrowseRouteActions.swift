// CloudLibraryBrowseRouteActions.swift
// Defines cloud library browse route actions for the Features / CloudLibrary surface.
//

import StratixModels

struct CloudLibraryBrowseRouteActions {
    let refreshCloudLibrary: @MainActor () -> Void
    let requestSideRailEntry: @MainActor () -> Void
    let librarySelectTile: @MainActor (MediaTileViewState) -> Void
    let libraryPlayTile: @MainActor (MediaTileViewState) -> Void
    let libraryFocusTileID: @MainActor (TitleID?) -> Void
    let librarySettledTileID: @MainActor (TitleID?) -> Void
    let librarySelectTab: @MainActor (String) -> Void
    let libraryActivateSearch: @MainActor () -> Void
    let librarySelectFilter: @MainActor (ChipViewState) -> Void
    let librarySelectSort: @MainActor (LibrarySortOption) -> Void
    let libraryClearFilters: @MainActor () -> Void
    let searchClearQuery: @MainActor () -> Void
    let searchSelectTile: @MainActor (MediaTileViewState) -> Void
    let searchFocusTileID: @MainActor (TitleID?) -> Void
    var libraryRemoveTileFromMRU: (@MainActor (MediaTileViewState) -> Void)? = nil
}
