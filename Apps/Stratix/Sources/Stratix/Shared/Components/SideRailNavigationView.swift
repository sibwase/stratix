// SideRailNavigationView.swift
// Defines the side rail navigation view used in the Shared / Components surface.
//

import SwiftUI

/// Shell side rail container that coordinates account, nav, and action rows while switching
/// between collapsed and expanded rail states.
struct SideRailNavigationView: View {
    let state: SideRailNavigationViewState
    let selectedNavID: SideRailNavID
    var activeUtilityRoute: ShellUtilityRoute? = nil
    let onSelectNav: (SideRailNavID) -> Void
    var onSelectAction: (String) -> Void = { _ in }
    var onMoveFromSideRailToContent: (() -> Void)? = nil
    var surfaceID: String = "game_pass"
    var isExpanded: Binding<Bool> = .constant(false)
    var onExpansionChanged: ((Bool) -> Void)? = nil
    var forceCollapsed: Bool = false
    /// When collapsed, the rail keeps only the selected nav focusable unless callers opt out.
    var collapsedSelectedNavFocusable: Bool = true

    @FocusState var focusedTarget: SideRailFocusTarget?
    @State var didExplicitlyEnterRail = false
    @State var pendingFocusTask: Task<Void, Never>?
    @Namespace private var sidebarMorph

    /// Derived rail mode that ignores external expansion requests while force-collapsed.
    var isRailExpanded: Bool {
        !forceCollapsed && isExpanded.wrappedValue
    }

    private var railWidth: CGFloat {
        isRailExpanded ? StratixTheme.SideRail.railExpandedWidth : StratixTheme.SideRail.railCollapsedWidth
    }

    private var panelWidth: CGFloat {
        isRailExpanded ? StratixTheme.SideRail.panelExpandedWidth : StratixTheme.SideRail.panelCollapsedWidth
    }

    /// The currently selected nav item, used to show the collapsed badge label.
    private var selectedNavItem: SideRailNavItemViewState? {
        state.navItems.first { $0.id == selectedNavID }
    }

    private var collapsedBadgeTitle: String {
        if let activeUtilityRoute {
            switch activeUtilityRoute {
            case .settings:
                return "Settings"
            case .profile:
                return "Profile"
            }
        }
        return selectedNavItem?.title ?? "Home"
    }

    private var collapsedBadgeIcon: String {
        if let activeUtilityRoute {
            switch activeUtilityRoute {
            case .settings:
                return "gearshape.fill"
            case .profile:
                return "person.crop.circle.fill"
            }
        }
        return selectedNavItem?.systemImage ?? "house.fill"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isRailExpanded {
                    expandedPanel
                } else {
                    collapsedBadge
                }
            }
            .background {
                let railCornerRadius = isRailExpanded
                    ? StratixTheme.SideRail.expandedCornerRadius
                    : StratixTheme.SideRail.collapsedCornerRadius
                stratixSidebarGlass(cornerRadius: railCornerRadius)
                    .matchedGeometryEffect(id: "sidebar-glass", in: sidebarMorph, properties: .frame, anchor: .topLeading)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .animation(StratixTheme.SideRail.expandAnimation, value: isRailExpanded)
        .onAppear {
            onExpansionChanged?(isRailExpanded)
        }
        .onChange(of: isExpanded.wrappedValue) { _, expanded in
            handleExpansionRequestChange(expanded)
        }
        .onChange(of: selectedNavID) { _, _ in
            guard !forceCollapsed else { return }
            collapseRail()
        }
        .onChange(of: forceCollapsed) { _, collapsed in
            handleForceCollapsedChange(collapsed)
        }
        .onChange(of: collapsedSelectedNavFocusable) { _, isFocusable in
            guard !isFocusable else { return }
            collapseRail()
        }
        .onChange(of: focusedTarget) { _, target in
            handleFocusedTargetChange(target)
        }
        .onExitCommand {
            if isRailExpanded {
                moveFocusToContent()
            }
        }
    }

    // MARK: - Collapsed badge (Apple TV style non-focusable top-left floating liquid glass section indicator)

    private var collapsedBadge: some View {
        HStack(spacing: 14) {
            Image(systemName: collapsedBadgeIcon)
                .font(.system(size: 24, weight: .semibold))
                .frame(
                    width: StratixTheme.SideRail.collapsedBadgeIconFrame,
                    height: StratixTheme.SideRail.collapsedBadgeIconFrame
                )

            Text(collapsedBadgeTitle)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 22)
        .padding(.vertical, StratixTheme.SideRail.collapsedBadgeVerticalPadding)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(collapsedBadgeTitle))
    }

    // MARK: - Expanded panel (Apple TV floating rounded liquid glass island)

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            accountClusterView

            navListView

            if !trailingActions.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                actionListView
            }
        }
        .padding(StratixTheme.SideRail.horizontalPadding)
        .frame(width: StratixTheme.SideRail.railExpandedWidth, alignment: .topLeading)
        .focusSection()
    }

    private func handleForceCollapsedChange(_ collapsed: Bool) {
        if collapsed {
            focusedTarget = nil
            didExplicitlyEnterRail = false
            isExpanded.wrappedValue = false
        }
        onExpansionChanged?(isRailExpanded)
    }

    /// Applies an external expansion request while preserving the force-collapsed contract.
    private func handleExpansionRequestChange(_ expanded: Bool) {
        guard !forceCollapsed else {
            if expanded {
                isExpanded.wrappedValue = false
            }
            return
        }
        if expanded {
            expandRailAndFocusPreferredTarget()
            return
        }
        collapseRail()
    }
}

#if DEBUG
#Preview("SideRailNavigationView", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack {
        Color.black
        HStack(spacing: 24) {
            SideRailNavigationView(
                state: CloudLibraryPreviewData.sideRail,
                selectedNavID: .library,
                onSelectNav: { _ in },
                isExpanded: .constant(true)
            )
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}
#endif
