// SideRailActionList.swift
// Defines side rail action list for the Shared / Components surface.
//

import SwiftUI

extension SideRailNavigationView {
    /// Trailing action stack shown below the main nav rows once the rail is expanded.
    var actionListView: some View {
        VStack(alignment: .leading, spacing: StratixTheme.SideRail.rowSpacing) {
            ForEach(trailingActions) { action in
                SideRailActionButton(
                    action: action,
                    isSelected: action.id == "settings" && activeUtilityRoute == .settings,
                    isExpanded: isRailExpanded,
                    isFocusable: isRailExpanded || (action.id == "settings" && activeUtilityRoute == .settings),
                    onSelect: {
                        onSelectAction(action.id)
                        collapseRail()
                    },
                    onMoveToContent: moveFocusToContent
                )
                .focused($focusedTarget, equals: .action(action.id))
                .onMoveCommand { direction in
                    guard isRailExpanded else { return }
                    if direction == .right {
                        moveFocusToContent()
                        return
                    }
                    if direction == .up, action.id == firstActionID, let lastExpandedNavID {
                        focusedTarget = .nav(lastExpandedNavID)
                        return
                    }
                    if direction == .down, action.id == lastActionID {
                        focusedTarget = .action(action.id)
                    }
                }
            }
        }
    }
}

/// Focus-aware trailing action row used for settings and any future shell-level rail actions.
private struct SideRailActionButton: View {
    let action: SideRailActionViewState
    let isSelected: Bool
    let isExpanded: Bool
    let isFocusable: Bool
    let onSelect: () -> Void
    var onMoveToContent: (() -> Void)? = nil

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 14) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: StratixTheme.SideRail.iconSize, weight: isSelected || isFocused ? .bold : .semibold))
                        .frame(width: 28, height: 28)

                    if isExpanded {
                        Text(action.accessibilityLabel)
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
        .accessibilityIdentifier("side_rail_action_\(action.id)")
        .accessibilityLabel(Text(action.accessibilityLabel))
        .accessibilityValue(Text(isSelected ? "selected" : "not_selected"))
        .onMoveCommand { direction in
            guard direction == .right else { return }
            onMoveToContent?()
        }
    }
}