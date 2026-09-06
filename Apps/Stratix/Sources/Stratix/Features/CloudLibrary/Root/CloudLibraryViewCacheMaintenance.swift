// CloudLibraryViewCacheMaintenance.swift
// Defines cloud library view cache maintenance for the CloudLibrary / Root surface.
//

import SwiftUI
import DiagnosticsKit
import StratixCore
import StratixModels

extension CloudLibraryView {
    func triggerDebugQuickLaunch() {
        if let item = stateSnapshot.item(productID: Self.debugQuickLaunchProductID) {
            pendingDebugQuickLaunchProductID = nil
            launchCloudStream(titleId: item.typedTitleID, source: "debug_quick_launch")
            return
        }
        pendingDebugQuickLaunchProductID = Self.debugQuickLaunchProductID
        if !stateSnapshot.isLoading {
            Task { await refreshCloudLibrary(forceRefresh: true) }
        }
    }

    func attemptPendingDebugQuickLaunch() {
        guard let productID = pendingDebugQuickLaunchProductID else { return }
        guard activeStreamContext == nil else { return }
        guard let item = stateSnapshot.item(productID: productID) else { return }
        pendingDebugQuickLaunchProductID = nil
        launchCloudStream(titleId: item.typedTitleID, source: "debug_quick_launch_pending")
    }

    func handleSectionRefresh(oldSections: [CloudLibrarySection], newSections: [CloudLibrarySection]) {
        let majorRefresh = isMajorLibraryRefresh(oldSections: oldSections, newSections: newSections)
        logProjectionDebug(
            "sections_changed major=\(majorRefresh) old=[\(sectionSummary(oldSections))] new=[\(sectionSummary(newSections))] route=\(String(describing: routeState.browseRoute))"
        )
        if majorRefresh {
            vm.detailStateCache.removeAll()
            vm.detailHydrationInFlightTitleIDs.removeAll()
        } else {
            pruneDetailCaches(using: newSections)
        }
        if let scopedCategory = queryState.scopedCategory {
            let availableTitleIDs = CloudLibraryDataSource.allLibraryTitleIDs(from: newSections)
            if scopedCategory.allowedTitleIDs.isDisjoint(with: availableTitleIDs) {
                queryState.scopedCategory = nil
            }
        }
        if !majorRefresh {
            invalidateDetailCacheForChangedInputs()
        }
        sceneModel.noteHydrationMarker(stateSnapshot.lastHydratedAt)
    }

    func logProjectionDebug(_ message: @autoclosure () -> String) {
        guard GLogger.isEnabled else { return }
        Self.uiLogger.info("CloudLibraryView projection: \(message())")
    }

    func logHomeStateTransition(
        oldState: CloudLibraryHomeViewState,
        newState: CloudLibraryHomeViewState
    ) {
        logProjectionDebug(
            "home_state oldCarousel=\(oldState.carouselItems.count) newCarousel=\(newState.carouselItems.count) oldRails=\(oldState.sections.count) newRails=\(newState.sections.count) newCarouselSample=[\(carouselSample(newState.carouselItems))] newRailSummary=[\(railSummary(newState.sections))]"
        )
    }

    func sectionSummary(_ sections: [CloudLibrarySection], limit: Int = 6) -> String {
        sections.prefix(limit)
            .map { "\($0.id):\($0.items.count)" }
            .joined(separator: ", ")
    }

    func carouselSample(_ items: [CloudLibraryHomeCarouselItemViewState], limit: Int = 5) -> String {
        items.prefix(limit)
            .map { "\($0.titleID.rawValue)|\($0.title.replacingOccurrences(of: "\"", with: "'"))" }
            .joined(separator: ", ")
    }

    func railSummary(_ sections: [CloudLibraryRailSectionViewState], limit: Int = 8) -> String {
        sections.prefix(limit)
            .map { "\($0.alias ?? $0.id):\($0.items.count)" }
            .joined(separator: ", ")
    }

    func pruneDetailCaches(using sections: [CloudLibrarySection]) {
        let validTitleIDs = CloudLibraryDataSource.allLibraryTitleIDs(from: sections)
        vm.detailStateCache.prune(validTitleIDs: validTitleIDs)
        vm.detailHydrationInFlightTitleIDs = vm.detailHydrationInFlightTitleIDs.intersection(validTitleIDs)
        focusState.setSettledHeroTileID(
            focusState.settledHeroTileID(for: CloudLibraryBrowseRoute.library).flatMap { validTitleIDs.contains($0) ? $0 : nil },
            for: CloudLibraryBrowseRoute.library
        )
        focusState.focusedTileIDsByRoute = focusState.focusedTileIDsByRoute.filter { validTitleIDs.contains($0.value) }
    }

    func detailInputSignature(for item: CloudLibraryItem) -> String {
        let snapshot = CloudLibraryDataSource.detailSnapshot(
            for: item,
            richDetail: stateSnapshot.productDetail(productID: item.typedProductID),
            achievementSnapshot: achievementsController.titleAchievementSnapshot(titleID: item.typedTitleID),
            achievementErrorText: achievementsController.lastTitleAchievementsError(titleID: item.typedTitleID),
            isHydrating: false,
            previousBaseRoute: .home
        )
        return CloudLibraryDataSource.detailInputSignature(for: snapshot)
    }

    func invalidateDetailCacheForChangedInputs() {
        guard !vm.detailStateCache.isEmpty else { return }

        let invalidatedTitleIDs = vm.detailStateCache.invalidateChangedEntries { titleID in
            guard let item = vm.cachedItemsByTitleID[titleID] else { return nil }
            return detailInputSignature(for: item)
        }
        guard !invalidatedTitleIDs.isEmpty else { return }

        for titleID in invalidatedTitleIDs {
            vm.detailHydrationInFlightTitleIDs.remove(titleID)
        }
    }

    func isMajorLibraryRefresh(oldSections: [CloudLibrarySection], newSections: [CloudLibrarySection]) -> Bool {
        sceneModel.isMajorLibraryRefresh(
            oldSections: oldSections,
            newSections: newSections,
            currentHydratedAt: stateSnapshot.lastHydratedAt
        )
    }
}
