// SideRailFocusCoordinatorTests.swift
// Exercises side rail focus coordinator behavior.
//

import XCTest

#if canImport(Stratix)
@testable import Stratix
#endif

final class SideRailFocusCoordinatorTests: XCTestCase {
    func testTrailingActions_doesNotInjectDefaultSettingsAction() {
        XCTAssertTrue(SideRailFocusCoordinator.trailingActions(from: []).isEmpty)
    }

    func testPreferredEntryTarget_focusesSelectedNavWhenBrowsing() {
        XCTAssertEqual(
            SideRailFocusCoordinator.preferredEntryTarget(
                activeUtilityRoute: nil,
                trailingActions: [.init(id: "settings", systemImage: "gearshape", accessibilityLabel: "Settings")],
                selectedNavID: .library
            ),
            .nav(.library)
        )
    }

    func testOrderedNavItems_appendsUnknownIDsAfterPreferredOrder() {
        let extra = SideRailNavItemViewState(id: .library, title: "Home", systemImage: "house.fill")
        let consoles = SideRailNavItemViewState(id: .consoles, title: "Consoles", systemImage: "tv")

        XCTAssertEqual(
            SideRailFocusCoordinator.orderedNavItems(from: [consoles, extra]).map(\.id),
            [.library, .consoles]
        )
    }

    func testPreferredEntryTarget_focusesProfileActionWhenActive() {
        XCTAssertEqual(
            SideRailFocusCoordinator.preferredEntryTarget(
                activeUtilityRoute: .profile,
                trailingActions: [.init(id: "profile", systemImage: "person", accessibilityLabel: "Profile")],
                selectedNavID: .library
            ),
            .action("profile")
        )
    }

    func testPreferredEntryTarget_focusesUtilityActionWhenActive() {
        XCTAssertEqual(
            SideRailFocusCoordinator.preferredEntryTarget(
                activeUtilityRoute: .settings,
                trailingActions: [.init(id: "settings", systemImage: "gearshape", accessibilityLabel: "Settings")],
                selectedNavID: .library
            ),
            .action("settings")
        )
    }

    func testIsCollapsedFocusable_onlyAllowsSelectedNavWhenEnabled() {
        XCTAssertTrue(
            SideRailFocusCoordinator.isCollapsedFocusable(
                .nav(.library),
                selectedNavID: .library,
                collapsedSelectedNavFocusable: true
            )
        )
        XCTAssertFalse(
            SideRailFocusCoordinator.isCollapsedFocusable(
                .nav(.consoles),
                selectedNavID: .library,
                collapsedSelectedNavFocusable: true
            )
        )
    }
}
