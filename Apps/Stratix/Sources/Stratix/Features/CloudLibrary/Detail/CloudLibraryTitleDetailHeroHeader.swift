// CloudLibraryTitleDetailHeroHeader.swift
// Defines cloud library title detail hero header for the CloudLibrary / Detail surface.
//

import SwiftUI
import StratixCore

extension MetacriticRating {
    var scoreColor: Color {
        if score >= 75 {
            return Color(red: 84 / 255, green: 176 / 255, blue: 56 / 255)
        } else if score >= 50 {
            return Color(red: 232 / 255, green: 180 / 255, blue: 44 / 255)
        } else {
            return Color(red: 215 / 255, green: 65 / 255, blue: 65 / 255)
        }
    }
}

extension CloudLibraryTitleDetailScreen {
    /// Span from the leading edge of column 1 through the trailing edge of column 6 in the library grid.
    var contentGridSpanWidth: CGFloat {
        let columns = CGFloat(StratixTheme.Library.gridColumnCount)
        let itemWidth = StratixTheme.Library.gridItemWidth
        let spacing = StratixTheme.Library.gridItemSpacing
        return columns * itemWidth + max(0, columns - 1) * spacing
    }

    var heroHeader: some View {
        let leftColumnWidth: CGFloat = 620

        return heroInfo(leftColumnWidth: leftColumnWidth)
            .padding(.leading, 6)
            .padding(.top, StratixTheme.SideRail.collapsedBadgeHeight + StratixTheme.Library.headerBelowBadgeSpacing + 10)
            .padding(.bottom, StratixTheme.Detail.contentSectionSpacing)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: heroHeight, alignment: .topLeading)
    }

    func inlineActionBar(maxWidth: CGFloat) -> some View {
        Group {
            if !allActions.isEmpty {
                ActionButtonBar(
                    actions: allActions,
                    onSelect: handle,
                    defaultFocusActionID: state.primaryAction.id,
                    defaultFocusNamespace: detailPrimaryActionNamespace
                )
                .focusScope(detailPrimaryActionNamespace)
                .frame(maxWidth: maxWidth, alignment: .center)
            }
        }
    }

    var allActions: [CloudLibraryActionViewState] {
        [state.primaryAction]
    }

    func handle(_ action: CloudLibraryActionViewState) {
        guard action.id != state.primaryAction.id else {
            onPrimaryAction()
            return
        }
        onSecondaryAction(action)
    }

    func heroInfo(leftColumnWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 36) {
            poster

            // Left Column: Game Title & Controls
            VStack(alignment: .leading, spacing: 14) {
                if let contextLabel = state.contextLabel, !contextLabel.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(contextLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(StratixTheme.Colors.textMuted)
                }

                Text(state.title)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = state.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !state.capabilityChips.isEmpty {
                    ChipGroupView(chips: state.capabilityChips)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ratingPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .frame(width: leftColumnWidth, alignment: .leading)

            // Right Column: About Section
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                let aboutText = (metacriticRating?.summaryDescription?.isEmpty == false ? metacriticRating?.summaryDescription : nil)
                    ?? (state.descriptionText?.isEmpty == false ? state.descriptionText : nil)

                if let aboutText {
                    Text(aboutText)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else {
                    Text("Additional metadata is still loading for this title.")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.2), value: metacriticRating?.summaryDescription)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .focusSection()
    }

    var poster: some View {
        let posterURL = state.posterImageURL ?? state.heroImageURL

        return ZStack(alignment: .bottom) {
            CachedRemoteImage(
                url: posterURL,
                kind: .poster,
                maxPixelSize: 900,
                onImageLoaded: {
                    if let posterURL {
                        markMediaReady(mediaReadinessKey(.poster(posterURL)))
                    }
                }
            ) {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                }
            }
            .frame(width: heroPosterWidth, height: heroPosterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            // Vignette gradient at bottom of poster so button stands out
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .allowsHitTesting(false)

            // Play button placed on bottom center of poster
            inlineActionBar(maxWidth: heroPosterWidth - 24)
                .padding(.bottom, 22)
        }
        .frame(width: heroPosterWidth, height: heroPosterHeight)
        .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 16)
    }

    var ratingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rating & info")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

            if let rating = state.ratingText, !rating.isEmpty {
                Text(rating)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
            }

            if let legal = state.legalText, !legal.isEmpty {
                Text(legal)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let rating = metacriticRating {
                metacriticBadge(rating: rating)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: metacriticRating)
    }

    @ViewBuilder
    func metacriticBadge(rating: MetacriticRating) -> some View {
        HStack(spacing: 12) {
            Text("\(rating.score)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(rating.scoreColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: rating.scoreColor.opacity(0.35), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Metascore")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                if let count = rating.reviewCount, count > 0 {
                    Text("Based on \(count) critic reviews")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                } else {
                    Text("Metacritic")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                }
            }
        }
        .padding(.top, 4)
    }
}