// CloudLibraryLibraryScreen.swift
// Defines the cloud library library screen for the CloudLibrary / Library surface.
//

import SwiftUI
import StratixModels

struct CloudLibraryLibraryScreen: View, Equatable {

    let state: CloudLibraryLibraryViewState
    let tileLookup: [TitleID: MediaTileViewState]
    @Binding var queryText: String
    var searchQuerySnapshot: String = ""
    var isLibrarySearchActive: Bool
    var preferredTitleID: TitleID? = nil
    let onSelectTile: (MediaTileViewState) -> Void
    var onActivateSearch: () -> Void = {}
    var onFocusTileID: (TitleID?) -> Void = { _ in }
    var onSettledTileID: (TitleID?) -> Void = { _ in }
    var onSelectTab: (String) -> Void = { _ in }
    var onSelectFilter: (ChipViewState) -> Void = { _ in }
    var onSelectSort: () -> Void = {}
    var onClearFilters: () -> Void = {}
    var onClearSearch: () -> Void = {}
    var onRequestSideRailEntry: () -> Void = {}

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Namespace var gridFocusNamespace
    @Namespace var headerFocusNamespace
    enum LibraryFocusTarget: Hashable {
        case tab(String)
        case headerButton(String)
        case searchField
        case filter(String)
        case clearSearch
        case tile(TitleID)
        case letter(String)
    }

    static let clearSearchAnchorID = "library_empty_clear_search"
    /// Matches the system focus-scroll pacing used when crossing header/grid boundaries on tvOS.
    static let focusScrollAnimation = Animation.easeInOut(duration: 0.28)

    @FocusState var focusedTarget: LibraryFocusTarget?
    @State var lastFocusedGridTitleID: TitleID?
    @State var lastFocusedHeaderTarget: LibraryFocusTarget?
    @State var libraryContentWidth: CGFloat = 1_920
    @State var letterJumpLetter: String?
    @State var permitsLetterIndexFocus = false
    @State var letterIndexEngaged = false

