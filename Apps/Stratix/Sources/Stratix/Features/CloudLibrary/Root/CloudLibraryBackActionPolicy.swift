// CloudLibraryBackActionPolicy.swift
// Defines cloud library back action policy for the CloudLibrary / Root surface.
//

enum CloudLibraryBackAction: Equatable {
    case closeUtilityRoute
    case popDetail
    case clearLibrarySearch
    case exitLibrarySearch
    case returnBrowseHome
    case enterSideRail
    case noOp
}

/// Resolves a single shell-level back action from the current route and side-rail state.
struct CloudLibraryBackActionPolicy {
    @MainActor
    /// Prefers closing overlays and detail before falling back to home-or-side-rail restoration.
    func resolve(
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState,
        isLibrarySearchActive: Bool = false,
        librarySearchText: String = ""
    ) -> CloudLibraryBackAction {
        if routeState.utilityRoute != nil {
            return .closeUtilityRoute
        }
        if !routeState.detailPath.isEmpty {
            return .popDetail
        }
        if routeState.browseRoute == .library, isLibrarySearchActive {
            let trimmedQuery = librarySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedQuery.isEmpty ? .exitLibrarySearch : .clearLibrarySearch
        }
        if routeState.browseRoute != .library {
            return .returnBrowseHome
        }
        if !focusState.isSideRailExpanded {
            return .enterSideRail
        }
        return .noOp
    }
}
