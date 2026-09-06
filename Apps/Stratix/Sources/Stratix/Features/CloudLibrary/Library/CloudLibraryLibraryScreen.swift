// CloudLibraryLibraryScreen.swift
// Defines the cloud library library screen for the CloudLibrary / Library surface.
//

import SwiftUI
import StratixCore
import StratixModels

struct CloudLibraryLibraryScreen: View, Equatable {

    let state: CloudLibraryLibraryViewState
    let tileLookup: [TitleID: MediaTileViewState]
    @Binding var queryText: String
    var searchQuerySnapshot: String = ""
    var isLibrarySearchActive: Bool
    var preferredTitleID: TitleID? = nil
    let onSelectTile: (MediaTileViewState) -> Void
    var onPlayTile: (MediaTileViewState) -> Void = { _ in }
    var onActivateSearch: () -> Void = {}
    var onFocusTileID: (TitleID?) -> Void = { _ in }
    var onSettledTileID: (TitleID?) -> Void = { _ in }
    var onSelectTab: (String) -> Void = { _ in }
    var onSelectFilter: (ChipViewState) -> Void = { _ in }
    var onSelectSort: (LibrarySortOption) -> Void = { _ in }
    var onClearFilters: () -> Void = {}
    var onClearSearch: () -> Void = {}
    var onRemoveTileFromMRU: (MediaTileViewState) -> Void = { _ in }
    var onRequestSideRailEntry: () -> Void = {}

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.libraryGamepadChromeEnabled) var libraryGamepadChromeEnabled
    @Namespace var gridFocusNamespace
    @Namespace var headerFocusNamespace
    @Namespace var letterIndexFocusNamespace
    enum LibraryFocusTarget: Hashable {
        case tab(String)
        case headerButton(String)
        case searchField
        case letterKey(String)
        case filter(String)
        case clearSearch
        case tile(TitleID)
        case letter(String)
        case letterIndex
    }

    static let clearSearchAnchorID = "library_empty_clear_search"
    static let focusScrollAnimation = StratixTheme.Library.focusScrollAnimation

    @FocusState var focusedTarget: LibraryFocusTarget?
    @State var lastFocusedGridTitleID: TitleID?
    @State var lastFocusedHeaderTarget: LibraryFocusTarget?
    @State var lastFocusedLetterKey: String = "I"
    @State var libraryContentWidth: CGFloat = 1_920
    @State var letterJumpLetter: String?
    @State var permitsLetterIndexFocus = false
    @State var suppressNextGridFocusScroll = false

    @State var cachedGridColumnCount: Int = StratixTheme.Library.gridColumnCount
    @State var cachedGridItemWidth: CGFloat = StratixTheme.Library.gridItemWidth
    @State var cachedColumns: [GridItem] = Self.defaultColumns
    @State var focusSettler = FocusSettleDebouncer()
    @State var pendingFocusTask: Task<Void, Never>?
    @State var shoulderNavigationCooldownUntil: ContinuousClock.Instant?
    @State var cachedLetterSections: [String] = []
    @State var cachedLetterSectionSet: Set<String> = []
    @State var cachedLetterSectionIndexByLetter: [String: Int] = [:]
    @State var cachedFirstTitleIDByLetter: [String: TitleID] = [:]
    @State var cachedSectionLetters: [String] = []
    @State var cachedHeaderHeight: CGFloat = StratixTheme.Library.estimatedHeaderHeight
    @State var scrollPositionLetter: String?
    @State var isLibraryScrolling = false
    @State var lastScrollOffsetY: CGFloat = 0
    @State var letterScrollIdleTask: Task<Void, Never>?
    @State var engineFocusedLetter: String?
    @State var hasSettledFocusLetter = false
    @State private var cachedIndexedGridItems: [IndexedGridItem] = []
    @State var cachedTabIDs: Set<String> = []
    @State var cachedTabIndexByID: [String: Int] = [:]
    @State var cachedFilterIDs: Set<String> = []
    var gridItemWidth: CGFloat { cachedGridItemWidth }
    let gridItemSpacing = StratixTheme.Library.gridItemSpacing
    static let headerAnchorID = "library_header"
    static let defaultGridColumnCount = StratixTheme.Library.gridColumnCount
    static let defaultColumns: [GridItem] = Array(
        repeating: GridItem(.fixed(StratixTheme.Library.gridItemWidth), spacing: StratixTheme.Library.gridItemSpacing, alignment: .top),
        count: StratixTheme.Library.gridColumnCount
    )

    var showsLetterIndex: Bool {
        guard !isLibrarySearchActive else { return false }
        guard state.sortLabel.contains("A-Z") else { return false }
        guard cachedLetterSections.count >= 2 else { return false }

        if state.selectedTabID == LibraryTabID.myGames {
            return !state.gridItems.isEmpty
        }
        return state.gridItems.count >= 12
    }

    /// Letter rail accepts focus only when entered from the grid's trailing column.
    var letterIndexFocusEnabled: Bool {
        if case .letterIndex = focusedTarget { return true }
        if case .letter = focusedTarget { return true }
        return permitsLetterIndexFocus
    }

    var letterSections: [String] {
        cachedLetterSections
    }

    private struct IndexedGridItem: Identifiable {
        let index: Int
        let item: MediaTileViewState
        let sectionLetter: String

        var id: String { item.id }
    }

    struct LibraryLetterScrollSample: Equatable {
        var offsetY: CGFloat
        var letter: String?
    }

    private func updateHeaderDerivedCaches() {
        var tabIDs = Set<String>()
        tabIDs.reserveCapacity(state.tabs.count)
        var tabIndexByID: [String: Int] = [:]
        tabIndexByID.reserveCapacity(state.tabs.count)
        for (index, tab) in state.tabs.enumerated() {
            tabIDs.insert(tab.id)
            tabIndexByID[tab.id] = index
        }
        cachedTabIDs = tabIDs
        cachedTabIndexByID = tabIndexByID
        cachedFilterIDs = Set(state.filters.map(\.id))
    }

    private func updateGridItemDerivedCaches() {
        var seenLetters = Set<String>()
        var orderedLetters: [String] = []
        var firstTitleByLetter: [String: TitleID] = [:]
        var indexedItems: [IndexedGridItem] = []
        indexedItems.reserveCapacity(state.gridItems.count)
        orderedLetters.reserveCapacity(min(state.gridItems.count, 27))

        for (index, item) in state.gridItems.enumerated() {
            let letter = CloudLibraryLibraryLetterIndexSupport.indexLetter(for: item.title)
            if seenLetters.insert(letter).inserted {
                orderedLetters.append(letter)
                firstTitleByLetter[letter] = item.titleID
            }
            indexedItems.append(
                IndexedGridItem(
                    index: index,
                    item: item,
                    sectionLetter: letter
                )
            )
        }

        var sectionIndexByLetter: [String: Int] = [:]
        sectionIndexByLetter.reserveCapacity(orderedLetters.count)
        for (index, letter) in orderedLetters.enumerated() {
            sectionIndexByLetter[letter] = index
        }

        cachedLetterSections = orderedLetters
        cachedLetterSectionSet = seenLetters
        cachedLetterSectionIndexByLetter = sectionIndexByLetter
        cachedFirstTitleIDByLetter = firstTitleByLetter
        cachedSectionLetters = indexedItems.map(\.sectionLetter)
        cachedIndexedGridItems = indexedItems
    }

    /// Span from the leading edge of column 1 through the trailing edge of the last column.
    var libraryGridTileSpanWidth: CGFloat {
        let columns = CGFloat(cachedGridColumnCount)
        guard columns > 0 else { return gridItemWidth }
        return columns * gridItemWidth + max(0, columns - 1) * gridItemSpacing
    }

    var showsSearchNoMatches: Bool {
        isLibrarySearchActive
            && !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && state.gridItems.isEmpty
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: StratixTheme.Library.sectionSpacing) {
                    header(scrollProxy: scrollProxy)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { _, height in
                            if abs(cachedHeaderHeight - height) > 0.5 {
                                cachedHeaderHeight = height
                            }
                        }

                    if state.gridItems.isEmpty {
                        libraryEmptyStatePanel(scrollProxy: scrollProxy)
                    } else {
                        LazyVGrid(columns: cachedColumns, alignment: .leading, spacing: StratixTheme.Library.gridItemSpacing) {
                            ForEach(cachedIndexedGridItems) { entry in
                                let index = entry.index
                                let item = entry.item
                                let sectionLetter = entry.sectionLetter

                                let isMyGamesTab = state.selectedTabID == LibraryTabID.myGames
                                let isMRUItem = item.badgeText != nil || isMyGamesTab

                                LibraryLetterFocusHost(letter: sectionLetter) {
                                    MediaTileView(
                                        state: item,
                                        onSelect: {
                                            if isMyGamesTab {
                                                onPlayTile(item)
                                            } else {
                                                onSelectTile(item)
                                            }
                                        },
                                        onPlay: isMyGamesTab ? nil : {
                                            onPlayTile(item)
                                        },
                                        onViewDetails: isMyGamesTab ? {
                                            onSelectTile(item)
                                        } : nil,
                                        onRemoveFromMRU: isMRUItem ? {
                                            onRemoveTileFromMRU(item)
                                        } : nil,
                                        artworkOverrideSize: CGSize(
                                            width: cachedGridItemWidth,
                                            height: (cachedGridItemWidth * StratixTheme.Layout.tileAspect).rounded()
                                        )
                                    )
                                    .equatable()
                                }
                                .focused($focusedTarget, equals: .tile(item.titleID))
                                .prefersDefaultFocus(item.id == defaultGridFocusTileID, in: gridFocusNamespace)
                                .onMoveCommand { direction in
                                    let isChromeExit =
                                        (direction == .left && isLeadingGridColumn(index: index))
                                        || (direction == .up && isTopGridRow(index: index))
                                        || (direction == .right && isRightmostGridTile(index: index) && showsLetterIndex)
                                    if MediaTileAnalogPeek.shouldBlockNeighborMove(isChromeExit: isChromeExit) {
                                        focusedTarget = .tile(item.titleID)
                                        return
                                    }
                                    suppressNextGridFocusScroll = false
                                    NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                                    if direction == .left, isLeadingGridColumn(index: index) {
                                        focusedTarget = nil
                                        onRequestSideRailEntry()
                                    } else if direction == .right, isRightmostGridTile(index: index), showsLetterIndex {
                                        focusLetterIndex(for: sectionLetter)
                                    } else if direction == .up, isTopGridRow(index: index) {
                                        requestHeaderFocusFromGrid(scrollProxy: scrollProxy)
                                    }
                                }
                                .id(item.id)
                            }
                        }
                        .accessibilityIdentifier("library_grid_container")
                        .frame(width: libraryGridTileSpanWidth, alignment: .leading)
                        .focusScope(gridFocusNamespace)
                        .focusSection()
                        .onPreferenceChange(LibraryFocusedLetterKey.self) { letter in
                            applyEngineFocusedLetter(letter)
                        }
                        .padding(.bottom, StratixTheme.Library.gridVerticalCenterInset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(state.selectedTabID)
            .accessibilityIdentifier("route_library_root")
            .scrollIndicators(.never)
            .scrollClipDisabled()
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.top)
            .ignoresSafeArea(.keyboard)
            .onScrollGeometryChange(for: LibraryLetterScrollSample.self) { geometry in
                let offsetY = geometry.contentOffset.y
                let letter: String?
                if showsLetterIndex {
                    letter = CloudLibraryLibraryLetterIndexSupport.letter(
                        visibleMinY: geometry.visibleRect.minY,
                        visibleMaxY: geometry.visibleRect.maxY,
                        scrollDelta: offsetY - lastScrollOffsetY,
                        headerHeight: cachedHeaderHeight + StratixTheme.Library.sectionSpacing,
                        rowStride: libraryGridRowStride,
                        columnCount: cachedGridColumnCount,
                        sectionLetters: cachedSectionLetters
                    )
                } else {
                    letter = scrollPositionLetter
                }
                return LibraryLetterScrollSample(offsetY: offsetY, letter: letter)
            } action: { _, sample in
                applyLibraryLetterScrollSample(sample)
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .idle {
                    settleLetterIndexToFocusedCard()
                } else if !isLibraryScrolling {
                    isLibraryScrolling = true
                }
            }
            .overlay(alignment: .trailing) {
                CloudLibraryLibraryLetterIndexView(
                    sections: letterSections,
                    sectionIndexByLetter: cachedLetterSectionIndexByLetter,
                    positionLetter: letterIndexHighlightedLetter,
                    focusedTarget: $focusedTarget,
                    railFocusValue: .letterIndex,
                    onSelectLetter: { letter in
                        jumpToLetter(letter, scrollProxy: scrollProxy)
                    },
                    onMoveFromLetterIndex: { direction in
                        if direction == .left {
                            returnFocusToGridFromLetterIndex(scrollProxy: scrollProxy)
                        }
                    },
                    isFocusEnabled: letterIndexFocusEnabled,
                    namespace: letterIndexFocusNamespace
                )
                .frame(maxHeight: .infinity)
                .padding(
                    .top,
                    max(0, StratixTheme.Library.letterIndexVerticalInset - StratixTheme.Shell.contentTopPadding)
                )
                .padding(
                    .bottom,
                    max(0, StratixTheme.Library.letterIndexVerticalInset - StratixTheme.Shell.contentBottomPadding)
                )
                .offset(x: StratixTheme.Library.letterIndexOverlayOffset)
                .opacity(showsLetterIndex ? 1 : 0)
                .allowsHitTesting(showsLetterIndex)
                .accessibilityHidden(!showsLetterIndex)
            }
            .onChange(of: focusedTarget) { old, target in
                guard let target else {
                    onFocusTileID(nil)
                    onSettledTileID(nil)
                    focusSettler.cancel()
                    NavigationPerformanceTracker.recordFocusLoss(surface: "library")
                    return
                }

                if isLibrarySearchActive {
                    switch target {
                    case .searchField:
                        break
                    case .tab, .headerButton, .filter:
                        NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
                    default:
                        break
                    }
                }

                switch target {
                case .tile(let titleID):
                    lastFocusedGridTitleID = titleID
                    if !isLibraryScrolling, let letter = letterForTitleID(titleID) {
                        applySettledFocusLetter(letter)
                    }
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: titleID.rawValue)
                    scheduleFocusSettled(targetLabel: titleID.rawValue, settledTitleID: titleID)
                    // Native focus scrolling handles tile hops. scrollTo here janks a large LazyVGrid.
                    // First-row pinning: tab/search still scrollTo the header; do not force-scroll top-row tiles.
                case .tab(let id):
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "tab:\(id)")
                    scheduleFocusSettled(targetLabel: "tab:\(id)", settledTitleID: nil)
                case .searchField:
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "search_field")
                    scheduleFocusSettled(targetLabel: "search_field", settledTitleID: nil)
                case .letterKey(let key):
                    lastFocusedLetterKey = key
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "keyboard:\(key)")
                    scheduleFocusSettled(targetLabel: "keyboard:\(key)", settledTitleID: nil)
                case .headerButton(let id):
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "header:\(id)")
                    scheduleFocusSettled(targetLabel: "header:\(id)", settledTitleID: nil)
                case .filter(let id):
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "filter:\(id)")
                    scheduleFocusSettled(targetLabel: "filter:\(id)", settledTitleID: nil)
                case .clearSearch:
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "clear_search")
                    scheduleFocusSettled(targetLabel: "clear_search", settledTitleID: nil)
                case .letter(let letter):
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "letter:\(letter)")
                    scheduleFocusSettled(targetLabel: "letter:\(letter)", settledTitleID: nil)
                case .letterIndex:
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "letter_index")
                    scheduleFocusSettled(targetLabel: "letter_index", settledTitleID: nil)
                }
            }
            .onChange(of: state.gridItems, initial: true) { _, _ in
                updateGridItemDerivedCaches()
                if suppressNextGridFocusScroll {
                    withAnimation(nil) {
                        scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
                    }
                }
            }
            .onAppear {
                if focusedTarget == nil {
                    focusedTarget = .tab(state.selectedTabID)
                }
            }
            .onChange(of: state.tabs, initial: true) { _, _ in
                updateHeaderDerivedCaches()
            }
            .onChange(of: state.filters, initial: true) { _, _ in
                updateHeaderDerivedCaches()
            }
            .onChange(of: state.sortLabel) { _, _ in
                // Grid reorders on sort — remembered position is no longer valid.
                lastFocusedGridTitleID = nil
                updateGridLayout(for: libraryContentWidth)
            }
            .onChange(of: state.selectedTabID) { _, _ in
                lastFocusedGridTitleID = nil
                letterJumpLetter = nil
                scrollPositionLetter = nil
                permitsLetterIndexFocus = false
                suppressNextGridFocusScroll = true
                withAnimation(nil) {
                    scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
                }
            }
            .onChange(of: isLibrarySearchActive) { _, isActive in
                lastFocusedGridTitleID = nil
                letterJumpLetter = nil
                scrollPositionLetter = nil
                permitsLetterIndexFocus = false
                suppressNextGridFocusScroll = true
                if isActive {
                    focusedTarget = .searchField
                } else {
                    if case .searchField? = focusedTarget,
                       cachedTabIDs.contains(state.selectedTabID) {
                        requestHeaderFocus(.tab(state.selectedTabID), scrollProxy: scrollProxy)
                    }
                }
            }

            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            libraryContentWidth = proxy.size.width
                            updateGridLayout(for: proxy.size.width)
                        }
                        .onChange(of: proxy.size.width) { _, width in
                            libraryContentWidth = width
                            updateGridLayout(for: width)
                        }
                }
            )
            .background {
                CloudLibraryLibraryShoulderTabSwitch(
                    isEnabled: libraryGamepadChromeEnabled,
                    onShoulderLeft: {
                        shiftLibraryHeaderSegment(by: -1, scrollProxy: scrollProxy)
                    },
                    onShoulderRight: {
                        shiftLibraryHeaderSegment(by: 1, scrollProxy: scrollProxy)
                    },
                    onThumbstickLeft: {
                        handleThumbstickLeft()
                    }
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        .onDisappear {
            focusSettler.cancel()
            letterScrollIdleTask?.cancel()
            hasSettledFocusLetter = false
        }
    }

    private func handleThumbstickLeft() {
        if case .tile(let titleID) = focusedTarget {
            if let index = state.gridItems.firstIndex(where: { $0.titleID == titleID }),
               isLeadingGridColumn(index: index) {
                focusedTarget = nil
                onRequestSideRailEntry()
            }
        } else if case .tab(let tabID) = focusedTarget {
            if tabID == state.tabs.first?.id {
                focusedTarget = nil
                onRequestSideRailEntry()
            }
        } else if case .filter(let filterID) = focusedTarget {
            if filterID == state.filters.first?.id {
                focusedTarget = nil
                onRequestSideRailEntry()
            }
        }
    }

    nonisolated static func == (lhs: CloudLibraryLibraryScreen, rhs: CloudLibraryLibraryScreen) -> Bool {
        lhs.state == rhs.state &&
        lhs.tileLookup == rhs.tileLookup &&
        lhs.isLibrarySearchActive == rhs.isLibrarySearchActive &&
        lhs.searchQuerySnapshot == rhs.searchQuerySnapshot &&
        lhs.preferredTitleID == rhs.preferredTitleID
    }

}

