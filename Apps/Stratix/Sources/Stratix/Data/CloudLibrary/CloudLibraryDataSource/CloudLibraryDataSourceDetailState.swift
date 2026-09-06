// CloudLibraryDataSourceDetailState.swift
// Defines the cloud library data source detail state.
//

import Foundation
import StratixCore
import StratixModels

extension CloudLibraryDataSource {
    /// Packages the current title, rich detail, achievements, and route context into one detail projection snapshot.
    static func detailSnapshot(
        for item: CloudLibraryItem,
        richDetail: CloudLibraryProductDetail?,
        achievementSnapshot: TitleAchievementSnapshot?,
        achievementErrorText: String?,
        isHydrating: Bool,
        previousBaseRoute: AppRoute
    ) -> DetailStateSnapshot {
        DetailStateSnapshot(
            item: item,
            richDetail: richDetail,
            achievementSnapshot: achievementSnapshot,
            achievementErrorText: achievementErrorText,
            isHydrating: isHydrating,
            previousBaseRoute: previousBaseRoute
        )
    }

    /// Produces the stable cache key for detail-state hot-cache entries from the fields that affect rendered detail output.
    static func detailInputSignature(for snapshot: DetailStateSnapshot) -> String {
        var hasher = Hasher()
        let item = snapshot.item
        hasher.combine(item.typedTitleID)
        hasher.combine(item.typedProductID)
        hasher.combine(item.name)
        hasher.combine(item.shortDescription ?? "")
        hasher.combine(item.publisherName ?? "")
        hasher.combine(item.isInMRU)
        hasher.combine(item.attributes.map(\.localizedName).joined(separator: "|"))
        hasher.combine(item.supportedInputTypes.joined(separator: "|"))
        hasher.combine(item.artURL?.absoluteString ?? "")
        hasher.combine(item.posterImageURL?.absoluteString ?? "")
        hasher.combine(item.heroImageURL?.absoluteString ?? "")
        hasher.combine(item.galleryImageURLs.map(\.absoluteString).joined(separator: "|"))
        if let detail = snapshot.richDetail {
            hasher.combine(ProductID(rawValue: detail.productId))
            hasher.combine(detail.title ?? "")
            hasher.combine(detail.publisherName ?? "")
            hasher.combine(detail.shortDescription ?? "")
            hasher.combine(detail.longDescription ?? "")
            hasher.combine(detail.releaseDate ?? "")
            hasher.combine(detail.capabilityLabels.joined(separator: "|"))
            hasher.combine(detail.genreLabels.joined(separator: "|"))
            hasher.combine(detail.galleryImageURLs.map(\.absoluteString).joined(separator: "|"))
            hasher.combine(detail.mediaAssets.map(\.id).joined(separator: "|"))
            hasher.combine(detail.trailers.map(\.id).joined(separator: "|"))
            hasher.combine(detail.achievementSummary?.totalAchievements ?? -1)
            hasher.combine(detail.achievementSummary?.unlockedAchievements ?? -1)
            hasher.combine(detail.achievementSummary?.totalGamerscore ?? -1)
        } else {
            hasher.combine("no-detail")
        }
        if let achievements = snapshot.achievementSnapshot {
            hasher.combine(TitleID(rawValue: achievements.titleId))
            hasher.combine(Int(achievements.fetchedAt.timeIntervalSince1970))
            hasher.combine(achievements.summary.totalAchievements)
            hasher.combine(achievements.summary.unlockedAchievements)
            hasher.combine(achievements.summary.totalGamerscore)
            hasher.combine(achievements.achievements.count)
            for achievement in achievements.achievements.prefix(12) {
                hasher.combine(achievement.id)
                hasher.combine(achievement.unlocked)
                hasher.combine(achievement.percentComplete ?? -1)
                hasher.combine(achievement.gamerscore ?? -1)
            }
        } else {
            hasher.combine("no-achievements")
        }
        hasher.combine(snapshot.achievementErrorText ?? "")
        return String(hasher.finalize())
    }

