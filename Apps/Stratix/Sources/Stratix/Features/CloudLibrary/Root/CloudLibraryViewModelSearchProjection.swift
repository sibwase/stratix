// CloudLibraryViewModelSearchProjection.swift
// Defines cloud library view model search projection for the CloudLibrary / Root surface.
//

import StratixCore
import StratixModels

@MainActor
extension CloudLibraryViewModel {
    func searchBrowseContentToken(
        catalogRevision: UInt64,
        detailRevision: UInt64,
        sceneContentRevision: UInt64,
        showsContinueBadge: Bool
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(sceneContentRevision)
        hasher.combine(catalogRevision)
        hasher.combine(detailRevision)
        hasher.combine(showsContinueBadge)
        return hasher.finalize()
    }

    func searchResultProjectionToken(
        browseContentToken: Int,
        queryState: LibraryQueryState
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(browseContentToken)
        hasher.combine(queryState.mutationToken(includingLibrarySearchActive: true))
        return hasher.finalize()
    }

    func updateSearchTileLookup(
        browseItems: [MediaTileViewState],
        resultItems: [MediaTileViewState]
    ) {
        var tilePairs: [(TitleID, MediaTileViewState)] = []
        tilePairs.reserveCapacity(browseItems.count + resultItems.count)
        tilePairs.append(contentsOf: browseItems.map { ($0.titleID, $0) })
        tilePairs.append(contentsOf: resultItems.map { ($0.titleID, $0) })

        let newSearchTileLookup = Dictionary(
            tilePairs,
            uniquingKeysWith: { current, _ in current }
        )
        if newSearchTileLookup != cachedSearchTileLookup {
            cachedSearchTileLookup = newSearchTileLookup
        }
        updateCombinedLibraryTileLookup()
    }

    func rebuildSearchProjection(
        using index: CloudLibraryDataSource.PreparedLibraryIndex,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail],
        catalogRevision: UInt64,
        detailRevision: UInt64,
        sceneContentRevision: UInt64,
        queryState: LibraryQueryState,
        showsContinueBadge: Bool
    ) {
        let browseContentToken = searchBrowseContentToken(
            catalogRevision: catalogRevision,
            detailRevision: detailRevision,
            sceneContentRevision: sceneContentRevision,
            showsContinueBadge: showsContinueBadge
        )
        let resultProjectionToken = searchResultProjectionToken(
            browseContentToken: browseContentToken,
            queryState: queryState
        )
        let browseNeedsRebuild = browseContentToken != lastSearchBrowseProjectionToken
        let resultNeedsRebuild = resultProjectionToken != lastSearchProjectionToken
        guard browseNeedsRebuild || resultNeedsRebuild else { return }

        if browseNeedsRebuild {
            lastSearchBrowseProjectionToken = browseContentToken

            let browseItems = orderedPortraitSearchTiles(from: index.allItems)
            if browseItems != cachedSearchBrowseItems {
                cachedSearchBrowseItems = browseItems
            }

            let searchHeroURL = index.featuredItem?.heroImageURL ?? index.featuredItem?.artURL
            if searchHeroURL != cachedSearchHeroURL {
                cachedSearchHeroURL = searchHeroURL
            }
        }

        if resultNeedsRebuild {
            lastSearchProjectionToken = resultProjectionToken

            let rawSearchQuery = queryState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSearchQuery = rawSearchQuery.count >= 2 ? rawSearchQuery : ""
            let resultItems: [MediaTileViewState]
            if trimmedSearchQuery.isEmpty {
                _ = searchDocumentsIfNeeded(
                    using: index,
                    productDetailsByProductID: productDetailsByProductID,
                    catalogRevision: catalogRevision,
                    detailRevision: detailRevision,
                    queryRequiresSearchDocuments: false
                )
                resultItems = []
            } else {
                let searchDocuments = searchDocumentsIfNeeded(
                    using: index,
                    productDetailsByProductID: productDetailsByProductID,
                    catalogRevision: catalogRevision,
                    detailRevision: detailRevision,
                    queryRequiresSearchDocuments: true
                )
                resultItems = orderedPortraitSearchTiles(
                    from: CloudLibraryDataSource.searchResultItems(
                        index: index,
                        queryState: queryState,
                        productDetailsByProductID: productDetailsByProductID,
                        searchDocumentsByTitleID: searchDocuments
                    )
                )
            }
            if resultItems != cachedSearchResultItems {
                cachedSearchResultItems = resultItems
            }
        }

        if browseNeedsRebuild || resultNeedsRebuild {
            updateSearchTileLookup(
                browseItems: cachedSearchBrowseItems,
                resultItems: cachedSearchResultItems
            )
        }
    }

    func rebuildPortraitTileLookup(
        using index: CloudLibraryDataSource.PreparedLibraryIndex,
        catalogRevision: UInt64,
        detailRevision: UInt64,
        sceneContentRevision: UInt64,
        showsContinueBadge: Bool
    ) {
        let token = searchBrowseContentToken(
            catalogRevision: catalogRevision,
            detailRevision: detailRevision,
            sceneContentRevision: sceneContentRevision,
            showsContinueBadge: showsContinueBadge
        )
        guard token != lastPortraitTilesToken else { return }
        lastPortraitTilesToken = token

        var portraitTiles: [TitleID: MediaTileViewState] = [:]
        portraitTiles.reserveCapacity(index.allItems.count)
        for item in index.allItems where portraitTiles[item.typedTitleID] == nil {
            if let cachedTile = cachedLibraryTileLookup[item.typedTitleID] {
                portraitTiles[item.typedTitleID] = cachedTile
            } else {
                portraitTiles[item.typedTitleID] = CloudLibraryDataSource.tileState(
                    for: item,
                    aspect: .portrait,
                    showsContinueBadge: showsContinueBadge
                )
            }
        }
        cachedPortraitTilesByTitleID = portraitTiles
    }

    private func orderedPortraitSearchTiles(from items: [CloudLibraryItem]) -> [MediaTileViewState] {
        var tiles: [MediaTileViewState] = []
        tiles.reserveCapacity(items.count)
        for item in items {
            if let tile = cachedPortraitTilesByTitleID[item.typedTitleID] {
                tiles.append(tile)
            }
        }
        return tiles
    }
}