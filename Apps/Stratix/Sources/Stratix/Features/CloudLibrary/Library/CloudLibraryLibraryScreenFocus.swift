// CloudLibraryLibraryScreenFocus.swift
// Defines cloud library library screen focus for the CloudLibrary / Library surface.
//

import SwiftUI
import UIKit
import StratixModels

/// Horizontal header moves that must not steal focus from in-header tabs.
enum LibraryHeaderFocusPolicy {
    enum HorizontalMove: Equatable {
        case enterSideRail
        case focusTab(String)
        case focusSearch
    }

    /// Only the leading header tab may enter the side rail; other tabs move to the previous tab.
    static func moveLeft(
        fromTabID tabID: String,
        tabs: [CloudLibraryLibraryTabViewState]
    ) -> HorizontalMove {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
            return .enterSideRail
        }
        if index == 0 {
            return .enterSideRail
        }
        return .focusTab(tabs[index - 1].id)
    }
}

/// Packs library filter chips into the game-grid width and reveals overflow chips
/// only when focus is on the last or second-to-last visible chip.
@MainActor
enum LibraryFilterChipLayout {
    static let spacing: CGFloat = 14
    static let lookahead = 2

    private static let widthCache = NSCache<NSString, NSNumber>()

    static func packedCount(
        from start: Int,
        widths: [CGFloat],
        spacing: CGFloat = spacing,
        maxWidth: CGFloat
    ) -> Int {
        guard start < widths.count, maxWidth > 0 else { return 0 }
        var used: CGFloat = 0
        var count = 0
        for index in start..<widths.count {
            let extra = count == 0 ? widths[index] : widths[index] + spacing
            if used + extra > maxWidth + 0.5 {
                if count == 0 {
                    return 1
                }
                break
            }
            used += extra
            count += 1
        }
        return count
    }

    static func visibleRange(
        focusedIndex: Int?,
        widths: [CGFloat],
        spacing: CGFloat = spacing,
        maxWidth: CGFloat,
        lookahead: Int = lookahead
    ) -> Range<Int> {
        let count = widths.count
        guard count > 0 else { return 0..<0 }

        var start = 0
        if let focused = focusedIndex {
            let clamped = min(max(focused, 0), count - 1)
            let targetLast = min(count - 1, clamped + lookahead)
            var candidate = 0
            while candidate <= clamped {
                let packed = packedCount(
                    from: candidate,
                    widths: widths,
                    spacing: spacing,
                    maxWidth: maxWidth
                )
                let end = candidate + packed
                if packed > 0, clamped < end, targetLast < end {
                    start = candidate
                    break
                }
                if candidate == clamped {
                    start = candidate
                    break
                }
                candidate += 1
            }
        }

        let packed = packedCount(
            from: start,
            widths: widths,
            spacing: spacing,
            maxWidth: maxWidth
        )
        let totalWithOverflow = min(packed + 1, count - start)
        return start..<(start + totalWithOverflow)
    }

    static func estimatedWidth(label: String, hasIcon: Bool) -> CGFloat {
        let key = "\(label)|\(hasIcon)" as NSString
        if let cached = widthCache.object(forKey: key) {
            return CGFloat(cached.doubleValue)
        }
        let descriptor = UIFont.systemFont(ofSize: 22, weight: .bold).fontDescriptor.withDesign(.rounded)
        let font = descriptor.map { UIFont(descriptor: $0, size: 22) }
            ?? UIFont.systemFont(ofSize: 22, weight: .bold)
        let textWidth = (label as NSString).size(withAttributes: [.font: font]).width
        let horizontalPadding = (StratixTheme.Library.chipHorizontalPadding + 8) * 2
        let iconWidth: CGFloat = hasIcon ? 28 : 0
        let result = ceil(horizontalPadding + iconWidth + textWidth)
        widthCache.setObject(NSNumber(value: Double(result)), forKey: key)
        return result
    }
}

extension CloudLibraryLibraryScreen {
    var focusedFilterIndex: Int? {
        guard case .filter(let id) = focusedTarget else { return nil }
        return state.filters.firstIndex(where: { $0.id == id })
    }

