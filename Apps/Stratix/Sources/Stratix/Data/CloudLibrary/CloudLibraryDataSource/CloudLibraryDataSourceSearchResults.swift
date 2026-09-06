// CloudLibraryDataSourceSearchResults.swift
// Defines cloud library data source search results for the CloudLibrary / CloudLibraryDataSource surface.
//

import Foundation
import StratixCore
import StratixModels

extension CloudLibraryDataSource {
    /// Returns the item set for the currently selected library tab, reusing a prepared index when available.
    static func selectedItemsForCurrentTab(
        sections: [CloudLibrarySection],
        selectedTabID: String
    ) -> [CloudLibraryItem] {
        selectedItemsForCurrentTab(
            index: prepareIndex(sections: sections, merchandising: nil),
            selectedTabID: selectedTabID
        )
    }

    /// Narrows the prepared index down to the active library tab selection.
    static func selectedItemsForCurrentTab(
        index: PreparedLibraryIndex,
        selectedTabID: String
    ) -> [CloudLibraryItem] {
        guard selectedTabID != LibraryTabID.search else { return [] }
        guard selectedTabID == LibraryTabID.myGames, !index.mruItems.isEmpty else { return index.allItems }
        return index.mruItems
    }

    /// Returns the search result set directly from sections when no prepared index is being reused.
    static func searchResultItems(
        sections: [CloudLibrarySection],
        queryState: LibraryQueryState
    ) -> [CloudLibraryItem] {
        searchResultItems(
            index: prepareIndex(sections: sections, merchandising: nil),
            queryState: queryState
        )
    }

    /// Returns the search result set from the prepared index and current query/filter state.
    static func searchResultItems(
        index: PreparedLibraryIndex,
        queryState: LibraryQueryState,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail] = [:],
        searchDocumentsByTitleID: [TitleID: String]? = nil
    ) -> [CloudLibraryItem] {
        let query = queryState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        return applyFiltersAndSort(
            to: index.allItems,
            queryState: queryState,
            searchQuery: query,
            productDetailsByProductID: productDetailsByProductID,
            searchDocumentsByTitleID: searchDocumentsByTitleID
        )
    }

    /// Applies the current search text, category filters, and sort mode to a candidate item set.
    static func applyFiltersAndSort(
        to items: [CloudLibraryItem],
        queryState: LibraryQueryState,
        searchQuery: String,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail] = [:],
        searchDocumentsByTitleID: [TitleID: String]? = nil
    ) -> [CloudLibraryItem] {
        let filteredItems: [CloudLibraryItem]
        if searchQuery.count < 2 {
            filteredItems = items
        } else {
            filteredItems = items.filter { item in
                matchesSearch(
                    item: item,
                    query: searchQuery,
                    productDetailsByProductID: productDetailsByProductID,
                    searchDocumentsByTitleID: searchDocumentsByTitleID
                )
            }
        }

        if searchQuery.count >= 2 {
            return filteredItems.sorted { lhs, rhs in
                let lhsScore = searchMatchScore(item: lhs, query: searchQuery)
                let rhsScore = searchMatchScore(item: rhs, query: searchQuery)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        switch queryState.sortOption {
        case .alphabetical:
            return filteredItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .publisher:
            return filteredItems.sorted {
                let lhsPublisher = $0.publisherName ?? ""
                let rhsPublisher = $1.publisherName ?? ""
                if lhsPublisher.caseInsensitiveCompare(rhsPublisher) == .orderedSame {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhsPublisher.localizedCaseInsensitiveCompare(rhsPublisher) == .orderedAscending
            }
        case .recentlyPlayed:
            return filteredItems.sorted {
                if $0.isInMRU != $1.isInMRU {
                    return $0.isInMRU && !$1.isInMRU
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    /// Relevance scoring for search result ordering.
    static func searchMatchScore(item: CloudLibraryItem, query: String) -> Int {
        let lowerName = item.name.lowercased()
        let lowerQuery = query.lowercased()
        if lowerName == lowerQuery {
            return 100
        }
        if lowerName.hasPrefix(lowerQuery) {
            return 90
        }
        if lowerName.split(separator: " ").contains(where: { $0.hasPrefix(lowerQuery) }) {
            return 80
        }
        if lowerName.contains(lowerQuery) {
            return 70
        }
        if item.publisherName?.lowercased().contains(lowerQuery) == true {
            return 50
        }
        return 30
    }

    /// Primary metadata fields used for targeted short-query matching (names, publishers, genres).
    static func primarySearchText(
        for item: CloudLibraryItem,
        productDetail: CloudLibraryProductDetail? = nil
    ) -> String {
        var parts: [String] = [item.name]
        if let title = productDetail?.title, title != item.name {
            parts.append(title)
        }
        if let pub = item.publisherName {
            parts.append(pub)
        }
        if let dev = productDetail?.developerName {
            parts.append(dev)
        }
        if let genres = productDetail?.genreLabels {
            parts.append(contentsOf: genres)
        }
        if !item.attributes.isEmpty {
            parts.append(contentsOf: item.attributes.map(\.localizedName))
        }
        return parts.joined(separator: " ")
    }

    /// Builds the searchable text blob for one title from catalog metadata and optional rich detail.
    static func searchDocument(
        for item: CloudLibraryItem,
        productDetail: CloudLibraryProductDetail? = nil
    ) -> String {
        var parts: [String] = []
        parts.reserveCapacity(12)
        let values: [String?] = [
            item.name,
            productDetail?.title,
            item.publisherName,
            productDetail?.publisherName,
            productDetail?.developerName,
            item.shortDescription,
            productDetail?.shortDescription,
            productDetail?.longDescription,
            item.attributes.map(\.localizedName).joined(separator: " "),
            productDetail?.genreLabels.joined(separator: " "),
            productDetail?.capabilityLabels.joined(separator: " "),
            item.supportedInputTypes.joined(separator: " ")
        ]
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            parts.append(trimmed)
        }
        return parts.joined(separator: " ")
    }

    /// Matches a query against catalog metadata plus any hydrated product-detail content.
    static func matchesSearch(
        item: CloudLibraryItem,
        query: String,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail] = [:],
        searchDocumentsByTitleID: [TitleID: String]? = nil
    ) -> Bool {
        guard query.count >= 2 else { return false }
        if query.count < 4 {
            let primary = primarySearchText(
                for: item,
                productDetail: productDetailsByProductID[item.typedProductID]
            )
            return primary.localizedStandardContains(query)
        }
        let searchableText: String
        if let precomputed = searchDocumentsByTitleID?[item.typedTitleID] {
            searchableText = precomputed
        } else if let productDetail = productDetailsByProductID[item.typedProductID] {
            searchableText = searchDocument(for: item, productDetail: productDetail)
        } else {
            searchableText = searchDocument(for: item)
        }
        return searchableText.localizedStandardContains(query)
    }
}
