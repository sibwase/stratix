// CloudLibraryLibraryLetterIndexSupportTests.swift
// Exercises library letter-index mapping used while scrolling the game grid.
//

import XCTest
import SwiftUI

#if canImport(Stratix)
@testable import Stratix
#endif

final class CloudLibraryLibraryLetterIndexSupportTests: XCTestCase {
    func testIndexLetterUsesFirstLetterAndBucketsNonLetters() {
        XCTAssertEqual(CloudLibraryLibraryLetterIndexSupport.indexLetter(for: "Halo Infinite"), "H")
        XCTAssertEqual(CloudLibraryLibraryLetterIndexSupport.indexLetter(for: "  avowed"), "A")
        XCTAssertEqual(CloudLibraryLibraryLetterIndexSupport.indexLetter(for: "12 Minutes"), "#")
        XCTAssertEqual(CloudLibraryLibraryLetterIndexSupport.indexLetter(for: "   "), "#")
    }

    func testHighlightedLetterFollowsScrollUntilSettledThenUsesFocusedCard() {
        let sections = ["A", "B", "H", "Z"]

        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
                sections: sections,
                jumpLetter: "H",
                scrollLetter: "B",
                focusedLetter: "A"
            ),
            "H"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
                sections: sections,
                jumpLetter: nil,
                scrollLetter: "B",
                focusedLetter: "A",
                prefersFocusedLetter: false
            ),
            "B"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
                sections: sections,
                jumpLetter: nil,
                scrollLetter: "B",
                focusedLetter: "A",
                prefersFocusedLetter: true
            ),
            "A"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
                sections: sections,
                jumpLetter: nil,
                scrollLetter: nil,
                focusedLetter: "Z"
            ),
            "Z"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.highlightedLetter(
                sections: sections,
                jumpLetter: "Q",
                scrollLetter: "Q",
                focusedLetter: nil
            ),
            "A"
        )
    }

    func testLiveScrollPhaseIsAnyMovingPhase() {
        XCTAssertTrue(CloudLibraryLibraryLetterIndexSupport.isLiveScrollPhase(.tracking))
        XCTAssertTrue(CloudLibraryLibraryLetterIndexSupport.isLiveScrollPhase(.interacting))
        XCTAssertTrue(CloudLibraryLibraryLetterIndexSupport.isLiveScrollPhase(.decelerating))
        XCTAssertFalse(CloudLibraryLibraryLetterIndexSupport.isLiveScrollPhase(.idle))
    }

    func testLetterUsesLeadingEdgeOfScrollDirection() {
        let letters = ["A", "A", "A", "A", "A", "A", "B", "B", "B", "B", "B", "B", "C"]
        let stride: CGFloat = 100
        let header: CGFloat = 200
        let columns = 6

        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.letter(
                visibleMinY: header,
                visibleMaxY: header + 250,
                scrollDelta: 40,
                headerHeight: header,
                rowStride: stride,
                columnCount: columns,
                sectionLetters: letters
            ),
            "C"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.letter(
                visibleMinY: header,
                visibleMaxY: header + 250,
                scrollDelta: -40,
                headerHeight: header,
                rowStride: stride,
                columnCount: columns,
                sectionLetters: letters
            ),
            "A"
        )
    }

    func testLetterForVisibleMidYTracksCurrentRowSection() {
        let letters = ["A", "A", "A", "A", "A", "A", "B", "B", "B", "B", "B", "B", "C"]
        let stride: CGFloat = 100
        let header: CGFloat = 200
        let columns = 6

        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.letter(
                visibleMidY: header + 10,
                headerHeight: header,
                rowStride: stride,
                columnCount: columns,
                sectionLetters: letters
            ),
            "A"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.letter(
                visibleMidY: header + stride + 10,
                headerHeight: header,
                rowStride: stride,
                columnCount: columns,
                sectionLetters: letters
            ),
            "B"
        )
        XCTAssertEqual(
            CloudLibraryLibraryLetterIndexSupport.letter(
                visibleMidY: header + (stride * 2) + 10,
                headerHeight: header,
                rowStride: stride,
                columnCount: columns,
                sectionLetters: letters
            ),
            "C"
        )
    }
}
