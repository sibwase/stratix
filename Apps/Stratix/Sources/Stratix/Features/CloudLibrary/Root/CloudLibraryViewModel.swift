// CloudLibraryViewModel.swift
// Defines the cloud library view model.
//

import SwiftUI
import Observation
import DiagnosticsKit
import StratixCore
import StratixModels

// MARK: - ViewModel

/// Owns the projection cache, detail-state hot cache, and prefetch-tracking
/// sets that previously lived as @State in CloudLibraryView. CloudLibraryView
/// reads from this object and calls its mutating methods; it retains
/// responsibility for @FocusState bindings and typed environment wiring.
@Observable
@MainActor
final class CloudLibraryViewModel {
    let logger = GLogger(category: .ui)

    // MARK: - Cached projections (views read these directly)

    var cachedHomeState = CloudLibraryHomeViewState(
        heroBackgroundURL: nil,
        carouselItems: [],
        sections: []
    )
    var cachedLibraryState = CloudLibraryLibraryViewState(
        heroBackdropURL: nil,
        tabs: [
            .init(id: LibraryTabID.myGames, title: "My games"),
            .init(id: LibraryTabID.fullLibrary, title: "Full library")
        ],
        selectedTabID: LibraryTabID.fullLibrary,
        filters: [],
        sortLabel: "Sort A-Z",
        displayMode: .grid,
        gridItems: []
    )
    var cachedSearchBrowseItems: [MediaTileViewState] = []
    var cachedSearchResultItems: [MediaTileViewState] = []
    var cachedSearchHeroURL: URL?
    var cachedHeroBackgroundContext = CloudLibraryHeroBackgroundContext.empty

    // MARK: - Lookup tables (views read these directly)

    var cachedItemsByTitleID: [TitleID: CloudLibraryItem] = [:]
    var cachedItemsByProductID: [ProductID: CloudLibraryItem] = [:]
    var cachedHomeTileLookup: [TitleID: MediaTileViewState] = [:]
    var cachedLibraryTileLookup: [TitleID: MediaTileViewState] = [:]
    var cachedPortraitTilesByTitleID: [TitleID: MediaTileViewState] = [:]
    var cachedSearchTileLookup: [TitleID: MediaTileViewState] = [:]
    var cachedCombinedLibraryTileLookup: [TitleID: MediaTileViewState] = [:]

    // MARK: - Detail-state hot cache (LRU)

    var detailStateCache = DetailStateHotCache(capacity: StratixConstants.Cache.detailHotCacheCapacity)

    // MARK: - Load tracking

    var cachedLibraryCount: Int = 0
    var detailHydrationInFlightTitleIDs: Set<TitleID> = []

    // MARK: - Projection change-detection tokens (no need to publish)

    var preparedIndex: CloudLibraryDataSource.PreparedLibraryIndex?
    var preparedIndexToken: (
        catalogRevision: UInt64,
        detailRevision: UInt64,
        homeRevision: UInt64,
        sceneContentRevision: UInt64
    )?
    var lastLibraryProjectionToken: Int?
    var lastSearchBrowseProjectionToken: Int?
    var lastSearchProjectionToken: Int?
    var lastPortraitTilesToken: Int?

    // MARK: - Deferred search index (built only while search is active)

    var cachedSearchDocumentsByTitleID: [TitleID: String] = [:]
    var cachedSearchDocumentsRevision: (catalogRevision: UInt64, detailRevision: UInt64)?

    // MARK: - Index Maintenance

