// CloudLibraryLibraryScreenFocus.swift
// Defines cloud library library screen focus for the CloudLibrary / Library surface.
//

import SwiftUI
import StratixModels

extension CloudLibraryLibraryScreen {
    var defaultGridFocusTileID: String? {
        if let preferredTitleID,
           let preferredTileID = scrollTargetID(for: preferredTitleID),
           tileLookup[preferredTitleID] != nil {
            return preferredTileID
        }

        return state.gridItems.first?.id
    }

    /// Green position marker in the letter rail — always tracks the focused grid tile.
    ///
    /// Priority:
    /// 1. Active letter jump (until scroll settles)
    /// 2. First letter of the focused grid tile
    var letterIndexHighlightedLetter: String? {
        if let letterJumpLetter {
            return letterJumpLetter
        }
        return tileFocusLetter ?? letterSections.first
    }

    /// First letter of the currently focused grid tile.
    var tileFocusLetter: String? {
        let titleID: TitleID?
        if case .tile(let id) = focusedTarget {
            titleID = id
        } else {
            titleID = lastFocusedGridTitleID ?? preferredTitleID
        }
        guard let titleID,
              let item = tileLookup[titleID] else {
            return nil
        }
        return CloudLibraryLibraryLetterIndexSupport.indexLetter(for: item.title)
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
                scrollProxy.scrollTo(targetID, anchor: .topLeading)
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
        guard cachedLetterSectionSet.contains(letter) else { return }
        letterJumpLetter = nil
        letterIndexEngaged = true
        permitsLetterIndexFocus = true
        MainActorDeferredTask.schedule(task: &pendingFocusTask) {
            focusedTarget = .letter(letter)
        }
    }

    func jumpToLetter(_ letter: String, scrollProxy: ScrollViewProxy) {
        guard let titleID = cachedFirstTitleIDByLetter[letter],
              let targetID = scrollTargetID(for: titleID) else {
            return
        }

        letterJumpLetter = letter
        pendingFocusTask?.cancel()
        pendingFocusTask = Task { @MainActor in
            withAnimation(nil) {
                scrollProxy.scrollTo(targetID, anchor: .top)
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            lastFocusedGridTitleID = titleID
            focusedTarget = .tile(titleID)
            letterJumpLetter = nil
        }
    }

    func returnFocusToGridFromLetterIndex(scrollProxy: ScrollViewProxy) {
        let letter: String?
        if case .letter(let focusedLetter) = focusedTarget {
            letter = focusedLetter
        } else {
            letter = letterIndexHighlightedLetter
        }

        if let letter, cachedFirstTitleIDByLetter[letter] != nil {
            jumpToLetter(letter, scrollProxy: scrollProxy)
            return
        }

        requestGridFocus(scrollProxy: scrollProxy)
    }

    func updateGridLayout(for width: CGFloat) {
        let availableWidth = max(width - (gridEdgeFocusInset * 2), gridItemWidth)
        let newColumnCount = max(Int((availableWidth + gridItemSpacing) / (gridItemWidth + gridItemSpacing)), 1)
        guard newColumnCount != cachedGridColumnCount else { return }
        cachedGridColumnCount = newColumnCount
        cachedColumns = Array(
            repeating: GridItem(.fixed(gridItemWidth), spacing: gridItemSpacing, alignment: .top),
            count: newColumnCount
        )
    }

    func scrollTargetID(for titleID: TitleID) -> String? {
        tileLookup[titleID]?.id
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
            if !isLibrarySearchActive {
                onActivateSearch()
            } else {
                focusLibraryHeaderSegment(.searchField, scrollProxy: scrollProxy)
                NotificationCenter.default.post(name: .librarySearchRequestKeyboard, object: nil)
            }
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