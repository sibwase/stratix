// CloudLibraryDataSourceLibraryIndex.swift
// Defines cloud library data source library index for the CloudLibrary / CloudLibraryDataSource surface.
//

import Foundation
import StratixCore
import StratixModels

extension CloudLibraryDataSource {
    private static func sectionsByID(_ sections: [CloudLibrarySection]) -> [String: CloudLibrarySection] {
        var lookup: [String: CloudLibrarySection] = [:]
        lookup.reserveCapacity(sections.count)
        for section in sections {
            lookup[section.id] = section
        }
        return lookup
    }

    /// Builds the reusable library index shared by the home, library, search, and detail projection layers.
    static func prepareIndex(
        sections: [CloudLibrarySection],
        merchandising: HomeMerchandisingSnapshot?,
        productDetailsByProductID: [ProductID: CloudLibraryProductDetail] = [:]
    ) -> PreparedLibraryIndex {
        let sectionLookup = sectionsByID(sections)
        let mru = deduplicate(mruItems(from: sections, sectionLookup: sectionLookup))
        let all = allLibraryItems(from: sections, sectionLookup: sectionLookup)
        let featured = mru.first ?? all.first

        var itemsByTitleID: [TitleID: CloudLibraryItem] = [:]
        itemsByTitleID.reserveCapacity(all.count)
        for item in all where itemsByTitleID[item.typedTitleID] == nil {
            itemsByTitleID[item.typedTitleID] = item
        }

        var itemsByProductID: [ProductID: CloudLibraryItem] = [:]
        itemsByProductID.reserveCapacity(all.count)
        for item in all {
            let productID = item.typedProductID
            guard !productID.rawValue.isEmpty, itemsByProductID[productID] == nil else { continue }
            itemsByProductID[productID] = item
        }

        let categories = libraryCategoryDefinitions(
            sections: sections,
            merchandising: merchandising,
            mru: mru
        )

        return PreparedLibraryIndex(
            sections: sections,
            merchandising: merchandising,
            allItems: all,
            mruItems: mru,
            featuredItem: featured,
            itemsByTitleID: itemsByTitleID,
            itemsByProductID: itemsByProductID,
            categoryDefinitions: categories,
            libraryCount: all.count
        )
    }

    /// Returns the MRU subset, preferring the explicit MRU section when one exists.
    static func mruItems(
        from sections: [CloudLibrarySection],
        sectionLookup: [String: CloudLibrarySection]? = nil
    ) -> [CloudLibraryItem] {
        let lookup = sectionLookup ?? sectionsByID(sections)
        if let section = lookup["mru"] {
            return section.items
        }
        if let section = sections.first(where: { $0.name.localizedCaseInsensitiveContains("continue") }) {
            return section.items
        }
        return allLibraryItems(from: sections, sectionLookup: lookup).filter(\.isInMRU)
    }

    /// Returns the canonical library item set, preferring the explicit library section before falling back to every section.
    static func allLibraryItems(
        from sections: [CloudLibrarySection],
        sectionLookup: [String: CloudLibrarySection]? = nil
    ) -> [CloudLibraryItem] {
        if let library = (sectionLookup ?? sectionsByID(sections))["library"] {
            return deduplicate(library.items)
        }
        return deduplicate(sections.flatMap(\.items))
    }

    /// Returns the unique typed title IDs from the canonical library item set without materializing deduplicated items.
    static func allLibraryTitleIDs(
        from sections: [CloudLibrarySection],
        sectionLookup: [String: CloudLibrarySection]? = nil
    ) -> Set<TitleID> {
        if let library = (sectionLookup ?? sectionsByID(sections))["library"] {
            return Set(library.items.map(\.typedTitleID))
        }
        var titleIDs = Set<TitleID>()
        titleIDs.reserveCapacity(sections.reduce(0) { $0 + $1.items.count })
        for section in sections {
            for item in section.items {
                titleIDs.insert(item.typedTitleID)
            }
        }
        return titleIDs
    }

    /// Chooses the best featured item candidate from the live sections.
    static func featuredItem(from sections: [CloudLibrarySection]) -> CloudLibraryItem? {
        mruItems(from: sections).first ?? allLibraryItems(from: sections).first
    }

    /// Returns the precomputed featured item from the prepared index.
    static func featuredItem(from index: PreparedLibraryIndex) -> CloudLibraryItem? {
        index.featuredItem
    }

    /// Builds the filter-chip category definitions that the library screen uses for scoped browsing.
    static func libraryCategoryDefinitions(
        sections _: [CloudLibrarySection],
        merchandising: HomeMerchandisingSnapshot?,
        mru _: [CloudLibraryItem]? = nil
    ) -> [LibraryCategoryDefinition] {
        var definitions: [LibraryCategoryDefinition] = []
        var seenAliases = Set<String>()

        for row in merchandising?.rows ?? [] {
            let titleIDs = Set(row.items.map(\.typedTitleID))
            guard !titleIDs.isEmpty else { continue }
            guard seenAliases.insert(row.alias).inserted else { continue }
            definitions.append(
                LibraryCategoryDefinition(
                    context: LibraryScopedCategoryContext(
                        alias: row.alias,
                        label: row.label,
                        allowedTitleIDs: titleIDs
                    ),
                    systemImage: row.alias == "free-to-play" ? "sparkles.rectangle.stack.fill" : nil
                )
            )
        }

        return definitions
    }

    /// Deduplicates library items by typed title ID while preserving first-seen order.
    static func deduplicate(_ items: [CloudLibraryItem]) -> [CloudLibraryItem] {
        var seen = Set<TitleID>()
        var uniqueItems: [CloudLibraryItem] = []
        uniqueItems.reserveCapacity(items.count)
        for item in items {
            if seen.insert(item.typedTitleID).inserted {
                uniqueItems.append(item)
            }
        }
        return uniqueItems
    }

    /// Deduplicates non-empty strings case-insensitively while preserving display-friendly trimmed values.
    static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueValues: [String] = []
        uniqueValues.reserveCapacity(values.count)
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                uniqueValues.append(trimmed)
            }
        }
        return uniqueValues
    }

    /// Deduplicates URLs by absolute string while preserving first-seen order.
    static func uniqueURLs(_ urls: [URL?]) -> [URL] {
        var seen = Set<String>()
        var uniqueURLs: [URL] = []
        for url in urls.compactMap({ $0 }) {
            if seen.insert(url.absoluteString).inserted {
                uniqueURLs.append(url)
            }
        }
        return uniqueURLs
    }

    /// Deduplicates gallery items by media kind plus URL so image and video entries do not collide.
    static func uniqueGalleryItems(_ items: [CloudLibraryGalleryItemViewState]) -> [CloudLibraryGalleryItemViewState] {
        var seen = Set<String>()
        var uniqueItems: [CloudLibraryGalleryItemViewState] = []
        uniqueItems.reserveCapacity(items.count)
        for item in items {
            let key = "\(item.kind.rawValue):\(item.mediaURL.absoluteString)"
            if seen.insert(key).inserted {
                uniqueItems.append(item)
            }
        }
        return uniqueItems
    }

    /// Builds a short initials string for profile and shell fallbacks.
    static func initials(from name: String) -> String {
        let pieces = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let initials = pieces.joined()
        return initials.isEmpty ? "P" : initials.uppercased()
    }
}
