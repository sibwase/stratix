// CloudLibraryShellHost.swift
// Defines the main CloudLibrary shell host, including side-rail routing and async action orchestration.
//

import SwiftUI
import StratixCore
import StratixModels

/// Owns CloudLibrary shell composition, route actions, and deferred async shell work.
struct CloudLibraryShellHost: View {
    let settingsStore: SettingsStore
    @Bindable var routeState: CloudLibraryRouteState
    @Bindable var focusState: CloudLibraryFocusState
    @Bindable var presentationStore: CloudLibraryPresentationStore
    let layoutPolicy: CloudLibraryLayoutPolicy
    let backActionPolicy: CloudLibraryBackActionPolicy
    let isStreamPresentationActive: Bool
    let shellInteractionCoordinator: CloudLibraryShellInteractionCoordinator
    let detailPrewarmCoordinator = CloudLibraryDetailPrewarmCoordinator()
    let stateSnapshot: CloudLibraryStateSnapshot
    let loadState: CloudLibraryLoadState
    let sceneModel: CloudLibrarySceneModel
    let queryState: Binding<LibraryQueryState>
    let selectedSettingsPane: Binding<CloudLibrarySettingsPane>
    let viewModel: CloudLibraryViewModel
    let profileSnapshot: ProfileShellSnapshot
    let libraryStatus: LibraryShellStatusSnapshot
    let consoleCount: Int
    let regionOverrideDiagnostics: String?
    let launchCloudStream: (TitleID, String) -> Void
    let refreshCloudLibrary: (Bool) async -> Void
    let refreshConsoles: () async -> Void
    let refreshProfileMetadata: () async -> Void
    let refreshProfile: () async -> Void
    let refreshFriends: () async -> Void
    let signOut: () async -> Void
    let exportPreviewDump: () async -> String
    let loadDetail: @MainActor (ProductID) async -> Void
    let loadAchievements: @MainActor (TitleID) async -> Void
    let productDetail: @MainActor (ProductID) -> CloudLibraryProductDetail?
    let achievementSnapshot: @MainActor (TitleID) -> TitleAchievementSnapshot?
    let achievementErrorText: @MainActor (TitleID) -> String?
    var removeFromMRU: (@MainActor (TitleID) -> Void)? = nil
    @State private var pendingAsyncActions: [PendingAsyncAction] = []
    @State private var pendingAsyncActionSequence = 0

    private enum PendingAsyncAction: Equatable {
        case openDetail(TitleID)
        case refreshCloudLibrary
        case refreshConsoles
        case refreshProfileMetadata
        case refreshProfile
        case refreshFriends
        case signOut
    }

    /// Mounts the hosted shell and applies shell-level remote-command handlers.
    var body: some View {
        hostedShell
            .applyExitCommandIfNeeded(shouldAttachExitCommand) {
                handleExitCommand()
            }
            .onPlayPauseCommand {
                guard !isStreamPresentationActive else { return }
                handleSettingsShortcut()
            }
    }

    /// Builds the shell container and schedules presentation rebuild tasks off the current route state.
    private var hostedShell: some View {
        CloudLibraryShellView(
            sideRail: sideRailState,
            selectedNavID: selectedNavID,
            activeUtilityRoute: routeState.utilityRoute,
            heroBackgroundURL: sceneModel.heroBackgroundState.shellHeroBackgroundURL,
            contentTopPadding: contentTopPadding,
            contentHorizontalPadding: contentHorizontalPadding,
            contentLeadingAdjustment: contentLeadingAdjustment,
            contentBottomPadding: 18,
            sideRailSurfaceID: sceneModel.routeState.currentSurfaceID,
            onSelectNav: { navID in
                shellInteractionCoordinator.selectPrimaryRoute(
                    navID.browseRoute,
                    routeState: routeState,
                    focusState: focusState,
                    settingsStore: settingsStore,
                    queryState: queryState
                )
            },
            onSelectSideRailAction: handleSideRailAction,
            onMoveFromSideRailToContent: handleMoveFromSideRailToContent,
            isSideRailExpanded: $focusState.isSideRailExpanded,
            forceCollapsedSideRail: false,
            collapsedSelectedNavFocusable: false,
            onExpansionChanged: { expanded in
                focusState.isSideRailExpanded = expanded
            }
        ) {
            contentHost
        }
        .onAppear(perform: bootstrapShell)
        .task(id: shellPresentationTaskID) {
            presentationStore.rebuildShellPresentation(
                settingsStore: settingsStore,
                profileSnapshot: profileSnapshot,
                libraryStatus: libraryStatus,
                consoleCount: consoleCount,
                isLoadingCloudLibrary: stateSnapshot.isLoading,
                regionOverrideDiagnostics: regionOverrideDiagnostics,
                viewModel: viewModel
            )
        }
        .task(id: browsePresentationTaskID) {
            presentationStore.rebuildBrowsePresentation(
                loadState: loadState,
                routeState: routeState,
                focusState: focusState,
                viewModel: viewModel
            )
        }
        .task(id: pendingAsyncActionSequence) {
            await performPendingAsyncActions()
        }
    }