    /// Projects a detail snapshot into the title-detail view state rendered by the shell.
    static func detailState(from snapshot: DetailStateSnapshot) -> CloudLibraryTitleDetailViewState {
        let item = snapshot.item
        let richDetail = snapshot.richDetail
        let achievementSnapshot = snapshot.achievementSnapshot
        let achievementErrorText = snapshot.achievementErrorText
        let isHydrating = snapshot.isHydrating
        let attributeNames = uniqueStrings(item.attributes.map(\.localizedName) + (richDetail?.capabilityLabels ?? []))
        let genreLabels = richDetail?.genreLabels ?? []
        let trailers = Array((richDetail?.trailers ?? []).prefix(10))
        let canonicalMedia = richDetail?.mediaAssets ?? []
        let canonicalTrailerMedia = canonicalMedia.filter { $0.kind == .video }
        let canonicalScreenshotMedia = canonicalMedia.filter { $0.kind == .image }

        let publisher = richDetail?.publisherName ?? item.publisherName
        let subtitleParts = [publisher, attributeNames.prefix(2).joined(separator: " • ")].compactMap { part -> String? in
            guard let part, !part.isEmpty else { return nil }
            return part
        }

        var capabilityChips: [ChipViewState] = []
        capabilityChips.reserveCapacity(10)
        capabilityChips.append(
            contentsOf: attributeNames.prefix(6).map { name in
                ChipViewState(id: "attr-\(name.lowercased())", label: name)
            }
        )
        capabilityChips.append(
            contentsOf: item.supportedInputTypes.prefix(3).enumerated().map { index, input in
                ChipViewState(id: "input-\(index)-\(input)", label: input, systemImage: "gamecontroller.fill", style: .accent)
            }
        )

        let existingChipLabels = Set(capabilityChips.map { $0.label.lowercased() })
        for genre in genreLabels.prefix(4) where !existingChipLabels.contains(genre.lowercased()) {
            capabilityChips.append(ChipViewState(id: "genre-\(genre.lowercased())", label: genre))
        }

        let releaseLine = richDetail?.releaseDate.flatMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return "Release: \(trimmed)"
        }

        let legalLines = uniqueStrings(
            [item.supportedInputTypes.isEmpty ? nil : "Input: \(item.supportedInputTypes.joined(separator: ", "))", releaseLine]
                .compactMap { $0 }
        )
        let legalText = legalLines.isEmpty ? nil : legalLines.joined(separator: "\n")

        let rawDescription = (richDetail?.shortDescription?.isEmpty == false ? richDetail?.shortDescription : nil)
            ?? (item.shortDescription?.isEmpty == false ? item.shortDescription : nil)
            ?? richDetail?.longDescription