private struct LibraryFocusedLetterKey: PreferenceKey {
    static let defaultValue: String? = nil
    static func reduce(value: inout String?, nextValue: () -> String?) {
        if let next = nextValue() {
            value = next
        }
    }
}

private struct LibraryLetterFocusHost<Content: View>: View {
    let letter: String
    let content: Content
    @Environment(\.isFocused) private var isFocused

    init(letter: String, @ViewBuilder content: () -> Content) {
        self.letter = letter
        self.content = content()
    }

    var body: some View {
        content.preference(key: LibraryFocusedLetterKey.self, value: isFocused ? letter : nil)
    }
}

#if DEBUG
#Preview("CloudLibraryLibrary Grid", traits: .fixedLayout(width: 1920, height: 1080)) {
    struct PreviewHost: View {
        @State private var queryText = ""

        var body: some View {
            CloudLibraryShellView(
                sideRail: CloudLibraryPreviewData.sideRail,
                selectedNavID: .library,
                heroBackgroundURL: CloudLibraryPreviewData.library.heroBackdropURL,
                onSelectNav: { _ in }
            ) {
                let tileLookup: [TitleID: MediaTileViewState] = Dictionary(
                    uniqueKeysWithValues: CloudLibraryPreviewData.library.gridItems.map {
                        ($0.titleID, $0)
                    }
                )
                CloudLibraryLibraryScreen(
                    state: CloudLibraryPreviewData.library,
                    tileLookup: tileLookup,
                    queryText: $queryText,
                    isLibrarySearchActive: false,
                    onSelectTile: { _ in }
                )
            }
        }
    }

    return PreviewHost()
        .environment(SettingsStore())
}
#endif
