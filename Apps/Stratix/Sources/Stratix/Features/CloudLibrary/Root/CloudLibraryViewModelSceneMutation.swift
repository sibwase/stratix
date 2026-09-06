// CloudLibraryViewModelSceneMutation.swift
// Defines cloud library view model scene mutation for the CloudLibrary / Root surface.
//

import StratixCore
import StratixModels

@MainActor
extension CloudLibraryViewModel {
    func applySceneMutation(inputs: CloudLibrarySceneInputs) {
        let prepared = preparedIndexIfNeeded(
            sections: inputs.library.sections,
            merchandising: inputs.library.homeMerchandising,
            productDetailsByProductID: inputs.library.productDetails,
            catalogRevision: inputs.library.catalogRevision,
            detailRevision: inputs.library.detailRevision,
            homeRevision: inputs.library.homeRevision,
            sceneContentRevision: inputs.library.sceneContentRevision
        )
        let index = prepared.index

        if index.libraryCount != cachedLibraryCount {
            cachedLibraryCount = index.libraryCount
        }
        if !prepared.fromCache {
            rebuildItemLookup(using: index)
        }
        rebuildLibraryProjection(
            using: index,
            productDetailsByProductID: inputs.library.productDetails,
            catalogRevision: inputs.library.catalogRevision,
            detailRevision: inputs.library.detailRevision,
            homeRevision: inputs.library.homeRevision,
            sceneContentRevision: inputs.library.sceneContentRevision,
            queryState: inputs.queryState,
            showsContinueBadge: inputs.showsContinueBadge
        )
        rebuildPortraitTileLookup(
            using: index,
            catalogRevision: inputs.library.catalogRevision,
            detailRevision: inputs.library.detailRevision,
            sceneContentRevision: inputs.library.sceneContentRevision,
            showsContinueBadge: inputs.showsContinueBadge
        )
        rebuildSearchProjection(
            using: index,
            productDetailsByProductID: inputs.library.productDetails,
            catalogRevision: inputs.library.catalogRevision,
            detailRevision: inputs.library.detailRevision,
            sceneContentRevision: inputs.library.sceneContentRevision,
            queryState: inputs.queryState,
            showsContinueBadge: inputs.showsContinueBadge
        )
    }

    func heroBackgroundInputs(
        route: CloudLibrarySceneModel.HeroBackgroundRoute,
        utilityRouteVisible: Bool,
        detailTitleID: TitleID?,
        homeFocusedTitleID: TitleID?,
        libraryFocusedTitleID: TitleID?
    ) -> CloudLibrarySceneModel.HeroBackgroundInputs {
        CloudLibrarySceneModel.HeroBackgroundInputs(
            route: route,
            utilityRouteVisible: utilityRouteVisible,
            detailHeroBackgroundURL: heroCandidateURL(for: detailTitleID),
            homeFocusedHeroBackgroundURL: heroCandidateURL(for: homeFocusedTitleID),
            libraryFocusedHeroBackgroundURL: heroCandidateURL(for: libraryFocusedTitleID),
            homeHeroBackgroundURL: cachedHomeState.heroBackgroundURL,
            libraryHeroBackgroundURL: cachedLibraryState.heroBackdropURL,
            searchHeroBackgroundURL: cachedSearchHeroURL
        )
    }

    func heroBackgroundContext(
        browseRouteRawValue: String,
        utilityRouteVisible: Bool,
        detailTitleID: TitleID?,
        homeFocusedTitleID: TitleID?,
        libraryFocusedTitleID: TitleID?
    ) -> CloudLibraryHeroBackgroundContext {
        let route = (CloudLibraryBrowseRoute(rawValue: browseRouteRawValue) ?? .library).heroBackgroundRoute
        let inputs = heroBackgroundInputs(
            route: route,
            utilityRouteVisible: utilityRouteVisible,
            detailTitleID: detailTitleID,
            homeFocusedTitleID: homeFocusedTitleID,
            libraryFocusedTitleID: libraryFocusedTitleID
        )
        return CloudLibraryHeroBackgroundContext(
            inputs: inputs,
            taskID: CloudLibrarySceneModel.heroBackgroundTaskID(inputs: inputs)
        )
    }

    func heroBackgroundTaskID(
        browseRouteRawValue: String,
        utilityRouteVisible: Bool,
        detailTitleID: TitleID?,
        homeFocusedTitleID: TitleID?,
        libraryFocusedTitleID: TitleID?
    ) -> Int {
        heroBackgroundContext(
            browseRouteRawValue: browseRouteRawValue,
            utilityRouteVisible: utilityRouteVisible,
            detailTitleID: detailTitleID,
            homeFocusedTitleID: homeFocusedTitleID,
            libraryFocusedTitleID: libraryFocusedTitleID
        ).taskID
    }

    func rebuildHeroBackgroundContext(
        browseRouteRawValue: String,
        utilityRouteVisible: Bool,
        detailTitleID: TitleID?,
        homeFocusedTitleID: TitleID?,
        libraryFocusedTitleID: TitleID?
    ) {
        let context = heroBackgroundContext(
            browseRouteRawValue: browseRouteRawValue,
            utilityRouteVisible: utilityRouteVisible,
            detailTitleID: detailTitleID,
            homeFocusedTitleID: homeFocusedTitleID,
            libraryFocusedTitleID: libraryFocusedTitleID
        )
        guard context != cachedHeroBackgroundContext else { return }
        cachedHeroBackgroundContext = context
    }
}