    var currentFilterChipWidths: [CGFloat] {
        state.filters.map { chip in
            LibraryFilterChipLayout.estimatedWidth(
                label: chip.label,
                hasIcon: chip.systemImage != nil
            )
        }
    }

    var visibleFilterChips: [ChipViewState] {
        let widths = currentFilterChipWidths
        let range = LibraryFilterChipLayout.visibleRange(
            focusedIndex: focusedFilterIndex,
            widths: widths,
            maxWidth: libraryGridTileSpanWidth
        )
        guard !range.isEmpty, state.filters.indices.contains(range.lowerBound) else {
            return []
        }
        let upper = min(range.upperBound, state.filters.count)
        return Array(state.filters[range.lowerBound..<upper])
    }

    var hasLeadingOverflowFilterChips: Bool {
        let range = LibraryFilterChipLayout.visibleRange(
            focusedIndex: focusedFilterIndex,
            widths: currentFilterChipWidths,
            maxWidth: libraryGridTileSpanWidth
        )
        return range.lowerBound > 0
    }

    var hasTrailingOverflowFilterChips: Bool {
        let widths = currentFilterChipWidths
        let range = LibraryFilterChipLayout.visibleRange(
            focusedIndex: focusedFilterIndex,
            widths: widths,
            maxWidth: libraryGridTileSpanWidth
        )
        guard !range.isEmpty else { return false }
        var totalWidth: CGFloat = 0
        for i in range {
            totalWidth += (totalWidth == 0 ? widths[i] : widths[i] + LibraryFilterChipLayout.spacing)
        }
        return range.upperBound < state.filters.count || totalWidth > libraryGridTileSpanWidth
    }

    var defaultGridFocusTileID: String? {
        if let lastFocusedGridTitleID,
           let tile = state.gridItems.first(where: { $0.titleID == lastFocusedGridTitleID }) {
            return tile.id
        }

        if let preferredTitleID,
           let tile = state.gridItems.first(where: { $0.titleID == preferredTitleID }) {
            return tile.id
        }

        return state.gridItems.first?.id
    }