    /// Reuses the prepared index until one of the library, home, or scene revisions changes.
    func preparedIndexIfNeeded(
        sections: [CloudLibrarySection],
        merchandising: HomeMerchandisingSnapshot?,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail],
        catalogRevision: UInt64,
        detailRevision: UInt64,
        homeRevision: UInt64,
        sceneContentRevision: UInt64
    ) -> (index: CloudLibraryDataSource.PreparedLibraryIndex, fromCache: Bool) {
        let token: (
            catalogRevision: UInt64,
            detailRevision: UInt64,
            homeRevision: UInt64,
            sceneContentRevision: UInt64
        ) = (catalogRevision, detailRevision, homeRevision, sceneContentRevision)
        if let preparedIndex,
           let preparedIndexToken,
           preparedIndexToken.catalogRevision == token.catalogRevision,
           preparedIndexToken.detailRevision == token.detailRevision,
           preparedIndexToken.homeRevision == token.homeRevision,
           preparedIndexToken.sceneContentRevision == token.sceneContentRevision {
            return (preparedIndex, true)
        }

        let nextIndex = CloudLibraryDataSource.prepareIndex(
            sections: sections,
            merchandising: merchandising,
            productDetailsByProductID: productDetailsByProductID
        )
        preparedIndex = nextIndex
        preparedIndexToken = token
        return (nextIndex, false)
    }

    /// Builds or reuses the search document map only while a non-empty search query is active.
    func searchDocumentsIfNeeded(
        using index: CloudLibraryDataSource.PreparedLibraryIndex,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail],
        catalogRevision: UInt64,
        detailRevision: UInt64,
        queryRequiresSearchDocuments: Bool
    ) -> [TitleID: String]? {
        guard queryRequiresSearchDocuments else {
            releaseSearchDocumentsCache()
            return nil
        }

        let revision = (catalogRevision: catalogRevision, detailRevision: detailRevision)
        if let cachedSearchDocumentsRevision,
           cachedSearchDocumentsRevision == revision,
           !cachedSearchDocumentsByTitleID.isEmpty {
            return cachedSearchDocumentsByTitleID
        }

        var documents: [TitleID: String] = [:]
        documents.reserveCapacity(index.allItems.count)
        for item in index.allItems where documents[item.typedTitleID] == nil {
            documents[item.typedTitleID] = CloudLibraryDataSource.searchDocument(
                for: item,
                productDetail: productDetailsByProductID[item.typedProductID]
            )
        }
        cachedSearchDocumentsByTitleID = documents
        cachedSearchDocumentsRevision = revision
        return documents
    }

    private func releaseSearchDocumentsCache() {
        guard !cachedSearchDocumentsByTitleID.isEmpty else { return }
        cachedSearchDocumentsByTitleID.removeAll(keepingCapacity: false)
        cachedSearchDocumentsRevision = nil
    }

    /// Produces a lightweight task token for browse presentation rebuild work without materializing tile lookups.
    func browsePresentationMutationToken(
        loadState: CloudLibraryLoadState,
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState
    ) -> Int {
        var hasher = Hasher()
        _ = focusState
        hasher.combine(loadState)
        hasher.combine(routeState.browseRoute)
        hasher.combine(lastLibraryProjectionToken ?? -1)
        hasher.combine(lastSearchBrowseProjectionToken ?? -1)
        hasher.combine(lastSearchProjectionToken ?? -1)
        hasher.combine(cachedLibraryCount)
        return hasher.finalize()
    }

    /// Merges library and search tile lookups once so browse hosts do not rebuild the combined map per presentation pass.
    func updateCombinedLibraryTileLookup() {
        let nextCombined = CloudLibraryDataSource.combinedLibraryTileLookup(
            libraryTileLookup: cachedLibraryTileLookup,
            searchBrowseItems: cachedSearchBrowseItems,
            searchResultItems: cachedSearchResultItems
        )
        if nextCombined != cachedCombinedLibraryTileLookup {
            cachedCombinedLibraryTileLookup = nextCombined
        }
    }

    // MARK: - Item Lookup

    /// Chooses the best available hero-style artwork URL for the currently focused title.
    func heroCandidateURL(for titleID: TitleID?) -> URL? {
        guard let titleID,
              let item = cachedItemsByTitleID[titleID] else {
            return nil
        }
        return item.heroImageURL ?? item.artURL ?? item.posterImageURL
    }

    /// Rebuilds item lookups from a freshly prepared index to keep title and product lookups aligned with projection inputs.
    func rebuildItemLookup(using index: CloudLibraryDataSource.PreparedLibraryIndex) {
        cachedItemsByTitleID = index.itemsByTitleID
        cachedItemsByProductID = index.itemsByProductID
    }

    // MARK: - Reset

    /// Clears every cached projection and lookup when the signed-in shell session is torn down.
    func resetForSignOut() {
        cachedHomeState = CloudLibraryHomeViewState(heroBackgroundURL: nil, carouselItems: [], sections: [])
        cachedLibraryState = CloudLibraryLibraryViewState(
            heroBackdropURL: nil,
            tabs: [
                .init(id: "my-games", title: "My games"),
                .init(id: "full-library", title: "Full library")
            ],
            selectedTabID: "full-library",
            filters: [],
            sortLabel: "Sort: A-Z",
            displayMode: .grid,
            gridItems: []
        )
        cachedSearchBrowseItems = []
        cachedSearchResultItems = []
        cachedSearchHeroURL = nil
        cachedItemsByTitleID = [:]
        cachedItemsByProductID = [:]
        cachedHomeTileLookup = [:]
        cachedLibraryTileLookup = [:]
        cachedPortraitTilesByTitleID = [:]
        cachedSearchTileLookup = [:]
        cachedCombinedLibraryTileLookup = [:]
        detailStateCache.removeAll()
        cachedLibraryCount = 0
        detailHydrationInFlightTitleIDs = []
        preparedIndex = nil
        preparedIndexToken = nil
        lastLibraryProjectionToken = nil
        lastSearchBrowseProjectionToken = nil
        lastSearchProjectionToken = nil
        lastPortraitTilesToken = nil
        cachedHeroBackgroundContext = .empty
        releaseSearchDocumentsCache()
    }
}
