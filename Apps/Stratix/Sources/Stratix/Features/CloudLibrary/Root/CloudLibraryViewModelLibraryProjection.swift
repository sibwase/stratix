// CloudLibraryViewModelLibraryProjection.swift
// Defines cloud library view model library projection for the CloudLibrary / Root surface.
//

import StratixCore
import StratixModels

@MainActor
extension CloudLibraryViewModel {
    func rebuildLibraryProjection(
        using index: CloudLibraryDataSource.PreparedLibraryIndex,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail],
        catalogRevision: UInt64,
        detailRevision: UInt64,
        homeRevision: UInt64,
        sceneContentRevision: UInt64,
        queryState: LibraryQueryState,
        showsContinueBadge: Bool
    ) {
        var hasher = Hasher()
        hasher.combine(sceneContentRevision)
        hasher.combine(catalogRevision)
        hasher.combine(detailRevision)
        hasher.combine(homeRevision)
        hasher.combine(queryState.mutationToken(includingLibrarySearchActive: true))
        hasher.combine(showsContinueBadge)
        let projectionToken = hasher.finalize()
        guard projectionToken != lastLibraryProjectionToken else { return }
        lastLibraryProjectionToken = projectionToken

        let rawSearchQuery = queryState.isLibrarySearchActive
            ? queryState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let trimmedSearchQuery = rawSearchQuery.count >= 2 ? rawSearchQuery : ""
        let searchDocuments = searchDocumentsIfNeeded(
            using: index,
            productDetailsByProductID: productDetailsByProductID,
            catalogRevision: catalogRevision,
            detailRevision: detailRevision,
            queryRequiresSearchDocuments: !trimmedSearchQuery.isEmpty
        )

        let newLibraryState = CloudLibraryDataSource.libraryState(
            index: index,
            queryState: queryState,
            productDetailsByProductID: productDetailsByProductID,
            searchDocumentsByTitleID: searchDocuments,
            showsContinueBadge: showsContinueBadge
        )
        if newLibraryState != cachedLibraryState {
            cachedLibraryState = newLibraryState
        }

        applyLibraryTileLookup(from: newLibraryState)
    }

    private func applyLibraryTileLookup(from libraryState: CloudLibraryLibraryViewState) {
        var libraryTilePairs: [(TitleID, MediaTileViewState)] = []
        libraryTilePairs.reserveCapacity(libraryState.gridItems.count)
        for item in libraryState.gridItems {
            libraryTilePairs.append((item.titleID, item))
        }
        let newLibraryTileLookup = Dictionary(
            libraryTilePairs,
            uniquingKeysWith: { current, _ in current }
        )
        if newLibraryTileLookup != cachedLibraryTileLookup {
            cachedLibraryTileLookup = newLibraryTileLookup
        }
        updateCombinedLibraryTileLookup()
    }
}