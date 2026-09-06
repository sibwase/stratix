// ShellExitHandlingDecision.swift
// Defines shell exit handling decision for the Integration / UITestHarness surface.
//

struct ShellExitHandlingDecision: Equatable {
    let shouldConsumeBackEvent: Bool

    static func resolve(
        utilityRoute: ShellUtilityRoute?,
        selectedTile: MediaTileViewState?,
        streamOverlayVisible: Bool,
        primaryRoute: SideRailNavID,
        isSideRailExpanded: Bool
    ) -> Self {
        // Menu is always consumed inside the authenticated shell. Letting it
        // fall through suspends Stratix to Apple TV Home whenever focus is on
        // the side rail or otherwise not on a tile.
        _ = (utilityRoute, selectedTile, streamOverlayVisible, primaryRoute, isSideRailExpanded)
        return .init(shouldConsumeBackEvent: true)
    }
}
