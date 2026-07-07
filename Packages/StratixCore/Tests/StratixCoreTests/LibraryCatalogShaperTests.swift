// LibraryCatalogShaperTests.swift
// Exercises library catalog shaper behavior.
//

import Foundation
@testable import StratixCore
import StratixModels
import Testing
import XCloudAPI

@Suite(.serialized)
struct LibraryCatalogShaperTests {
    @Test
    func makeCloudLibrarySections_keepsEntitledTitleWithoutCatalogMetadata() {
        let title = TitleEntry(
            titleID: TitleID("FORTNITE"),
            productID: ProductID("bt5p2x999vh2"),
            inputs: ["controller"],
            fallbackName: "Fortnite"
        )

        let sections = LibraryShaper.makeCloudLibrarySections(
            titles: [title],
            mruEntries: [],
            productMap: [:],
            titleByProductId: [title.productID: title],
            titleByTitleId: [title.titleID: title],
            productByXCloudTitleId: [:],
            mruProductIds: []
        )

        let libraryItems = LibraryController.allLibraryItems(from: sections)
        #expect(libraryItems.count == 1)
        #expect(libraryItems[0].titleId == "FORTNITE")
        #expect(libraryItems[0].productId == "bt5p2x999vh2")
        #expect(libraryItems[0].name == "Fortnite")
    }

    @Test
    func makeCloudLibrarySections_usesProductIdWhenNoDisplayMetadataExists() {
        let title = TitleEntry(
            titleID: TitleID("title-1"),
            productID: ProductID("product-1"),
            inputs: [],
            fallbackName: nil
        )

        let sections = LibraryShaper.makeCloudLibrarySections(
            titles: [title],
            mruEntries: [],
            productMap: [:],
            titleByProductId: [title.productID: title],
            titleByTitleId: [title.titleID: title],
            productByXCloudTitleId: [:],
            mruProductIds: []
        )

        let libraryItems = LibraryController.allLibraryItems(from: sections)
        #expect(libraryItems.count == 1)
        #expect(libraryItems[0].name == "product-1")
    }

    @Test
    func indexCatalogProducts_mapsSingleBatchResponseToRequestedProductId() throws {
        let product = try makeCatalogProduct(
            productId: "9NBLDIFFERENT",
            title: "Fortnite",
            xCloudTitleId: "FORTNITE"
        )

        var productMap: [String: GamePassCatalogClient.CatalogProduct] = [:]
        var productByXCloudTitleId: [String: GamePassCatalogClient.CatalogProduct] = [:]
        LibraryShaper.indexCatalogProducts(
            [product],
            requestedProductIds: ["bt5p2x999vh2"],
            into: &productMap,
            productByXCloudTitleId: &productByXCloudTitleId
        )

        #expect(productMap["bt5p2x999vh2"]?.ProductTitle == "Fortnite")
        #expect(productByXCloudTitleId["FORTNITE"]?.ProductId == "9NBLDIFFERENT")
    }

    private func makeCatalogProduct(
        productId: String,
        title: String,
        xCloudTitleId: String? = nil
    ) throws -> GamePassCatalogClient.CatalogProduct {
        var payload: [String: Any] = [
            "ProductId": productId,
            "ProductTitle": title
        ]
        if let xCloudTitleId {
            payload["XCloudTitleId"] = xCloudTitleId
        }
        let data = try JSONSerialization.data(withJSONObject: ["Products": [payload]])
        return try JSONDecoder().decode(GamePassCatalogClient.HydrateResponse.self, from: data).Products[0]
    }
}

@Suite(.serialized)
struct LibraryHydrationCatalogStateFallbackNameTests {
    @Test
    func liveFetch_usesSymbolicTitleIdWhenDetailsNameMissing() {
        let catalogState = LibraryHydrationCatalogState.liveFetch(
            primaryTitlesResponse: XCloudTitlesResponse(
                results: [
                    XCloudTitleDTO(
                        titleId: "FORTNITE",
                        details: .init(
                            productId: "bt5p2x999vh2",
                            name: nil,
                            hasEntitlement: true,
                            supportedInputTypes: ["controller"]
                        )
                    )
                ]
            ),
            supplementaryResponses: [],
            mruResponse: XCloudTitlesResponse(results: []),
            existingSections: []
        )

        #expect(catalogState.titles.count == 1)
        #expect(catalogState.titles[0].fallbackName == "Fortnite")
    }
}