    @ViewBuilder
    /// Routes the current utility, browse, and detail presentation into the content host.
    private var contentHost: some View {
        CloudLibraryContentRouteHost(
            utilityRoute: routeState.utilityRoute,
            utilityPresentation: presentationStore.utilityRoutePresentation,
            selectedSettingsPane: selectedSettingsPane,
            utilityActions: utilityActions,
            browsePresentation: presentationStore.browseRoutePresentation,
            searchText: queryState.searchText,
            isLibrarySearchActive: queryState.wrappedValue.isLibrarySearchActive,
            browseActions: browseActions,
            detailPath: detailPathBinding,
            detailOriginRoute: routeState.browseRoute.appRoute,
            viewModel: viewModel,
            detailActions: detailActions,
            isSideRailExpanded: focusState.isSideRailExpanded
        )
    }

    /// Resolves whether the shell is currently showing browse, utility, or detail content.
    var contentMode: CloudLibraryShellContentMode {
        if routeState.utilityRoute != nil {
            .utility
        } else if routeState.detailPath.isEmpty {
            .browse
        } else {
            .detail
        }
    }

    private var selectedNavID: SideRailNavID {
        routeState.browseRoute.sideRailNavID
    }

    private var sideRailState: SideRailNavigationViewState {
        presentationStore.shellPresentationProjection.sideRail.sideRailState
    }

    private var contentTopPadding: CGFloat {
        layoutPolicy.shellContentTopPadding(
            browseRoute: routeState.browseRoute,
            utilityRoute: routeState.utilityRoute
        )
    }

    private var contentHorizontalPadding: CGFloat {
        layoutPolicy.shellContentHorizontalPadding(
            browseRoute: routeState.browseRoute,
            utilityRoute: routeState.utilityRoute
        )
    }

    private var contentLeadingAdjustment: CGFloat {
        layoutPolicy.shellContentLeadingAdjustment(
            browseRoute: routeState.browseRoute,
            utilityRoute: routeState.utilityRoute
        )
    }

    private var shouldAttachExitCommand: Bool {
        true
    }

    private var shellPresentationTaskID: Int {
        presentationStore.shellPresentationTaskID(
            settingsStore: settingsStore,
            profileSnapshot: profileSnapshot,
            libraryStatus: libraryStatus,
            consoleCount: consoleCount,
            isLoadingCloudLibrary: stateSnapshot.isLoading,
            regionOverrideDiagnostics: regionOverrideDiagnostics,
            viewModel: viewModel
        )
    }

    private var browsePresentationTaskID: Int {
        presentationStore.browsePresentationTaskID(
            loadState: loadState,
            routeState: routeState,
            focusState: focusState,
            viewModel: viewModel
        )
    }