    /// Position marker in the letter rail — follows scroll, then the focused card once scrolling stops.
    var letterIndexHighlightedLetter: String? {
        CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
            sections: letterSections,
            jumpLetter: letterJumpLetter,
            scrollLetter: scrollPositionLetter,
            focusedLetter: engineFocusedLetter ?? tileFocusLetter,
            prefersFocusedLetter: !isLibraryScrolling && hasSettledFocusLetter
        )
    }

    var libraryGridRowStride: CGFloat {
        CloudLibraryLibraryLetterIndexSupport.rowStride(itemWidth: cachedGridItemWidth)
    }

    func applyLibraryLetterScrollSample(_ sample: CloudLibraryLibraryScreen.LibraryLetterScrollSample) {
        let moved = abs(sample.offsetY - lastScrollOffsetY) > 0.5
        lastScrollOffsetY = sample.offsetY
        guard moved else { return }
        if !isLibraryScrolling {
            isLibraryScrolling = true
        }
        if hasSettledFocusLetter {
            hasSettledFocusLetter = false
        }
        if let letter = sample.letter, scrollPositionLetter != letter {
            scrollPositionLetter = letter
        }
        scheduleLetterIndexIdleSnap()
    }

    func scheduleLetterIndexIdleSnap() {
        letterScrollIdleTask?.cancel()
        letterScrollIdleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            settleLetterIndexToFocusedCard()
        }
    }

    func settleLetterIndexToFocusedCard() {
        letterScrollIdleTask?.cancel()
        letterScrollIdleTask = Task { @MainActor in
            if isLibraryScrolling {
                isLibraryScrolling = false
            }
            hasSettledFocusLetter = false
            try? await Task.sleep(for: .milliseconds(32))
            guard !Task.isCancelled, !isLibraryScrolling else { return }
            if let engine = engineFocusedLetter {
                applySettledFocusLetter(engine)
            } else if let focused = tileFocusLetter {
                applySettledFocusLetter(focused)
            }
        }
    }

    func applyEngineFocusedLetter(_ letter: String?) {
        if engineFocusedLetter != letter {
            engineFocusedLetter = letter
        }
        guard !isLibraryScrolling, let letter else { return }
        applySettledFocusLetter(letter)
    }

    func applySettledFocusLetter(_ letter: String) {
        if !hasSettledFocusLetter {
            hasSettledFocusLetter = true
        }
        if scrollPositionLetter != letter {
            scrollPositionLetter = letter
        }
    }

    func letterForTitleID(_ titleID: TitleID) -> String? {
        let title = tileLookup[titleID]?.title
            ?? state.gridItems.first(where: { $0.titleID == titleID })?.title
        guard let title, !title.isEmpty else { return nil }
        return CloudLibraryLibraryLetterIndexSupport.indexLetter(for: title)
    }

    /// First letter of the currently focused grid tile.
    var tileFocusLetter: String? {
        let titleID: TitleID?
        if case .tile(let id) = focusedTarget {
            titleID = id
        } else {
            titleID = lastFocusedGridTitleID ?? preferredTitleID
        }
        guard let titleID else { return nil }
        return letterForTitleID(titleID)
    }

    /// Returns from the grid to header chrome with one focus-driven scroll.
    func requestHeaderFocusFromGrid(scrollProxy: ScrollViewProxy) {
        if let remembered = lastFocusedHeaderTarget,
           case .filter(let id) = remembered,
           cachedFilterIDs.contains(id) {
            applyFocusDrivenTransition(to: .filter(id))
            return
        }
        if let lastFilter = state.filters.last {
            applyFocusDrivenTransition(to: .filter(lastFilter.id))
            return
        }
        requestHeaderFocusFromSideRail(scrollProxy: scrollProxy)
    }

    func requestHeaderFocusFromSideRail(scrollProxy: ScrollViewProxy) {
        if let remembered = lastFocusedHeaderTarget {
            switch remembered {
            case .tab(let id) where cachedTabIDs.contains(id):
                applyFocusDrivenTransition(to: .tab(id))
                return
            case .headerButton(let id) where id == "sort":
                applyFocusDrivenTransition(to: .headerButton(id))
                return
            case .headerButton(let id) where id == "clear-filters":
                applyFocusDrivenTransition(to: .headerButton(id))
                return
            case .filter(let id) where cachedFilterIDs.contains(id):
                applyFocusDrivenTransition(to: .filter(id))
                return
            case .searchField:
                applyFocusDrivenTransition(to: .searchField)
                return
            case .clearSearch where showsSearchNoMatches:
                applyFocusDrivenTransition(to: .clearSearch)
                return
            default:
                break
            }
        }

        if isLibrarySearchActive {
            applyFocusDrivenTransition(to: .searchField)
            return
        }

        if cachedTabIDs.contains(state.selectedTabID) {
            applyFocusDrivenTransition(to: .tab(state.selectedTabID))
            return
        }
        if let firstTab = state.tabs.first {
            applyFocusDrivenTransition(to: .tab(firstTab.id))
            return
        }
        if !state.sortLabel.isEmpty {
            applyFocusDrivenTransition(to: .headerButton("sort"))
            return
        }
        requestGridFocus(scrollProxy: scrollProxy)
    }

    func requestClearSearchFocus(scrollProxy: ScrollViewProxy, focusDriven: Bool = false) {
        pendingFocusTask?.cancel()
        if focusDriven {
            applyFocusDrivenTransition(to: .clearSearch)
            return
        }
        pendingFocusTask = Task { @MainActor in
            withAnimation(nil) {
                scrollProxy.scrollTo(Self.clearSearchAnchorID, anchor: .center)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedTarget = .clearSearch
        }
    }

    func requestEmptyStateUpNavigation(scrollProxy: ScrollViewProxy) {
        if let lastFilter = state.filters.last {
            applyFocusDrivenTransition(to: .filter(lastFilter.id))
            return
        }
        applyFocusDrivenTransition(to: .searchField)
    }

    /// Lets the focus engine drive one continuous scroll across header/grid boundaries.
    func applyFocusDrivenTransition(to target: LibraryFocusTarget) {
        pendingFocusTask?.cancel()
        withAnimation(Self.focusScrollAnimation) {
            focusedTarget = target
        }
    }

    func requestHeaderFocus(
        _ target: LibraryFocusTarget,
        scrollProxy: ScrollViewProxy,
        focusDriven: Bool = false
    ) {
        pendingFocusTask?.cancel()
        if focusDriven {
            applyFocusDrivenTransition(to: target)
            return
        }
        pendingFocusTask = Task { @MainActor in
            withAnimation(nil) {
                scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedTarget = target
        }
    }

    func requestGridFocus(
        scrollProxy: ScrollViewProxy,
        prefersFirstVisibleItem: Bool = false,
        focusDriven: Bool = false
    ) {
        if state.gridItems.isEmpty {
            if showsSearchNoMatches {
                requestClearSearchFocus(scrollProxy: scrollProxy, focusDriven: focusDriven)
            }
            return
        }
        let targetTitleID: TitleID?
        if focusDriven {
            targetTitleID = headerToGridFocusTitleID()
        } else if prefersFirstVisibleItem {
            targetTitleID = state.gridItems.first?.titleID
        } else if let remembered = lastFocusedGridTitleID,
                  tileLookup[remembered] != nil {
            targetTitleID = remembered
        } else if let preferredTitleID,
                  tileLookup[preferredTitleID] != nil {
            targetTitleID = preferredTitleID
        } else {
            targetTitleID = state.gridItems.first?.titleID
        }
        guard let targetTitleID,
              let targetID = scrollTargetID(for: targetTitleID) else { return }
        pendingFocusTask?.cancel()
        if focusDriven {
            applyFocusDrivenTransition(to: .tile(targetTitleID))
            return
        }
        pendingFocusTask = Task { @MainActor in
            withAnimation(nil) {
                scrollProxy.scrollTo(targetID, anchor: StratixTheme.Library.focusedRowAnchor)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedTarget = .tile(targetTitleID)
        }
    }

    /// Picks the nearest top-row tile when re-entering the grid from header chrome.
    private func headerToGridFocusTitleID() -> TitleID? {
        if let remembered = lastFocusedGridTitleID,
           let index = state.gridItems.firstIndex(where: { $0.titleID == remembered }),
           isTopGridRow(index: index),
           tileLookup[remembered] != nil {
            return remembered
        }
        return state.gridItems.first?.titleID
    }

    func scheduleFocusSettled(targetLabel: String, settledTitleID: TitleID?) {
        focusSettler.schedule {
            NavigationPerformanceTracker.recordFocusSettled(surface: "library", target: targetLabel)
            self.onSettledTileID(settledTitleID)
        }
    }

    func isTopGridRow(index: Int) -> Bool {
        index < cachedGridColumnCount
    }

    func isLeadingGridColumn(index: Int) -> Bool {
        index % cachedGridColumnCount == 0
    }

    /// True for the rightmost tile in a row, including partially filled rows in My games.
    func isRightmostGridTile(index: Int) -> Bool {
        let column = index % cachedGridColumnCount
        let rowStart = (index / cachedGridColumnCount) * cachedGridColumnCount
        let itemsInRow = min(cachedGridColumnCount, state.gridItems.count - rowStart)
        guard itemsInRow > 0 else { return false }
        return column == itemsInRow - 1
    }

    func focusLetterIndex(for letter: String) {
        let targetLetter: String
        if cachedLetterSectionSet.contains(letter) {
            targetLetter = letter
        } else if let highlighted = letterIndexHighlightedLetter, cachedLetterSectionSet.contains(highlighted) {
            targetLetter = highlighted
        } else if let first = cachedLetterSections.first {
            targetLetter = first
        } else {
            return
        }
        letterJumpLetter = nil
        pendingFocusTask?.cancel()
        permitsLetterIndexFocus = true
        pendingFocusTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedTarget = .letter(targetLetter)
        }
    }

    func jumpToLetter(_ letter: String, scrollProxy: ScrollViewProxy) {
        guard let titleID = cachedFirstTitleIDByLetter[letter],
              let targetID = scrollTargetID(for: titleID) else {
            return
        }

        letterJumpLetter = letter
        scrollPositionLetter = letter
        pendingFocusTask?.cancel()
        pendingFocusTask = Task { @MainActor in
            withAnimation(nil) {
                scrollProxy.scrollTo(targetID, anchor: StratixTheme.Library.focusedRowAnchor)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            lastFocusedGridTitleID = titleID
            permitsLetterIndexFocus = false
            focusedTarget = .tile(titleID)
            letterJumpLetter = nil
        }
    }

    func returnFocusToGridFromLetterIndex(scrollProxy: ScrollViewProxy) {
        permitsLetterIndexFocus = false
        if let remembered = lastFocusedGridTitleID, tileLookup[remembered] != nil {
            pendingFocusTask?.cancel()
            focusedTarget = .tile(remembered)
            return
        }
        requestGridFocus(scrollProxy: scrollProxy, focusDriven: true)
    }

    func updateGridLayout(for width: CGFloat) {
        let columns = StratixTheme.Library.gridColumnCount
        let availableWidth = max(width, 1)
        let itemWidth = floor(
            (availableWidth - CGFloat(columns - 1) * gridItemSpacing) / CGFloat(columns)
        )
        guard columns != cachedGridColumnCount || itemWidth != cachedGridItemWidth else { return }
        cachedGridColumnCount = columns
        cachedGridItemWidth = max(itemWidth, 1)
        cachedColumns = Array(
            repeating: GridItem(.fixed(cachedGridItemWidth), spacing: gridItemSpacing, alignment: .top),
            count: columns
        )
    }

    func scrollTargetID(for titleID: TitleID) -> String? {
        tileLookup[titleID]?.id
    }

    static func nextLibrarySortOption(after label: String) -> LibrarySortOption {
        let current = LibrarySortOption.allCases.first(where: {
            label.localizedCaseInsensitiveContains($0.label) || label.localizedCaseInsensitiveContains($0.rawValue)
        }) ?? .alphabetical
        let all = LibrarySortOption.allCases
        guard let index = all.firstIndex(of: current) else { return .alphabetical }
        return all[(index + 1) % all.count]
    }

    enum LibraryHeaderSegment: Hashable {
        case tab(String)
        case search
    }

    var libraryHeaderSegments: [LibraryHeaderSegment] {
        state.tabs.map { .tab($0.id) } + [.search]
    }

    var currentLibraryHeaderSegment: LibraryHeaderSegment {
        if isLibrarySearchActive {
            return .search
        }
        if cachedTabIDs.contains(state.selectedTabID) {
            return .tab(state.selectedTabID)
        }
        if let firstTab = state.tabs.first {
            return .tab(firstTab.id)
        }
        return .search
    }

    func shiftLibraryHeaderSegment(by delta: Int, scrollProxy: ScrollViewProxy) {
        guard shoulderNavigationShouldHandleInput() else { return }

        if isLibrarySearchActive {
            if delta < 0 {
                activateLibraryHeaderSegment(.tab(LibraryTabID.fullLibrary), scrollProxy: scrollProxy)
            }
            return
        }

        if case .headerButton("sort")? = focusedTarget {
            return
        }

        let segments = libraryHeaderSegments
        guard !segments.isEmpty else { return }

        guard let currentIndex = segments.firstIndex(of: currentLibraryHeaderSegment) else { return }
        let nextIndex = currentIndex + delta
        guard segments.indices.contains(nextIndex) else { return }
        activateLibraryHeaderSegment(segments[nextIndex], scrollProxy: scrollProxy)
    }

    func shoulderNavigationShouldHandleInput() -> Bool {
        let now = ContinuousClock.now
        if let cooldownUntil = shoulderNavigationCooldownUntil, now < cooldownUntil {
            return false
        }
        shoulderNavigationCooldownUntil = now + .milliseconds(280)
        return true
    }

    func activateLibraryHeaderSegment(_ segment: LibraryHeaderSegment, scrollProxy: ScrollViewProxy) {
        switch segment {
        case .tab(let id):
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            onSelectTab(id)
            focusLibraryHeaderSegment(.tab(id), scrollProxy: scrollProxy)
        case .search:
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            if !isLibrarySearchActive {
                onActivateSearch()
            }
            focusLibraryHeaderSegment(.tab("search_tab"), scrollProxy: scrollProxy)
        }
    }

    func focusLibraryHeaderSegment(_ target: LibraryFocusTarget, scrollProxy: ScrollViewProxy) {
        pendingFocusTask?.cancel()
        withAnimation(nil) {
            scrollProxy.scrollTo(Self.headerAnchorID, anchor: .top)
        }
        focusedTarget = target
    }
}