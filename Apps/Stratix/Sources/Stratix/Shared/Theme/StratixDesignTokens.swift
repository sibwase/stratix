// StratixDesignTokens.swift
// Defines stratix design tokens for the Shared / Theme surface.
//

import SwiftUI

/// Central typography helpers that keep custom scaling behavior consistent across tvOS and
/// Dynamic Type sizes used by the Stratix design system.
enum StratixTypography {
    /// Applies the repo's rounded-system typography with the same Dynamic Type scaling curve
    /// used across shell, library, and detail surfaces.
    static func rounded(
        _ baseSize: CGFloat,
        weight: Font.Weight = .regular,
        dynamicTypeSize: DynamicTypeSize
    ) -> Font {
        .system(size: scaledSize(baseSize, for: dynamicTypeSize), weight: weight, design: .rounded)
    }

    /// Uses the shared Dynamic Type scaling curve for non-rounded system fonts as well.
    static func system(
        _ baseSize: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        dynamicTypeSize: DynamicTypeSize
    ) -> Font {
        .system(size: scaledSize(baseSize, for: dynamicTypeSize), weight: weight, design: design)
    }

    /// Maps tvOS Dynamic Type buckets onto the repo's fixed design-size scale.
    static func scaledSize(_ baseSize: CGFloat, for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let scale: CGFloat
        switch dynamicTypeSize {
        case .xSmall:
            scale = 0.90
        case .small:
            scale = 0.94
        case .medium:
            scale = 0.97
        case .large:
            scale = 1.00
        case .xLarge:
            scale = 1.12
        case .xxLarge:
            scale = 1.22
        case .xxxLarge:
            scale = 1.32
        case .accessibility1:
            scale = 1.40
        case .accessibility2:
            scale = 1.50
        case .accessibility3:
            scale = 1.60
        case .accessibility4:
            scale = 1.72
        case .accessibility5:
            scale = 1.84
        @unknown default:
            scale = 1.00
        }

        return round(baseSize * scale)
    }
}

/// Design-token namespace for shared spacing, sizing, color, and typography constants.
enum StratixTheme {
    enum Spacing {
        static let xxs: CGFloat = 6
        static let xs: CGFloat = 10
        static let sm: CGFloat = 14
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
        static let xl: CGFloat = 40
        static let xxl: CGFloat = 56
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 34
    }

    enum Layout {
        static let maxContentWidth: CGFloat = .greatestFiniteMagnitude
        /// Horizontal inset from the screen edge used by the Apple TV app on 1080p.
        static let screenEdgeInset: CGFloat = 80
        static let outerPadding: CGFloat = 0
        static let sideRailTopInset: CGFloat = 40
        static let heroHeight: CGFloat = 650
        static let tileWidth: CGFloat = 236
        /// Xbox box art is 2:3; keep the card in that ratio so posters are not cropped.
        static let tileHeight: CGFloat = 354
        /// Portrait poster aspect used when the library grid scales tiles to fill six columns.
        static var tileAspect: CGFloat { tileHeight / tileWidth }
    }

    enum Shell {
        static let contentTopPadding: CGFloat = 40
        static let contentBottomPadding: CGFloat = 18
        static let sideRailTopPadding: CGFloat = 40
        static let sideRailLeadingPadding: CGFloat = 24
        static let profileAccountClusterHeight: CGFloat = 48
        /// Fine-tunes profile avatar vertical alignment below the sort-button row center.
        static let profileAccountSortAlignmentExtraInset: CGFloat = 17
        /// Aligns the profile avatar center with the library sort-button row center.
        static let profileAccountSortAlignmentInset: CGFloat = {
            let sortCenterY = contentTopPadding + Library.headerControlsRowCenterY
            let profileCenterY = sideRailTopPadding
                + SideRail.verticalPadding
                + (profileAccountClusterHeight / 2)
            return sortCenterY - profileCenterY + profileAccountSortAlignmentExtraInset
        }()
        static let sideRailBottomPadding: CGFloat = 12
        static let sideRailInsetLeading: CGFloat = 0
        static let sideRailCollapsedPanelWidth: CGFloat = 90
        static let sideRailExpandedPanelWidth: CGFloat = 340
        static let contentGap: CGFloat = 0
        static let contentLeadingInset: CGFloat = 0
        static let browseRouteLeadingInset: CGFloat = Layout.screenEdgeInset
        static let browseRouteTrailingInset: CGFloat = Layout.screenEdgeInset
    }

    enum SideRail {
        static let railCollapsedWidth: CGFloat = 72
        static let railExpandedWidth: CGFloat = 280
        static let panelCollapsedWidth: CGFloat = 90
        static let panelExpandedWidth: CGFloat = 300
        static let iconSize: CGFloat = 22
        static let selectedIconSize: CGFloat = 22
        static let labelSize: CGFloat = 22
        static let rowHeight: CGFloat = 48
        static let rowCornerRadius: CGFloat = 14
        static let expandedCornerRadius: CGFloat = 26
        static let collapsedCornerRadius: CGFloat = 36
        static let collapsedBadgeIconFrame: CGFloat = 30
        static let collapsedBadgeVerticalPadding: CGFloat = 14
        static var collapsedBadgeHeight: CGFloat {
            collapsedBadgeVerticalPadding * 2 + collapsedBadgeIconFrame
        }
        static let verticalPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 12
        static let expandAnimation = Animation.spring(response: 0.34, dampingFraction: 0.88)
        static let rowFocusAnimation = Animation.easeInOut(duration: 0.22)
    }