    /// Builds the browse-route action bundle from shell-owned closures and state bindings.
    private var browseActions: CloudLibraryBrowseRouteActions {
        CloudLibraryBrowseRouteActions(
            refreshCloudLibrary: { enqueue(.refreshCloudLibrary) },
            requestSideRailEntry: requestSideRailEntry,
            librarySelectTile: { tile in enqueue(.openDetail(tile.titleID)) },
            libraryPlayTile: { tile in launchCloudStream(tile.titleID, tile.title) },
            libraryFocusTileID: { focusState.setFocusedTileID($0, for: .library) },
            librarySettledTileID: { focusState.setSettledHeroTileID($0, for: .library) },
            librarySelectTab: { tabID in
                queryState.wrappedValue.isLibrarySearchActive = false
                queryState.wrappedValue.searchText = ""
                queryState.wrappedValue.selectedTabID = tabID
            },
            libraryActivateSearch: {
                queryState.wrappedValue.isLibrarySearchActive = true
                queryState.wrappedValue.scopedCategory = nil
                queryState.wrappedValue.activeFilterIDs.removeAll()
            },

            librarySelectFilter: { filter in
                if queryState.wrappedValue.scopedCategory?.alias == filter.id {
                    queryState.wrappedValue.scopedCategory = nil
                } else {
                    queryState.wrappedValue.selectedTabID = LibraryTabID.fullLibrary
                    queryState.wrappedValue.scopedCategory = makeScopedCategory(
                        alias: filter.id,
                        label: filter.label
                    )
                }
                queryState.wrappedValue.activeFilterIDs.removeAll()
            },
            librarySelectSort: { option in
                focusState.setFocusedTileID(nil, for: .library)
                focusState.setSettledHeroTileID(nil, for: .library)
                queryState.wrappedValue.sortOption = option
            },
            libraryClearFilters: {
                queryState.wrappedValue.scopedCategory = nil
                queryState.wrappedValue.activeFilterIDs.removeAll()
            },
            searchClearQuery: {
                queryState.wrappedValue.searchText = ""
                focusState.setFocusedTileID(nil, for: .library)
                NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            },
            searchSelectTile: { tile in enqueue(.openDetail(tile.titleID)) },
            searchFocusTileID: { focusState.setFocusedTileID($0, for: .library) },
            libraryRemoveTileFromMRU: { tile in
                removeFromMRU?(tile.titleID)
            }
        )
    }

    private var detailActions: CloudLibraryDetailRouteActions {
        CloudLibraryDetailRouteActions(
            launchStream: { titleID, source in
                launchCloudStream(titleID, source)
            },
            secondaryAction: { action in
                handleDetailAction(action)
            }
        )
    }

    private var utilityActions: CloudLibraryUtilityRouteActions {
        CloudLibraryUtilityRouteActions(
            openConsoles: {
                shellInteractionCoordinator.openConsoles(
                    routeState: routeState,
                    focusState: focusState,
                    settingsStore: settingsStore
                )
            },
            openSettings: {
                shellInteractionCoordinator.openSettingsUtility(
                    routeState: routeState,
                    focusState: focusState,
                    selectedSettingsPane: selectedSettingsPane
                )
            },
            refreshProfileMetadata: { enqueue(.refreshProfileMetadata) },
            refreshProfileData: { enqueue(.refreshProfile) },
            refreshFriends: { enqueue(.refreshFriends) },
            refreshCloudLibrary: { enqueue(.refreshCloudLibrary) },
            refreshConsoles: { enqueue(.refreshConsoles) },
            signOut: { enqueue(.signOut) },
            requestSideRailEntry: requestSideRailEntry,
            exportPreviewDump: {
                await exportPreviewDump()
            }
        )
    }

    private var detailPathBinding: Binding<[TitleID]> {
        Binding(
            get: { routeState.detailPath },
            set: { proposedPath in
                routeState.detailPath = CloudLibraryDetailPathBindingPolicy.resolvedPath(
                    currentPath: routeState.detailPath,
                    proposedPath: proposedPath,
                    isStreamPresentationActive: isStreamPresentationActive
                )
            }
        )
    }

    func bootstrapShell() {
        shellInteractionCoordinator.bootstrapShell(
            routeState: routeState,
            focusState: focusState,
            settingsStore: settingsStore,
            overrideRawValue: StratixLaunchMode.uiTestBrowseRouteOverrideRawValue
        )
        if let restoredLibraryTabID = routeState.restoredLibraryTabID {
            if restoredLibraryTabID == LibraryTabID.search {
                queryState.wrappedValue.selectedTabID = LibraryTabID.fullLibrary
                queryState.wrappedValue.isLibrarySearchActive = true
            } else {
                queryState.wrappedValue.selectedTabID = restoredLibraryTabID
            }
            routeState.restoredLibraryTabID = nil
        }
    }

