// CloudLibraryLayoutPolicyTests.swift
// Exercises cloud library layout policy behavior.
//

import XCTest

#if canImport(Stratix)
@testable import Stratix
#endif

final class CloudLibraryLayoutPolicyTests: XCTestCase {
    func testLibraryRouteUsesBrowseSpacing() {
        let policy = CloudLibraryLayoutPolicy()

        XCTAssertEqual(
            policy.shellContentHorizontalPadding(browseRoute: .library, utilityRoute: nil),
            StratixTheme.Layout.outerPadding
        )
        XCTAssertEqual(
            policy.shellContentTopPadding(browseRoute: .library, utilityRoute: nil),
            StratixTheme.Shell.contentTopPadding
        )
        XCTAssertEqual(
            policy.shellContentLeadingAdjustment(browseRoute: .library, utilityRoute: nil),
            StratixTheme.Shell.browseRouteLeadingInset
        )
    }

    func testUtilityAndConsoleRoutesOverrideBrowseSpacingToZero() {
        let policy = CloudLibraryLayoutPolicy()

        XCTAssertEqual(
            policy.shellContentHorizontalPadding(browseRoute: .library, utilityRoute: .settings),
            0
        )
        XCTAssertEqual(
            policy.shellContentTopPadding(browseRoute: .library, utilityRoute: .settings),
            0
        )
        XCTAssertEqual(
            policy.shellContentLeadingAdjustment(browseRoute: .library, utilityRoute: .settings),
            0
        )
        XCTAssertEqual(
            policy.shellContentHorizontalPadding(browseRoute: .consoles, utilityRoute: nil),
            0
        )
        XCTAssertEqual(
            policy.shellContentTopPadding(browseRoute: .consoles, utilityRoute: nil),
            0
        )
        XCTAssertEqual(
            policy.shellContentLeadingAdjustment(browseRoute: .consoles, utilityRoute: nil),
            0
        )
    }
}