        let descriptionText: String? = {
            guard let text = rawDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return nil
            }
            if let firstParagraph = text.components(separatedBy: "\n\n").first?.trimmingCharacters(in: .whitespacesAndNewlines),
               !firstParagraph.isEmpty, firstParagraph.count > 30 {
                return firstParagraph
            }
            return text
        }()

        let baseBadgeText = item.isInMRU ? "Continue playing" : "Cloud enabled"
        let trailerCountForBadge = max(trailers.count, canonicalTrailerMedia.count)
        let trailerBadgeText: String = {
            guard trailerCountForBadge > 0 else { return baseBadgeText }
            let suffix = trailerCountForBadge == 1 ? "trailer" : "trailers"
            return "\(baseBadgeText) • \(trailerCountForBadge) \(suffix)"
        }()

        var detailPanels: [OverlayPanelViewState] = []

        let fullDescription = (richDetail?.longDescription?.isEmpty == false ? richDetail?.longDescription : nil)
            ?? (richDetail?.shortDescription?.isEmpty == false ? richDetail?.shortDescription : nil)
            ?? (item.shortDescription?.isEmpty == false ? item.shortDescription : nil)
        if let fullDescription, !fullDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            detailPanels.append(
                .init(
                    id: "description",
                    title: "",
                    body: fullDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        if !genreLabels.isEmpty {
            detailPanels.append(
                .init(
                    id: "genres",
                    title: "Genres",
                    body: genreLabels.joined(separator: ", ")
                )
            )
        }

        let screenshotURLs: [URL] = {
            let canonicalScreenshotURLs = uniqueURLs(canonicalScreenshotMedia.map { Optional($0.url) })
            if !canonicalScreenshotURLs.isEmpty { return canonicalScreenshotURLs }

            let richDetailScreenshotURLs = uniqueURLs((richDetail?.galleryImageURLs ?? []).map { Optional($0) })
            if !richDetailScreenshotURLs.isEmpty { return richDetailScreenshotURLs }

            let itemGalleryScreenshotURLs = uniqueURLs(item.galleryImageURLs.map { Optional($0) })
            if !itemGalleryScreenshotURLs.isEmpty { return itemGalleryScreenshotURLs }

            if isHydrating {
                let tileFallbacks = uniqueURLs([item.heroImageURL, item.posterImageURL, item.artURL])
                if !tileFallbacks.isEmpty { return tileFallbacks }
            }
            return []
        }()
        let limitedScreenshotURLs = Array(screenshotURLs.prefix(12))

        let screenshotItems = limitedScreenshotURLs.enumerated().map { index, url in
            CloudLibraryGalleryItemViewState(
                id: "shot-\(index)-\(url.absoluteString)",
                kind: .image,
                mediaURL: url,
                title: "Screenshot \(index + 1)"
            )
        }

        var trailerItems = canonicalTrailerMedia.prefix(3).enumerated().map { index, media in
            let trimmedTitle = media.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackThumbnail: URL? = {
                if let explicit = media.thumbnailURL { return explicit }
                guard !limitedScreenshotURLs.isEmpty else { return nil }
                return limitedScreenshotURLs[abs(index) % limitedScreenshotURLs.count]
            }()
            return CloudLibraryGalleryItemViewState(
                id: "trailer-\(media.url.absoluteString)",
                kind: .video,
                mediaURL: media.url,
                thumbnailURL: fallbackThumbnail,
                title: (trimmedTitle?.isEmpty == false) ? trimmedTitle : "Trailer"
            )
        }
        if trailerItems.isEmpty {
            trailerItems = trailers.prefix(3).enumerated().compactMap { index, trailer -> CloudLibraryGalleryItemViewState? in
                guard let playbackURL = trailer.playbackURL else { return nil }
                let trimmedTitle = trailer.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackThumbnail: URL? = {
                    if let explicit = trailer.thumbnailURL { return explicit }
                    guard !limitedScreenshotURLs.isEmpty else { return nil }
                    return limitedScreenshotURLs[abs(index) % limitedScreenshotURLs.count]
                }()
                return CloudLibraryGalleryItemViewState(
                    id: "trailer-\(playbackURL.absoluteString)",
                    kind: .video,
                    mediaURL: playbackURL,
                    thumbnailURL: fallbackThumbnail,
                    title: trimmedTitle.isEmpty ? "Trailer" : trimmedTitle
                )
            }
        }

        let galleryItems = uniqueGalleryItems(trailerItems + screenshotItems)
        let contextRootLabel = "Game Pass"

        return CloudLibraryTitleDetailViewState(
            id: item.titleId,
            title: richDetail?.title ?? item.name,
            subtitle: subtitleParts.joined(separator: " • "),
            heroImageURL: item.heroImageURL ?? item.artURL,
            posterImageURL: item.posterImageURL ?? item.artURL,
            ratingText: trailerBadgeText,
            legalText: legalText,
            descriptionText: descriptionText,
            primaryAction: .init(id: "play", title: "Play in Cloud", systemImage: "play.fill", style: .primary),
            secondaryActions: [],
            capabilityChips: capabilityChips,
            gallery: galleryItems,
            achievementSummary: achievementSnapshot?.summary ?? richDetail?.achievementSummary,
            achievementItems: achievementSnapshot?.achievements ?? [],
            achievementErrorText: achievementErrorText,
            detailPanels: detailPanels,
            contextLabel: "\(contextRootLabel) > \(richDetail?.title ?? item.name)",
            isHydrating: isHydrating,
            titleID: item.typedTitleID,
            productID: item.typedProductID
        )
    }

    static func detailState(
        for item: CloudLibraryItem,
        richDetail: CloudLibraryProductDetail?,
        achievementSnapshot: TitleAchievementSnapshot?,
        achievementErrorText: String?,
        isHydrating: Bool,
        previousBaseRoute: AppRoute
    ) -> CloudLibraryTitleDetailViewState {
        detailState(
            from: detailSnapshot(
                for: item,
                richDetail: richDetail,
                achievementSnapshot: achievementSnapshot,
                achievementErrorText: achievementErrorText,
                isHydrating: isHydrating,
                previousBaseRoute: previousBaseRoute
            )
        )
    }
}
