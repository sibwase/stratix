// CloudLibraryRouteState.swift
// Defines the cloud library route state.
//

import SwiftUI
import Observation
import StratixCore
import StratixModels

@Observable
@MainActor
/// Owns the shell’s browse, utility, and detail route facts plus remembered-route restoration diagnostics.
final class CloudLibraryRouteState {
    enum RestoreDiagnosticsSource: String {
        case notRestored = "not_restored"
        case overrideHome = "override_home"
        case overrideLibrary = "override_library"
        case overrideSearch = "override_search" // legacy: migrated to library search tab
        case overrideConsoles = "override_consoles"
        case rememberedHome = "remembered_home"
        case rememberedLibrary = "remembered_library"
        case rememberedSearch = "remembered_search" // legacy: migrated to library search tab
        case rememberedConsoles = "remembered_consoles"
        case defaultHome = "default_home"
    }

    var browseRoute: CloudLibraryBrowseRoute = .library
    var utilityRoute: ShellUtilityRoute?
    var detailPath: [TitleID] = []
    var hasRestoredStoredRoute = false
    var restoreDiagnosticsValue = RestoreDiagnosticsSource.notRestored.rawValue
    var restoredLibraryTabID: String?

    /// Restores the startup browse route once per session from launch overrides or remembered shell state.
    func restoreStoredRouteIfNeeded(
        settingsStore: SettingsStore,
        overrideRawValue: String?
    ) {
        guard !hasRestoredStoredRoute else { return }
        hasRestoredStoredRoute = true

        if let overrideRawValue {
            let normalized = CloudLibraryBrowseRoute.normalized(from: overrideRawValue)
            restoredLibraryTabID = normalized.libraryTabID
            applyRestoredBrowseRoute(
                normalized.route,
                diagnosticsSource: diagnosticsSource(forRawValue: overrideRawValue, prefix: "override")
            )
            return
        }

        guard settingsStore.shell.rememberLastSection else {
            applyRestoredBrowseRoute(.library, diagnosticsSource: .defaultHome)
            return
        }
        let rememberedRawValue = settingsStore.shell.lastDestinationRawValue
        let normalized = CloudLibraryBrowseRoute.normalized(from: rememberedRawValue)
        restoredLibraryTabID = normalized.libraryTabID
        applyRestoredBrowseRoute(
            normalized.route,
            diagnosticsSource: diagnosticsSource(forRawValue: rememberedRawValue, prefix: "remembered")
        )
    }

    /// Persists the last browse destination only when the raw value has changed.
    func persistLastDestination(
        _ route: CloudLibraryBrowseRoute,
        settingsStore: SettingsStore
    ) {
        guard settingsStore.shell.lastDestinationRawValue != route.rawValue else { return }
        var shell = settingsStore.shell
        shell.lastDestinationRawValue = route.rawValue
        settingsStore.shell = shell
    }

    /// Updates the active browse route without mutating utility or detail state.
    func setBrowseRoute(_ route: CloudLibraryBrowseRoute) {
        browseRoute = route
    }

    /// Presents a utility overlay over the current browse route.
    func openUtilityRoute(_ route: ShellUtilityRoute) {
        utilityRoute = route
    }

    /// Dismisses the active utility overlay.
    func closeUtilityRoute() {
        utilityRoute = nil
    }

    /// Pushes a title onto the detail stack.
    func pushDetail(_ titleID: TitleID) {
        detailPath.append(titleID)
    }

    /// Pops the active detail route when one exists.
    func popDetail() {
        guard !detailPath.isEmpty else { return }
        detailPath.removeLast()
    }

    /// Clears the entire detail stack.
    func clearDetailPath() {
        detailPath.removeAll()
    }

    /// Returns the shell to the library browse route and clears overlays and detail state.
    func returnHome() {
        utilityRoute = nil
        detailPath.removeAll()
        browseRoute = .library
    }

    /// Applies a restored browse route while clearing any stale overlay or detail state.
    private func applyRestoredBrowseRoute(
        _ route: CloudLibraryBrowseRoute,
        diagnosticsSource: RestoreDiagnosticsSource
    ) {
        utilityRoute = nil
        detailPath.removeAll()
        browseRoute = route
        restoreDiagnosticsValue = diagnosticsSource.rawValue
    }

    /// Converts a restored route plus source prefix into the stored diagnostics enum.
    private func diagnosticsSource(
        forRawValue rawValue: String,
        prefix: String
    ) -> RestoreDiagnosticsSource {
        if rawValue == LibraryTabID.search {
            return prefix == "override" ? .overrideSearch : .rememberedSearch
        }
        if rawValue == "home" {
            return prefix == "override" ? .overrideLibrary : .rememberedLibrary
        }
        let route = CloudLibraryBrowseRoute(rawValue: rawValue) ?? .library
        switch (prefix, route) {
        case ("override", .library): return .overrideLibrary
        case ("override", .consoles): return .overrideConsoles
        case ("remembered", .library): return .rememberedLibrary
        case ("remembered", .consoles): return .rememberedConsoles
        default: return .defaultHome
        }
    }
}