    @State var cachedGridColumnCount: Int = Self.defaultGridColumnCount
    @State var cachedColumns: [GridItem] = Self.defaultColumns
    @State var focusSettler = FocusSettleDebouncer()
    @State var pendingFocusTask: Task<Void, Never>?
    @State var shoulderNavigationCooldownUntil: ContinuousClock.Instant?
    @State var cachedLetterSections: [String] = []
    @State var cachedLetterSectionSet: Set<String> = []
    @State var cachedLetterSectionIndexByLetter: [String: Int] = [:]
    @State var cachedFirstTitleIDByLetter: [String: TitleID] = [:]
    @State private var cachedIndexedGridItems: [IndexedGridItem] = []
    @State var cachedTabIDs: Set<String> = []
    @State var cachedTabIndexByID: [String: Int] = [:]
    @State var cachedFilterIDs: Set<String> = []
    let gridItemWidth = StratixTheme.Library.gridItemWidth
    let gridItemSpacing = StratixTheme.Library.gridItemSpacing
    let gridEdgeFocusInset = StratixTheme.Library.gridEdgeFocusInset
    static let headerAnchorID = "library_header"
    static let defaultGridColumnCount: Int = {
        let availableWidth = max(1920 - (StratixTheme.Library.gridEdgeFocusInset * 2), StratixTheme.Library.gridItemWidth)
        return max(Int((availableWidth + StratixTheme.Library.gridItemSpacing) / (StratixTheme.Library.gridItemWidth + StratixTheme.Library.gridItemSpacing)), 1)
    }()
    static let defaultColumns: [GridItem] = Array(
        repeating: GridItem(.fixed(StratixTheme.Library.gridItemWidth), spacing: StratixTheme.Library.gridItemSpacing, alignment: .top),
        count: defaultGridColumnCount
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

                    if state.gridItems.isEmpty {
                        libraryEmptyStatePanel(scrollProxy: scrollProxy)
                    } else {
                        LazyVGrid(columns: cachedColumns, alignment: .leading, spacing: StratixTheme.Library.gridItemSpacing) {
                            ForEach(cachedIndexedGridItems) { entry in
                                let index = entry.index
                                let item = entry.item
                                let sectionLetter = entry.sectionLetter

                                MediaTileView(
                                    state: item,
                                    onSelect: {
                                        onSelectTile(item)
                                    },
                                    forcedFocus: focusedTarget == .tile(item.titleID)
                                )
                                .focused($focusedTarget, equals: .tile(item.titleID))
                                .prefersDefaultFocus(item.id == defaultGridFocusTileID, in: gridFocusNamespace)
                                .onMoveCommand { direction in
                                    NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                                    if direction == .left, isLeadingGridColumn(index: index) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focusScope(gridFocusNamespace)
                        .focusSection()
                        .padding(.horizontal, gridEdgeFocusInset)

                        .animation(nil, value: state.selectedTabID)
                        .animation(nil, value: isLibrarySearchActive)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("route_library_root")
            .scrollIndicators(.automatic, axes: .vertical)
            .overlay(alignment: .trailing) {
                if showsLetterIndex {
                    CloudLibraryLibraryLetterIndexView(
                        sections: letterSections,
                        sectionIndexByLetter: cachedLetterSectionIndexByLetter,
                        positionLetter: letterIndexHighlightedLetter,
                        focusedTarget: $focusedTarget,
                        letterFocusValue: { .letter($0) },
                        onSelectLetter: { letter in
                            jumpToLetter(letter, scrollProxy: scrollProxy)
                        },
                        onMoveFromLetterIndex: { direction in
                            if direction == .left {
                                returnFocusToGridFromLetterIndex(scrollProxy: scrollProxy)
                            }
                        },
                        isFocusEnabled: letterIndexFocusEnabled,
                        letterIndexEngaged: letterIndexEngaged
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.trailing, 4)
                }
            }
            .gamePassDisableSystemFocusEffect()
            .onChange(of: focusedTarget) { old, target in
                if case .letter = target,
                   !permitsLetterIndexFocus,
                   case .letter? = old {
                    // Allow navigation within the letter index rail.
                } else if case .letter = target, !permitsLetterIndexFocus, let old {
                    focusedTarget = old
                    return
                }

                if case .letter = target {
                    permitsLetterIndexFocus = false
                    letterIndexEngaged = true
                }

                guard let target else {
                    letterIndexEngaged = false
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
                    letterIndexEngaged = false
                    lastFocusedGridTitleID = titleID
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: titleID.rawValue)
                    onFocusTileID(titleID)
                    scheduleFocusSettled(targetLabel: titleID.rawValue, settledTitleID: titleID)
                case .tab(let id):
                    letterIndexEngaged = false
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "tab:\(id)")
                    scheduleFocusSettled(targetLabel: "tab:\(id)", settledTitleID: nil)
                case .searchField:
                    letterIndexEngaged = false
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "search_field")
                    scheduleFocusSettled(targetLabel: "search_field", settledTitleID: nil)
                case .headerButton(let id):
                    letterIndexEngaged = false
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "header:\(id)")
                    scheduleFocusSettled(targetLabel: "header:\(id)", settledTitleID: nil)
                case .filter(let id):
                    letterIndexEngaged = false
                    lastFocusedHeaderTarget = target
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "filter:\(id)")
                    scheduleFocusSettled(targetLabel: "filter:\(id)", settledTitleID: nil)
                case .clearSearch:
                    letterIndexEngaged = false
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "clear_search")
                    scheduleFocusSettled(targetLabel: "clear_search", settledTitleID: nil)
                case .letter(let letter):
                    onFocusTileID(nil)
                    NavigationPerformanceTracker.recordFocusTarget(surface: "library", target: "letter:\(letter)")
                    scheduleFocusSettled(targetLabel: "letter:\(letter)", settledTitleID: nil)
                }
            }
            .onChange(of: state.gridItems, initial: true) { _, _ in
                updateGridItemDerivedCaches()
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
                permitsLetterIndexFocus = false
                withAnimation(nil) {
                    scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
                }
            }
            .onChange(of: isLibrarySearchActive) { _, isActive in
                lastFocusedGridTitleID = nil
                letterJumpLetter = nil
                permitsLetterIndexFocus = false
                withAnimation(nil) {
                    scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
                }
                if isActive {
                    focusedTarget = .searchField
                    NotificationCenter.default.post(name: .librarySearchRequestKeyboard, object: nil)
                } else {
                    NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
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
                    isEnabled: true,
                    onShoulderLeft: {
                        shiftLibraryHeaderSegment(by: -1, scrollProxy: scrollProxy)
                    },
                    onShoulderRight: {
                        shiftLibraryHeaderSegment(by: 1, scrollProxy: scrollProxy)
                    }
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        .onDisappear {
            focusSettler.cancel()
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
}
#endif
