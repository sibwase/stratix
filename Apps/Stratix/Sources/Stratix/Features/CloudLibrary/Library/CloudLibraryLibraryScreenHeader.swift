// CloudLibraryLibraryScreenHeader.swift
// Defines cloud library library screen header for the CloudLibrary / Library surface.
//

import SwiftUI

extension CloudLibraryLibraryScreen {
    @ViewBuilder
    func header(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: StratixTheme.Library.headerBelowBadgeSpacing) {
            topBarRow(scrollProxy: scrollProxy)
                .frame(height: StratixTheme.SideRail.collapsedBadgeHeight)

            standardHeaderRow(scrollProxy: scrollProxy)

            filterChipsRow(scrollProxy: scrollProxy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusScope(headerFocusNamespace)
        .focusSection()
        .id(Self.headerAnchorID)
    }

    @ViewBuilder
    private func topBarRow(scrollProxy: ScrollViewProxy) -> some View {
        HStack(alignment: .center, spacing: 0) {
            if isLibrarySearchActive {
                SingleLineCharacterKeyboard(
                    queryText: $queryText,
                    focusedTarget: $focusedTarget,
                    onRequestSideRailEntry: onRequestSideRailEntry,
                    onRequestDownNavigation: {
                        requestHeaderFocus(.tab("search_tab"), scrollProxy: scrollProxy)
                    }
                )
            } else {
                Color.clear
                    .frame(height: StratixTheme.SideRail.collapsedBadgeHeight)
            }
        }
        .padding(.leading, 150)
        .frame(width: libraryGridTileSpanWidth, alignment: .leading)
        .frame(minHeight: StratixTheme.SideRail.collapsedBadgeHeight, maxHeight: StratixTheme.SideRail.collapsedBadgeHeight, alignment: .leading)
    }

    @ViewBuilder
    private func standardHeaderRow(scrollProxy: ScrollViewProxy) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 24) {
                ForEach(state.tabs) { tab in
                    LibraryTabButton(
                        title: tab.title,
                        systemImage: tab.systemImage,
                        isSelected: !isLibrarySearchActive && tab.id == state.selectedTabID
                    ) {
                        onSelectTab(tab.id)
                    }
                    .accessibilityIdentifier("library_tab_\(tab.id)")
                    .focused($focusedTarget, equals: .tab(tab.id))
                    .onMoveCommand { direction in
                        NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                        if isLibrarySearchActive {
                            handleSearchActiveTabMove(from: tab.id, direction: direction, scrollProxy: scrollProxy)
                            return
                        }
                        switch direction {
                        case .left:
                            if case .enterSideRail = LibraryHeaderFocusPolicy.moveLeft(
                                fromTabID: tab.id,
                                tabs: state.tabs
                            ) {
                                onRequestSideRailEntry()
                            }
                        case .right where tab.id == state.tabs.last?.id:
                            requestHeaderFocus(.tab("search_tab"), scrollProxy: scrollProxy)
                        default:
                            break
                        }
                    }
                }

                LibraryTabButton(
                    title: "Search",
                    systemImage: "magnifyingglass",
                    isSelected: isLibrarySearchActive,
                    onSelect: {
                        if !isLibrarySearchActive {
                            onActivateSearch()
                        }
                        focusedTarget = .letterKey(lastFocusedLetterKey)
                    }
                )
                .focused($focusedTarget, equals: .tab("search_tab"))
                .prefersDefaultFocus(isLibrarySearchActive, in: headerFocusNamespace)
                .accessibilityIdentifier("library_tab_search")
                .onMoveCommand { direction in
                    NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                    switch direction {
                    case .left:
                        if let lastTab = state.tabs.last {
                            requestHeaderFocus(.tab(lastTab.id), scrollProxy: scrollProxy)
                        } else {
                            onRequestSideRailEntry()
                        }
                    case .up where isLibrarySearchActive:
                        requestHeaderFocus(.letterKey(lastFocusedLetterKey), scrollProxy: scrollProxy)
                    case .right:
                        requestHeaderFocus(.headerButton("sort"), scrollProxy: scrollProxy)
                    default:
                        break
                    }
                }

                if isLibrarySearchActive && !queryText.isEmpty {
                    Text(queryText)
                        .font(
                            StratixTypography.rounded(
                                48,
                                weight: .bold,
                                dynamicTypeSize: dynamicTypeSize
                            )
                        )
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.leading, 6)
                }
            }
            .frame(minHeight: StratixTheme.Library.headerControlsRowHeight, alignment: .center)

            Spacer(minLength: 24)

            HStack(alignment: .center, spacing: 14) {
                if let summary = state.resultSummaryText {
                    Text(summary)
                        .font(StratixTypography.rounded(22, weight: .semibold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }

                SortButton(
                    title: state.sortLabel,
                    onSelect: {
                        onSelectSort(Self.nextLibrarySortOption(after: state.sortLabel))
                    },
                    menuOptions: LibrarySortOption.allCases.map { option in
                        (id: option.rawValue, title: option.label, action: { onSelectSort(option) })
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .focused($focusedTarget, equals: .headerButton("sort"))
                .onMoveCommand { direction in
                    NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                    switch direction {
                    case .left:
                        requestHeaderFocus(.tab("search_tab"), scrollProxy: scrollProxy)
                    default:
                        break
                    }
                }

                if !state.activeFilterLabels.isEmpty {
                    SortButton(title: "Show all", icon: "line.3.horizontal.decrease.circle.fill", onSelect: onClearFilters)
                        .focused($focusedTarget, equals: .headerButton("clear-filters"))
                        .onMoveCommand { direction in
                            NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                            if direction == .left {
                                requestHeaderFocus(.headerButton("sort"), scrollProxy: scrollProxy)
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: StratixTheme.Library.headerControlsRowHeight, alignment: .leading)
    }

    @ViewBuilder
    private func filterChipsRow(scrollProxy: ScrollViewProxy) -> some View {
        HStack(spacing: LibraryFilterChipLayout.spacing) {
            ForEach(visibleFilterChips) { filter in
                LibraryFilterChipButton(chip: filter) {
                    onSelectFilter(filter)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    )
                )
                .focused($focusedTarget, equals: .filter(filter.id))
                .onMoveCommand { direction in
                    switch direction {
                    case .down:
                        NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                        if !showsSearchNoMatches {
                            requestGridFocus(scrollProxy: scrollProxy, focusDriven: true)
                        }
                    case .left:
                        if filter.id == visibleFilterChips.first?.id {
                            focusedTarget = nil
                            onRequestSideRailEntry()
                        }
                    default:
                        break
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.28), value: visibleFilterChips.map(\.id))
        .frame(width: libraryGridTileSpanWidth, alignment: .leading)
        .mask {
            let hasLeading = hasLeadingOverflowFilterChips
            let hasTrailing = hasTrailingOverflowFilterChips
            if hasLeading && hasTrailing {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.80),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if hasLeading {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if hasTrailing {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.80),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                Color.black
            }
        }
        .opacity(state.filters.isEmpty ? 0 : 1)
        .allowsHitTesting(!state.filters.isEmpty)
        .accessibilityHidden(state.filters.isEmpty)
    }

    private func handleSearchActiveTabMove(
        from tabID: String,
        direction: MoveCommandDirection,
        scrollProxy: ScrollViewProxy
    ) {
        guard let index = cachedTabIndexByID[tabID] else { return }

        switch direction {
        case .left:
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            if index > 0 {
                requestHeaderFocus(.tab(state.tabs[index - 1].id), scrollProxy: scrollProxy)
            } else {
                onRequestSideRailEntry()
            }
        case .right:
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            if index < state.tabs.count - 1 {
                requestHeaderFocus(.tab(state.tabs[index + 1].id), scrollProxy: scrollProxy)
            } else {
                requestHeaderFocus(.searchField, scrollProxy: scrollProxy)
            }
        default:
            break
        }
    }

    @ViewBuilder
    func libraryEmptyStatePanel(scrollProxy: ScrollViewProxy) -> some View {
        if showsSearchNoMatches {
            searchNoMatchesPanel(scrollProxy: scrollProxy)
        } else {
            CloudLibraryStatusPanel(
                state: .init(
                    kind: .empty,
                    title: "Library is empty",
                    message: "Once cloud titles are available they will appear here.",
                    primaryActionTitle: nil
                )
            )
            .frame(height: 480)
        }
    }

    private func searchNoMatchesPanel(scrollProxy: ScrollViewProxy) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text("No matches")
                    .font(StratixTypography.rounded(34, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                Text("No titles matched \"\(queryText)\"")
                    .font(StratixTypography.rounded(20, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Press CLEAR ⌫ or Back button to reset search")
                        .font(StratixTypography.rounded(16, weight: .semibold, dynamicTypeSize: dynamicTypeSize))
                }
                .foregroundStyle(StratixTheme.Colors.textMuted.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .padding(.top, 4)
            }
            .frame(maxWidth: 760)
            Spacer()
        }
        .frame(height: 440)
        .frame(maxWidth: .infinity)
        .id(Self.clearSearchAnchorID)
    }
}