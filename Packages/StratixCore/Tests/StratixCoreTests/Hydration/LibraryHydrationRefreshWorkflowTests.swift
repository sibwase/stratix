// LibraryHydrationRefreshWorkflowTests.swift
// Exercises library hydration refresh workflow behavior.
//

import Foundation
@testable import StratixCore
import StratixModels
import Testing
import XCloudAPI

@MainActor
@Suite(.serialized)
struct LibraryHydrationRefreshWorkflowTests {
    @Test
    func run_allowsXHomeTokenWhenXCloudTokenMissing() async {
        let orchestrator = TestLibraryHydrationOrchestrator()
        let snapshot = TestHydrationFixtures.unifiedSnapshot(savedAt: Date())
        orchestrator.liveRefreshResult = TestHydrationFixtures.orchestrationResult(
            publishedState: .cacheRestore(snapshot: snapshot),
            persistenceIntent: .none,
            cachedDiscovery: snapshot.discovery,
            source: .liveRefresh
        )

        let controller = LibraryController(
            refreshWorkflow: nil,
            hydrationOrchestrator: orchestrator
        )
        let coordinator = AppCoordinator()
        let services = AppLibraryControllerServices(
            sessionController: coordinator.sessionController,
            profileController: coordinator.profileController,
            achievementsController: coordinator.achievementsController
        )
        controller.attach(services)
        await coordinator.sessionController.applyTokensFromCoordinator(
            StreamTokens(
                xhomeToken: "xhome-token",
                xhomeHost: "https://xhome.example.com",
                xcloudToken: nil,
                xcloudHost: nil,
                xcloudF2PToken: nil,
                xcloudF2PHost: nil
            ),
            mode: .full
        )

        await LibraryHydrationRefreshWorkflow().run(
            controller: controller,
            reason: .manualUser,
            deferInitialRoutePublication: false
        )

        #expect(orchestrator.liveRefreshCalls == 1)
        #expect(controller.lastError == nil)
        #expect(controller.needsReauth == false)
    }

    @Test
    func run_refreshesTokensWhenNoLibraryCandidatesExist() async {
        let orchestrator = TestLibraryHydrationOrchestrator()
        let snapshot = TestHydrationFixtures.unifiedSnapshot(savedAt: Date())
        orchestrator.liveRefreshResult = TestHydrationFixtures.orchestrationResult(
            publishedState: .cacheRestore(snapshot: snapshot),
            persistenceIntent: .none,
            cachedDiscovery: snapshot.discovery,
            source: .liveRefresh
        )

        let dependencies = TestLibraryControllerDependencies(
            tokens: StreamTokens(
                xhomeToken: "",
                xhomeHost: "https://xhome.example.com",
                xcloudToken: nil,
                xcloudHost: nil,
                xcloudF2PToken: nil,
                xcloudF2PHost: nil
            ),
            refreshedTokens: StreamTokens(
                xhomeToken: "xhome-token",
                xhomeHost: "https://xhome.example.com",
                xcloudToken: "xcloud-token",
                xcloudHost: "https://xcloud.example.com",
                xcloudF2PToken: nil,
                xcloudF2PHost: nil
            )
        )
        let controller = LibraryController(
            refreshWorkflow: nil,
            hydrationOrchestrator: orchestrator
        )
        controller.attach(dependencies)

        await LibraryHydrationRefreshWorkflow().run(
            controller: controller,
            reason: .manualUser,
            deferInitialRoutePublication: false
        )

        #expect(dependencies.refreshCalls == 1)
        #expect(orchestrator.liveRefreshCalls == 1)
        #expect(controller.lastError == nil)
    }
}

@MainActor
final class TestLibraryControllerDependencies: LibraryControllerDependencies {
    var tokens: StreamTokens?
    var refreshedTokens: StreamTokens?
    private(set) var refreshCalls = 0

    init(tokens: StreamTokens?, refreshedTokens: StreamTokens? = nil) {
        self.tokens = tokens
        self.refreshedTokens = refreshedTokens
    }

    func authenticatedLibraryTokens() -> StreamTokens? {
        tokens
    }

    func refreshStreamTokens(logContext: String) async throws -> StreamTokens {
        refreshCalls += 1
        guard let refreshedTokens else { throw AuthError.noStreamToken }
        tokens = refreshedTokens
        return refreshedTokens
    }

    func xboxWebCredentials(logContext: String) async -> XboxWebCredentials? { nil }
    func achievementSnapshot(titleID: TitleID) -> TitleAchievementSnapshot? { nil }
    func loadCurrentUserProfile() async {}
    func loadSocialPeople(maxItems: Int) async {}
}