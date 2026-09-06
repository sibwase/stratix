// SideRailFocusCoordinator.swift
// Defines the side rail focus coordinator for the Shared / Components surface.
//

import SwiftUI

/// TV-app sidebar row chrome: white capsule on focus, no extra scale or glow.
enum SideRailRowStyle {
    static func foreground(isFocused: Bool, isSelected: Bool) -> Color {
        if isFocused {
            return Color.black
        }
        if isSelected {
            return Color.white
        }
        return Color.white.opacity(0.72)
    }

    static func fill(isFocused: Bool, isSelected: Bool) -> Color {
        if isFocused {
            return Color.white
        }
        if isSelected {
            return Color.white.opacity(0.14)
        }
        return Color.clear
    }
}

/// Focus destinations the side rail can own directly across account, nav, and trailing action rows.
enum SideRailFocusTarget: Hashable {
    case account
    case nav(SideRailNavID)
    case action(String)
}

/// Shared ordering and focus-entry rules for the side rail so the view layer stays mostly declarative.
enum SideRailFocusCoordinator {
    private static let preferredNavOrder: [SideRailNavID] = [.library, .consoles]

    /// Reorders nav items into the canonical shell order even if the source state arrives unsorted.
    static func orderedNavItems(from navItems: [SideRailNavItemViewState]) -> [SideRailNavItemViewState] {
        guard !navItems.isEmpty else { return [] }
        var ordered: [SideRailNavItemViewState] = []
        ordered.reserveCapacity(preferredNavOrder.count)
        var seen = Set<SideRailNavID>()
        for id in preferredNavOrder {
            if let item = navItems.first(where: { $0.id == id }) {
                ordered.append(item)
                seen.insert(id)
            }
        }
        for item in navItems where !seen.contains(item.id) {
            ordered.append(item)
        }
        return ordered
    }

    /// Returns trailing rail actions as provided by shell state without injecting defaults.
    static func trailingActions(from actions: [SideRailActionViewState]) -> [SideRailActionViewState] {
        actions
    }

    /// Chooses the focus destination when the rail expands from content entry.
    static func preferredEntryTarget(
        activeUtilityRoute: ShellUtilityRoute?,
        trailingActions: [SideRailActionViewState],
        selectedNavID: SideRailNavID
    ) -> SideRailFocusTarget {
        if let activeUtilityRoute {
            switch activeUtilityRoute {
            case .profile:
                return .account
            case .settings:
                if trailingActions.contains(where: { $0.id == "settings" }) {
                    return .action("settings")
                }
                return .account
            }
        }
        return .nav(selectedNavID)
    }

    /// Limits collapsed-rail focus to the selected nav row when that mode is enabled.
    static func isCollapsedFocusable(
        _ target: SideRailFocusTarget,
        selectedNavID: SideRailNavID,
        collapsedSelectedNavFocusable: Bool
    ) -> Bool {
        guard collapsedSelectedNavFocusable else { return false }
        if case .nav(let id) = target {
            return id == selectedNavID
        }
        return false
    }
}

extension SideRailNavigationView {
    var orderedNavItems: [SideRailNavItemViewState] {
        SideRailFocusCoordinator.orderedNavItems(from: state.navItems)
    }

    var trailingActions: [SideRailActionViewState] {
        SideRailFocusCoordinator.trailingActions(from: state.trailingActions)
    }

    var preferredEntryTarget: SideRailFocusTarget {
        SideRailFocusCoordinator.preferredEntryTarget(
            activeUtilityRoute: activeUtilityRoute,
            trailingActions: trailingActions,
            selectedNavID: selectedNavID
        )
    }

    var firstExpandedNavID: SideRailNavID? {
        orderedNavItems.first?.id
    }

    var lastExpandedNavID: SideRailNavID? {
        orderedNavItems.last?.id
    }

    var firstActionID: String? {
        trailingActions.first?.id
    }

    var lastActionID: String? {
        trailingActions.last?.id
    }

    /// Hands focus back to content and collapses the rail in one place so callers do not forget either step.
    func moveFocusToContent() {
        onMoveFromSideRailToContent?()
        collapseRail()
    }

    /// Expands the rail and schedules focus after the state change has been committed by SwiftUI.
    func expandRailAndFocusPreferredTarget() {
        guard !forceCollapsed else { return }
        didExplicitlyEnterRail = true
        if !isExpanded.wrappedValue {
            isExpanded.wrappedValue = true
        }
        scheduleRailFocus {
            focusedTarget = preferredEntryTarget
        }
        onExpansionChanged?(true)
    }

    /// Collapses the rail and clears any pending delayed focus hand-off.
    func collapseRail() {
        pendingFocusTask?.cancel()
        focusedTarget = nil
        didExplicitlyEnterRail = false
        if isExpanded.wrappedValue {
            isExpanded.wrappedValue = false
        }
        onExpansionChanged?(false)
    }

    /// Keeps collapsed and expanded focus transitions consistent when tvOS focus changes underneath the rail.
    func handleFocusedTargetChange(_ target: SideRailFocusTarget?) {
        guard !forceCollapsed else {
            focusedTarget = nil
            didExplicitlyEnterRail = false
            isExpanded.wrappedValue = false
            onExpansionChanged?(false)
            return
        }

        guard let target else {
            // Focus left the rail for content: collapse unless we are still landing entry focus.
            if isRailExpanded, !didExplicitlyEnterRail {
                collapseRail()
            } else {
                onExpansionChanged?(isRailExpanded)
            }
            return
        }

        if isRailExpanded {
            if didExplicitlyEnterRail,
               case .nav(let navID) = target,
               navID == selectedNavID {
                NavigationPerformanceTracker.recordRailSelectedRowFocused(
                    surface: surfaceID,
                    target: navID.rawValue
                )
                didExplicitlyEnterRail = false
            }
            onExpansionChanged?(true)
            return
        }

        if SideRailFocusCoordinator.isCollapsedFocusable(
            target,
            selectedNavID: selectedNavID,
            collapsedSelectedNavFocusable: collapsedSelectedNavFocusable
        ) {
            expandRailAndFocusPreferredTarget()
            return
        }

        onExpansionChanged?(false)
    }

    /// Defers focus assignment one runloop so the expanded rail can become focusable first.
    private func scheduleRailFocus(_ updateFocus: @escaping @MainActor () -> Void) {
        MainActorDeferredTask.schedule(task: &pendingFocusTask, updateFocus)
    }
}
