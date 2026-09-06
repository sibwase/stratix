// CloudLibraryDetailHydrationView.swift
// Defines the cloud library detail hydration view used in the CloudLibrary / Detail surface.
//

import SwiftUI
import StratixCore
import StratixModels

struct CloudLibraryDetailHydrationView: View {
    let titleID: TitleID
    let originRoute: AppRoute
    let viewModel: CloudLibraryViewModel
    let onLaunchStream: (TitleID, String) -> Void
    var onSecondaryAction: (CloudLibraryActionViewState) -> Void = { _ in }

    @Environment(LibraryController.self) private var libraryController
    @Environment(AchievementsController.self) private var achievementsController
    @State private var refreshRequestID = 0

    var body: some View {
        Group {
            if let item = viewModel.cachedItemsByTitleID[titleID] ?? libraryController.itemsByTitleID[titleID] {
                let currentSnapshot = detailSnapshot(for: item)
                let inputSignature = detailInputSignature(for: item)
                let isHydrating = viewModel.detailHydrationInFlightTitleIDs.contains(titleID)
                let activeDetailState = viewModel.detailStateCache.peek(titleID)?.state ?? CloudLibraryDataSource.detailState(from: currentSnapshot)
                CloudLibraryTitleDetailScreen(
                    state: activeDetailState,
                    onPrimaryAction: {
                        onLaunchStream(item.typedTitleID, "detail_primary")
                    },
                    onSecondaryAction: onSecondaryAction,
                    showsAmbientBackground: true,
                    showsHeroArtwork: false,
                    usesOuterPadding: false,
                    interceptExitCommand: false
                )
                .equatable()
                .task(id: inputSignature) {
                    if let entry = viewModel.detailStateCache.peek(titleID),
                       entry.inputSignature == inputSignature {
                        return
                    }
                    await hydrateDetailViewState(for: item)
                }
            } else {
                CloudLibraryStatusPanel(
                    state: .init(
                        kind: .error,
                        title: "Couldn't open title",
                        message: "That game is no longer in the current catalog snapshot.",
                        primaryActionTitle: "Try Again"
                    ),
                    onPrimaryAction: requestLibraryRefresh
                )
            }
        }
        .task(id: refreshRequestID) {
            guard refreshRequestID > 0 else { return }
            await libraryController.refresh(forceRefresh: true, reason: .manualUser)
        }
    }

    // MARK: - Hydration

    private func hydrateDetailViewState(for item: CloudLibraryItem) async {
        await MainActor.run {
            _ = viewModel.detailHydrationInFlightTitleIDs.insert(titleID)
        }
        async let detailTask: Void = libraryController.loadDetail(productID: item.typedProductID)
        async let achievementsTask: Void = achievementsController.loadTitleAchievements(titleID: item.typedTitleID)
        _ = await (detailTask, achievementsTask)
        let snapshot = await MainActor.run { detailSnapshot(for: item) }
        await MainActor.run {
            _ = viewModel.detailHydrationInFlightTitleIDs.remove(titleID)
            viewModel.prewarmDetailState(titleID: titleID, snapshot: snapshot)
        }
    }

    private func requestLibraryRefresh() {
        refreshRequestID += 1
    }

    // MARK: - Cache key

    private func detailSnapshot(for item: CloudLibraryItem) -> CloudLibraryDataSource.DetailStateSnapshot {
        CloudLibraryDataSource.detailSnapshot(
            for: item,
            richDetail: libraryController.productDetail(productID: item.typedProductID),
            achievementSnapshot: achievementsController.titleAchievementSnapshot(titleID: item.typedTitleID),
            achievementErrorText: achievementsController.lastTitleAchievementsError(titleID: item.typedTitleID),
            isHydrating: false,
            previousBaseRoute: originRoute
        )
    }

    private func detailInputSignature(for item: CloudLibraryItem) -> String {
        viewModel.detailInputSignature(for: detailSnapshot(for: item))
    }
}
