// SideRailNavList.swift
// Defines side rail nav list for the Shared / Components surface.
//

import SwiftUI

extension SideRailNavigationView {
    /// Main nav stack for the side rail, including the collapsed-mode re-entry behavior on the selected row.
    var navListView: some View {
        VStack(alignment: .leading, spacing: StratixTheme.SideRail.rowSpacing) {
            ForEach(orderedNavItems) { item in
                let isRowFocusable =
                    isRailExpanded || (collapsedSelectedNavFocusable && item.id == selectedNavID)
                SideRailNavButton(
                    item: item,
                    isSelected: item.id == selectedNavID && activeUtilityRoute == nil,
                    isExpanded: isRailExpanded,
                    isFocusable: isRowFocusable,
                    onSelect: {
                        onSelectNav(item.id)
                        moveFocusToContent()
                    },
                    onRequestExpandWhenCollapsed: {
                        guard item.id == selectedNavID else { return }
                        expandRailAndFocusPreferredTarget()
                    },
                    onMoveToContent: moveFocusToContent
                )
                .focused($focusedTarget, equals: .nav(item.id))
                .onMoveCommand { direction in
                    guard isRailExpanded else { return }
                    if direction == .right {
                        moveFocusToContent()
                        return
                    }
                    if direction == .up, item.id == firstExpandedNavID {
                        focusedTarget = .account
                        return
                    }
                    if direction == .down, item.id == lastExpandedNavID, let firstActionID {
                        focusedTarget = .action(firstActionID)
                    }
                }
            }
        }
    }
}

/// Focus-aware side rail nav row that uses icon-only chrome with a green selected state.
private struct SideRailNavButton: View {
    let item: SideRailNavItemViewState
    let isSelected: Bool
    let isExpanded: Bool
    let isFocusable: Bool
    let onSelect: () -> Void
    var onRequestExpandWhenCollapsed: (() -> Void)? = nil
    var onMoveToContent: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 14) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: StratixTheme.SideRail.iconSize, weight: isSelected || isFocused ? .bold : .semibold))
                        .frame(width: 28, height: 28)

                    if isExpanded {
                        Text(item.title)
                            .font(.system(size: StratixTheme.SideRail.labelSize, weight: isSelected || isFocused ? .semibold : .regular, design: .rounded))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                }
                .foregroundStyle(SideRailRowStyle.foreground(isFocused: isFocused, isSelected: isSelected))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: StratixTheme.SideRail.rowHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: StratixTheme.SideRail.rowCornerRadius, style: .continuous)
                        .fill(SideRailRowStyle.fill(isFocused: isFocused, isSelected: isSelected))
                )
                .animation(StratixTheme.SideRail.rowFocusAnimation, value: isSelected)
                .animation(StratixTheme.SideRail.rowFocusAnimation, value: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .disabled(!isFocusable)
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier(sideRailNavAccessibilityIdentifier)
        .accessibilityValue(Text(isSelected ? "selected" : "not_selected"))
        .onMoveCommand { direction in
            guard direction == .right || direction == .left else { return }
            if direction == .right {
                onMoveToContent?()
                return
            }
            guard isSelected, !isExpanded else { return }
            onRequestExpandWhenCollapsed?()
        }
    }

    /// Uses stable accessibility IDs so shell UI tests can target each primary route directly.
    private var sideRailNavAccessibilityIdentifier: String {
        switch item.id {
        case .library:
            return "side_rail_nav_library"
        case .consoles:
            return "side_rail_nav_consoles"
        }
    }
}