    func handleBack() {
        shellInteractionCoordinator.handleBack(
            routeState: routeState,
            focusState: focusState,
            backActionPolicy: backActionPolicy,
            settingsStore: settingsStore,
            queryState: queryState
        )
    }

    func handleExitCommand() {
        // Always consume Menu/Back in the authenticated shell. Letting it fall through
        // suspends the app to Apple TV Home whenever focus is on the rail or otherwise
        // not on a tile — including many remote/gamepad combinations.
        guard !isStreamPresentationActive else { return }
        handleBack()
    }

    func handleSettingsShortcut() {
        shellInteractionCoordinator.handleSettingsShortcut(
            routeState: routeState,
            focusState: focusState,
            selectedSettingsPane: selectedSettingsPane
        )
    }

    private func handleMoveFromSideRailToContent() {
        if let utilityRoute = routeState.utilityRoute {
            focusState.requestUtilityFocus(for: utilityRoute)
        } else {
            focusState.requestTopContentFocus(for: routeState.browseRoute)
        }
    }

    private func handleSideRailAction(_ actionID: String) {
        switch actionID {
        case "profile-menu":
            shellInteractionCoordinator.openProfileUtility(
                routeState: routeState,
                focusState: focusState
            )
        case "refresh":
            utilityActions.refreshCloudLibrary()
        case "settings":
            shellInteractionCoordinator.openSettingsUtility(
                routeState: routeState,
                focusState: focusState,
                selectedSettingsPane: selectedSettingsPane
            )
        default:
            break
        }
    }

    private func handleDetailAction(_ action: CloudLibraryActionViewState) {
        guard action.id == "refresh-library" else { return }
        enqueue(.refreshCloudLibrary)
    }

    private func makeScopedCategory(alias: String, label: String) -> LibraryScopedCategoryContext {
        LibraryScopedCategoryContext(
            alias: alias,
            label: label,
            allowedTitleIDs: Set<TitleID>()
        )
    }

    private func enqueue(_ action: PendingAsyncAction) {
        pendingAsyncActions.append(action)
        pendingAsyncActionSequence += 1
    }

    @MainActor
    private func dequeuePendingAsyncAction() -> PendingAsyncAction? {
        guard !pendingAsyncActions.isEmpty else { return nil }
        return pendingAsyncActions.removeFirst()
    }

    private func performPendingAsyncActions() async {
        while let action = await MainActor.run(body: dequeuePendingAsyncAction) {
            await run(action)
        }
    }

    private func run(_ action: PendingAsyncAction) async {
        switch action {
        case .openDetail(let titleID):
            await shellInteractionCoordinator.openDetail(
                titleID,
                routeState: routeState,
                focusState: focusState,
                queryState: queryState,
                stateSnapshot: stateSnapshot,
                viewModel: viewModel,
                prewarmDetailState: prewarmDetailState
            )
        case .refreshCloudLibrary:
            await refreshCloudLibrary(true)
        case .refreshConsoles:
            await refreshConsoles()
        case .refreshProfileMetadata:
            await refreshProfileMetadata()
        case .refreshProfile:
            await refreshProfile()
        case .refreshFriends:
            await refreshFriends()
        case .signOut:
            await signOut()
        }
    }

    private func requestSideRailEntry() {
        focusState.requestSideRailEntry()
    }

    private func prewarmDetailState(for titleID: TitleID) async {
        guard let item = stateSnapshot.item(titleID: titleID) else { return }
        await detailPrewarmCoordinator.prewarmDetailState(
            titleID: titleID,
            item: item,
            originRoute: routeState.browseRoute.appRoute,
            viewModel: viewModel,
            loadDetail: loadDetail,
            loadAchievements: loadAchievements,
            productDetail: productDetail,
            achievementSnapshot: achievementSnapshot,
            achievementErrorText: achievementErrorText
        )
    }
}

enum CloudLibraryShellContentMode: Equatable {
    case browse
    case utility
    case detail
}

private extension View {
    @ViewBuilder
    func applyExitCommandIfNeeded(_ enabled: Bool, perform action: @escaping () -> Void) -> some View {
        if enabled {
            onExitCommand(perform: action)
        } else {
            self
        }
    }
}


