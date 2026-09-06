// CloudLibraryDetailPrewarmCoordinator.swift
// Defines the cloud library detail prewarm coordinator for the CloudLibrary / Root surface.
//

import Foundation
import StratixCore
import StratixModels

@MainActor
/// Loads and caches detail projections ahead of navigation so the pushed detail view can render from hot state.
struct CloudLibraryDetailPrewarmCoordinator {
    typealias DetailLoader = @MainActor (ProductID) async -> Void
    typealias AchievementsLoader = @MainActor (TitleID) async -> Void
    typealias DetailLookup = @MainActor (ProductID) -> CloudLibraryProductDetail?
    typealias AchievementLookup = @MainActor (TitleID) -> TitleAchievementSnapshot?
    typealias AchievementErrorLookup = @MainActor (TitleID) -> String?

    /// Reuses a matching hot-cache entry when possible, otherwise performs the full detail and achievements warmup.
    func prewarmDetailState(
        titleID: TitleID,
        item: CloudLibraryItem,
        originRoute: AppRoute,
        viewModel: CloudLibraryViewModel,
        loadDetail: DetailLoader,
        loadAchievements: AchievementsLoader,
        productDetail: DetailLookup,
        achievementSnapshot: AchievementLookup,
        achievementErrorText: AchievementErrorLookup
    ) async {
        let initialSnapshot = makeDetailSnapshot(
            item: item,
            originRoute: originRoute,
            productDetail: productDetail(item.typedProductID),
            achievementSnapshot: achievementSnapshot(titleID),
            achievementErrorText: achievementErrorText(titleID),
            isHydrating: false
        )
        let initialSignature = detailInputSignature(for: initialSnapshot)

        if viewModel.detailStateCache.peek(titleID) == nil {
            let initialDetailState = CloudLibraryDataSource.detailState(from: initialSnapshot)
            viewModel.detailStateCache.insert(
                state: initialDetailState,
                for: titleID,
                inputSignature: initialSignature
            )
        }

        if let entry = viewModel.detailStateCache.peek(titleID),
           entry.inputSignature == initialSignature,
           productDetail(item.typedProductID) != nil {
            viewModel.detailStateCache.touch(titleID)
            return
        }

        viewModel.detailHydrationInFlightTitleIDs.insert(titleID)
        defer {
            viewModel.detailHydrationInFlightTitleIDs.remove(titleID)
        }

        async let detailTask: Void = loadDetail(item.typedProductID)
        async let achievementsTask: Void = loadAchievements(titleID)
        _ = await (detailTask, achievementsTask)

        let finalSnapshot = makeDetailSnapshot(
            item: item,
            originRoute: originRoute,
            productDetail: productDetail(item.typedProductID),
            achievementSnapshot: achievementSnapshot(titleID),
            achievementErrorText: achievementErrorText(titleID),
            isHydrating: false
        )
        let finalSignature = detailInputSignature(for: finalSnapshot)
        let detailState = CloudLibraryDataSource.detailState(from: finalSnapshot)
        viewModel.detailStateCache.insert(
            state: detailState,
            for: titleID,
            inputSignature: finalSignature
        )
    }

    /// Captures the current detail inputs in the shape expected by the data-source projection layer.
    func makeDetailSnapshot(
        item: CloudLibraryItem,
        originRoute: AppRoute,
        productDetail: CloudLibraryProductDetail?,
        achievementSnapshot: TitleAchievementSnapshot?,
        achievementErrorText: String?,
        isHydrating: Bool
    ) -> CloudLibraryDataSource.DetailStateSnapshot {
        CloudLibraryDataSource.detailSnapshot(
            for: item,
            richDetail: productDetail,
            achievementSnapshot: achievementSnapshot,
            achievementErrorText: achievementErrorText,
            isHydrating: isHydrating,
            previousBaseRoute: originRoute
        )
    }

    /// Produces a stable cache key from the detail inputs that materially affect rendered detail state.
    func detailInputSignature(for snapshot: CloudLibraryDataSource.DetailStateSnapshot) -> String {
        CloudLibraryDataSource.detailInputSignature(for: snapshot)
    }
}