    enum Home {
        static let tileFocusScale: CGFloat = 0.96
        static let tileUnfocusedScale: CGFloat = 0.912
        static var tileFocusAppliedScale: CGFloat { tileFocusScale }
        /// Gap between poster and title.
        static let tileTitleSpacing: CGFloat = 20
        /// Extra poster-to-title gap while focused, so highlight/shadow does not close the space.
        static let tileTitleFocusSpacing: CGFloat = 18
        /// Fixed title/subtitle block under a portrait tile so rows keep a stable stride.
        static let tileTitleBlockHeight: CGFloat = 86
    }

    enum Library {
        /// Vertical center of the tab/sort header row measured from the library content top edge.
        static let headerControlsRowCenterY: CGFloat = 66
        /// Space under the section chip, relative to chip height.
        static var headerBelowBadgeSpacing: CGFloat { SideRail.collapsedBadgeHeight / 6 }
        /// Library tabs sit below the collapsed section chip, not on the same row.
        static var contentTopPaddingBelowBadge: CGFloat {
            StratixTheme.Shell.sideRailTopPadding + SideRail.collapsedBadgeHeight + headerBelowBadgeSpacing
        }
        /// Compacts the header after removing the shoulder-tab hint row above tabs.
        static let headerTopCompaction: CGFloat = 22
        /// Hides the navigation-stack search field once the library content scrolls past the header.
        static let searchChromeHideContentOffset: CGFloat = 28
        static let sectionSpacing: CGFloat = 24
        static let gridColumnCount: Int = 6
        static let gridItemWidth: CGFloat = 236
        static let gridItemSpacing: CGFloat = 32
        /// Screen-edge inset already matches Apple TV; do not add a second library gutter.
        static let gridEdgeFocusInset: CGFloat = 0
        /// Letter index sits in the trailing screen inset; do not add a second gutter.
        static let trailingChromeGutter: CGFloat = 0
        /// Vertical scroll anchor for focused rows below the first; first row stays pinned to the header.
        static let focusedRowAnchor = UnitPoint(x: 0, y: 0.5)
        /// Matches the collapsed side-rail chip so library titles share its vertical band.
        static let headerControlsRowHeight: CGFloat = 58
        static let headerFilterRowHeight: CGFloat = 52
        static let headerStackSpacing: CGFloat = 18
        /// Extra bottom inset so the last grid rows can sit on the vertical center line.
        static let gridVerticalCenterInset: CGFloat = 220
        static let letterIndexWidth: CGFloat = 28
        /// Matches the collapsed section-chip inset from the screen edge.
        static var letterIndexVerticalInset: CGFloat { StratixTheme.Shell.sideRailTopPadding }
        static let letterIndexTrailingInset: CGFloat = 8
        /// Letter rail lives in the trailing screen gutter, not inside the grid.
        static let letterIndexReservedWidth: CGFloat = 0
        /// Trailing gutter equals the leading inset. The rail starts at that gutter's midpoint.
        static var letterIndexOverlayOffset: CGFloat {
            letterIndexWidth + Layout.screenEdgeInset / 2
        }
        /// D-pad row moves in the library grid.
        static let focusScrollAnimation = Animation.easeOut(duration: 0.32)
        /// Tabs + filter chips used until the live header reports its height.
        static var estimatedHeaderHeight: CGFloat {
            SideRail.collapsedBadgeHeight
                + headerBelowBadgeSpacing
                + headerControlsRowHeight
                + headerStackSpacing
                + headerFilterRowHeight
        }
        static let chipHorizontalPadding: CGFloat = 14
        static let chipVerticalPadding: CGFloat = 10
    }

    enum Detail {
        static let heroHeight: CGFloat = 600
        static let heroPosterWidth: CGFloat = 338
        static let heroPosterHeight: CGFloat = 507
        static let contentSectionSpacing: CGFloat = 28
        static let contentTopPadding: CGFloat = Shell.contentTopPadding
        static let contentBottomPadding: CGFloat = 40
        static let heroSideInset: CGFloat = 0
        static let heroInnerPadding: CGFloat = Layout.screenEdgeInset
        static let heroInterItemSpacing: CGFloat = 28
        static let contentHorizontalInset: CGFloat = 0
        static let browseAlignedLeadingInset: CGFloat = Layout.screenEdgeInset
    }

    enum Colors {
        static let bgTop = Color(red: 0.03, green: 0.06, blue: 0.08)
        static let bgBottom = Color(red: 0.01, green: 0.02, blue: 0.03)
        static let glassFill = Color.white.opacity(0.07)
        static let glassStroke = Color.white.opacity(0.16)
        static let elevatedGlass = Color(red: 0.08, green: 0.12, blue: 0.14).opacity(0.76)
        static let panelFill = Color.black.opacity(0.34)
        static let focusTint = Color(red: 0.72, green: 0.95, blue: 0.34)
        static let accent = Color(red: 0.36, green: 0.82, blue: 0.33)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.75)
        static let textMuted = Color.white.opacity(0.55)
        static let warning = Color.orange
    }

    enum Fonts {
        static let shellTitle = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let nav = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let heroTitle = Font.system(size: 48, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 30, weight: .bold, design: .rounded)
        static let detailTitle = Font.system(size: 50, weight: .heavy, design: .rounded)
        static let cardTitle = Font.system(size: 22, weight: .semibold, design: .rounded)
    }
}
