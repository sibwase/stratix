// LibraryHydrationRefreshWorkflow.swift
// Defines library hydration refresh workflow for the Hydration surface.
//

import Foundation
import StratixModels
import XCloudAPI

@MainActor
struct LibraryHydrationRefreshWorkflow {
    func run(
        controller: LibraryController,
        reason: CloudLibraryRefreshReason,
        deferInitialRoutePublication: Bool
    ) async {
        guard !controller.isSuspendedForStreaming else { return }
        guard let dependencies = controller.dependencies else { return }

        var tokens = dependencies.authenticatedLibraryTokens()
        guard var tokens else { return }

        if !hasUsableLibraryTokens(tokens, controller: controller) {
            controller.hydrationInfo("Cloud library missing stream tokens; attempting refresh before load")
            do {
                tokens = try await dependencies.refreshStreamTokens(logContext: "cloud library token prefetch")
            } catch {
                controller.logger.error(
                    "Cloud library load failed: stream token refresh failed (\(controller.logString(for: error)))"
                )
                if controller.isUnauthorized(error) {
                    controller.apply([
                        .needsReauthSet(true),
                        .errorSet("Your sign-in session expired. Sign in again to reload Game Pass.")
                    ])
                } else {
                    controller.apply([
                        .needsReauthSet(false),
                        .errorSet("Could not refresh stream tokens.")
                    ])
                }
                return
            }
        }

        guard hasUsableLibraryTokens(tokens, controller: controller) else {
            controller.apply([
                .errorSet("Missing stream token."),
                .needsReauthSet(false)
            ])
            controller.logger.error("Cloud library load failed: missing stream token")
            return
        }

        controller.apply([.loadingStarted, .errorSet(nil), .needsReauthSet(false)])
        defer { controller.apply(.loadingFinished) }

        do {
            let result = try await controller.hydrationOrchestrator.performLiveRefresh(
                controller: controller,
                request: controller.makeHydrationRequest(
                    trigger: .liveRefresh,
                    reason: reason,
                    deferInitialRoutePublication: deferInitialRoutePublication
                )
            )
            await controller.applyHydrationOrchestrationResult(result)
            guard !controller.isSuspendedForStreaming else { return }
            controller.hasPerformedNetworkHydrationThisSession = true
        } catch {
            let message = controller.logString(for: error)
            controller.logger.error("Cloud library load failed: \(message)")

            guard controller.isUnauthorized(error) == false else {
                controller.logger.warning("Cloud library unauthorized with cached tokens; attempting silent refresh + retry")
                await retryAfterTokenRefresh(
                    controller: controller,
                    reason: reason,
                    deferInitialRoutePublication: deferInitialRoutePublication
                )
                return
            }

            controller.apply([.needsReauthSet(false), .errorSet(error.localizedDescription)])
        }
    }

    private func hasUsableLibraryTokens(
        _ tokens: StreamTokens,
        controller: LibraryController
    ) -> Bool {
        !controller.makeLibraryTokenCandidates(tokens: tokens).isEmpty
    }

    private func retryAfterTokenRefresh(
        controller: LibraryController,
        reason: CloudLibraryRefreshReason,
        deferInitialRoutePublication: Bool
    ) async {
        do {
            guard let dependencies = controller.dependencies else {
                controller.apply([.needsReauthSet(true), .errorSet("Sign in required.")])
                return
            }
            _ = try await dependencies.refreshStreamTokens(
                logContext: "cloud library retry"
            )
            let result = try await controller.hydrationOrchestrator.performLiveRefresh(
                controller: controller,
                request: controller.makeHydrationRequest(
                    trigger: .liveRefresh,
                    reason: reason,
                    deferInitialRoutePublication: deferInitialRoutePublication
                )
            )
            await controller.applyHydrationOrchestrationResult(result)
            guard !controller.isSuspendedForStreaming else { return }
            controller.apply([.errorSet(nil), .needsReauthSet(false)])
            controller.hasPerformedNetworkHydrationThisSession = true
        } catch {
            controller.logger.error("Cloud library retry after refresh failed: \(controller.logString(for: error))")
            if controller.isUnauthorized(error) {
                controller.apply([
                    .needsReauthSet(true),
                    .errorSet("Your sign-in session expired. Sign in again to reload Game Pass.")
                ])
            } else {
                controller.apply([.needsReauthSet(false), .errorSet(error.localizedDescription)])
            }
        }
    }
}