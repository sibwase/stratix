// StreamController.swift
// Defines the stream controller.
//

import Foundation
import Observation
import StratixModels
import StreamingCore
import XCloudAPI
import DiagnosticsKit

// MARK: - StreamController

@Observable
@MainActor
public final class StreamController {
    public private(set) var state: StreamState

    public var isReconnecting: Bool { state.isReconnecting }
    public var streamingSession: (any StreamingSessionFacade)? { state.streamingSession }
    public var isStreamOverlayVisible: Bool { state.isStreamOverlayVisible }
    public var currentStreamAchievementSnapshot: TitleAchievementSnapshot? { state.currentStreamAchievementSnapshot }
    public var lastStreamAchievementError: String? { state.lastStreamAchievementError }
    public var launchHeroURL: URL? { state.launchHeroURL }
    public var runtimePhase: StreamRuntimePhase { state.runtimePhase }
    public var shellRestoredAfterStreamExit: Bool { state.shellRestoredAfterStreamExit }
    public var activeRuntimeContext: StreamRuntimeContext? { state.activeRuntimeContext }

    public var isStreamPriorityModeActive: Bool {
        state.runtimePhase != .shellActive
    }

    public var reconnectAttemptCount: Int { state.reconnectAttemptCount }
    public var lastDisconnectIntent: StreamingDisconnectIntent? { state.lastDisconnectIntent }
    public var lastReconnectSuppressionReason: StreamReconnectSuppressionReason? {
        state.lastReconnectSuppressionReason
    }
    public var lastStreamStartFailure: String? { state.lastStreamStartFailure }
    public static var defaultReconnectTotalWindowSeconds: Int {
        StreamReconnectPolicy.defaultTotalRetryWindowSeconds
    }
    public var reconnectTotalWindowSeconds: Int { Self.defaultReconnectTotalWindowSeconds }
    public var showsReconnectControl: Bool {
        guard state.activeLaunchTarget != nil else { return false }
        guard state.lastDisconnectIntent != .userInitiated,
              state.lastDisconnectIntent != .inactivityTimeout else { return false }
        guard !state.isReconnecting else { return false }
        return state.lastReconnectSuppressionReason == .attemptsExhausted
    }

    /// Enables tvOS controller-driven UI focus while launch controls or the stream overlay are active.
    public var allowsStreamControllerUIFocus: Bool {
        if state.isStreamOverlayVisible { return true }
        if showsReconnectControl { return true }
        guard let session = state.streamingSession else {
            return isStreamPriorityModeActive
        }
        switch session.lifecycle {
        case .connected, .disconnecting, .disconnected, .failed:
            return false
        default:
            return true
        }
    }

    @ObservationIgnored private weak var dependencies: (any StreamControllerDependencies)?
    @ObservationIgnored private let logger = GLogger(category: .auth)

    @ObservationIgnored private let overlayController: StreamOverlayController
    @ObservationIgnored private let regionDiagnosticsResolver: StreamRegionDiagnosticsResolver
    @ObservationIgnored private let overlayVisibilityCoordinator: StreamOverlayVisibilityCoordinator
    @ObservationIgnored private let runtimeAttachmentService: StreamRuntimeAttachmentService
    @ObservationIgnored private let priorityModeCoordinator: StreamPriorityModeCoordinator
    @ObservationIgnored private let launchWorkflow: StreamLaunchWorkflow
    @ObservationIgnored private let stopStreamWorkflow: StreamStopWorkflow
    @ObservationIgnored private let streamReconnectCoordinator: StreamReconnectCoordinator
    @ObservationIgnored private let inactivityWatchdog = StreamInactivityWatchdog()
    @ObservationIgnored private var reconnectBridgeProvider: (@MainActor () async -> any WebRTCBridge)?

    @ObservationIgnored private let startHomeWorkflow: (@MainActor (RemoteConsole, any WebRTCBridge) async -> Void)?
    @ObservationIgnored private let startCloudWorkflow: (@MainActor (TitleID, any WebRTCBridge) async -> Void)?
    @ObservationIgnored private let stopWorkflow: (@MainActor () async -> Void)?
    @ObservationIgnored private let overlayVisibilityWorkflow: (@MainActor (Bool) -> Void)?
    @ObservationIgnored private var overlayDismissGuardUntil: ContinuousClock.Instant?
    private let overlayDismissGuardDuration = Duration.milliseconds(750)

    init(
        startHomeWorkflow: (@MainActor (RemoteConsole, any WebRTCBridge) async -> Void)? = nil,
        startCloudWorkflow: (@MainActor (TitleID, any WebRTCBridge) async -> Void)? = nil,
        stopWorkflow: (@MainActor () async -> Void)? = nil,
        overlayVisibilityWorkflow: (@MainActor (Bool) -> Void)? = nil,
        overlayController: StreamOverlayController = StreamOverlayController(),
        overlayInputPolicy: StreamOverlayInputPolicy = StreamOverlayInputPolicy(),
        achievementRefreshCoordinator: StreamAchievementRefreshCoordinator = StreamAchievementRefreshCoordinator(),
        heroArtworkService: StreamHeroArtworkService = StreamHeroArtworkService(),
        launchConfigurationService: StreamLaunchConfigurationService = StreamLaunchConfigurationService(),
        reconnectCoordinator: StreamReconnectCoordinator = StreamReconnectCoordinator(),
        streamSessionLifecycleObserver: StreamSessionLifecycleObserver = StreamSessionLifecycleObserver(),
        regionDiagnosticsResolver: StreamRegionDiagnosticsResolver? = nil,
        initialState: StreamState = .empty
    ) {
        self.startHomeWorkflow = startHomeWorkflow
        self.startCloudWorkflow = startCloudWorkflow
        self.stopWorkflow = stopWorkflow
        self.overlayVisibilityWorkflow = overlayVisibilityWorkflow
        self.overlayController = overlayController
        let regionDiagnosticsResolver = regionDiagnosticsResolver ?? StreamRegionDiagnosticsResolver(
            launchConfigurationService: launchConfigurationService
        )
        let overlayVisibilityCoordinator = StreamOverlayVisibilityCoordinator(
            overlayInputPolicy: overlayInputPolicy,
            achievementRefreshCoordinator: achievementRefreshCoordinator,
            heroArtworkService: heroArtworkService
        )
        let runtimeAttachmentService = StreamRuntimeAttachmentService(
            lifecycleObserver: streamSessionLifecycleObserver
        )
        let priorityModeCoordinator = StreamPriorityModeCoordinator()
        self.regionDiagnosticsResolver = regionDiagnosticsResolver
        self.overlayVisibilityCoordinator = overlayVisibilityCoordinator
        self.runtimeAttachmentService = runtimeAttachmentService
        self.priorityModeCoordinator = priorityModeCoordinator
        let homeLaunchWorkflow = StreamHomeLaunchWorkflow(
            launchConfigurationService: launchConfigurationService,
            overlayVisibilityCoordinator: overlayVisibilityCoordinator,
            runtimeAttachmentService: runtimeAttachmentService,
            priorityModeCoordinator: priorityModeCoordinator
        )
        let cloudLaunchWorkflow = StreamCloudLaunchWorkflow(
            launchConfigurationService: launchConfigurationService,
            overlayVisibilityCoordinator: overlayVisibilityCoordinator,
            runtimeAttachmentService: runtimeAttachmentService,
            priorityModeCoordinator: priorityModeCoordinator
        )
        self.launchWorkflow = StreamLaunchWorkflow(
            homeLaunchWorkflow: homeLaunchWorkflow,
            cloudLaunchWorkflow: cloudLaunchWorkflow
        )
        self.stopStreamWorkflow = StreamStopWorkflow(
            overlayVisibilityCoordinator: overlayVisibilityCoordinator,
            runtimeAttachmentService: runtimeAttachmentService,
            priorityModeCoordinator: priorityModeCoordinator
        )
        self.streamReconnectCoordinator = reconnectCoordinator
        self.state = initialState
    }

    func attach(_ dependencies: any StreamControllerDependencies) {
        self.dependencies = dependencies
    }

    public func registerReconnectBridgeProvider(
        _ provider: (@MainActor () async -> any WebRTCBridge)?
    ) {
        reconnectBridgeProvider = provider
    }

    func apply(_ action: StreamAction) {
        let next = StreamReducer.reduce(state: state, action: action)
        if next != state {
            state = next
        }
    }

    func apply(_ actions: [StreamAction]) {
        guard !actions.isEmpty else { return }
        var next = state
        for action in actions {
            next = StreamReducer.reduce(state: next, action: action)
        }
        if next != state {
            state = next
        }
    }

    public func startHomeStream(console: RemoteConsole, bridge: any WebRTCBridge) async {
        if let startHomeWorkflow {
            await startHomeWorkflow(console, bridge)
        } else {
            await performStartHomeStream(console: console, bridge: bridge)
        }
    }

    public func startCloudStream(titleId: TitleID, bridge: any WebRTCBridge) async {
        if let startCloudWorkflow {
            await startCloudWorkflow(titleId, bridge)
        } else {
            await performStartCloudStream(titleId: titleId, bridge: bridge)
        }
    }

    public func stopStreaming() async {
        if let stopWorkflow {
            await stopWorkflow()
        } else {
            await performStopStreaming(disconnectReason: .userInitiated)
        }
    }

    public func expireAutoReconnectWindow() async {
        await streamReconnectCoordinator.cancelActiveReconnectAttempts()
        apply([.reconnectSuppressed(.attemptsExhausted)])
    }

    public func retryActiveStream(bridge: any WebRTCBridge) async {
        guard let target = state.activeLaunchTarget else { return }
        await streamReconnectCoordinator.reset()
        let detachActions = await detachActionsForRelaunch()
        apply([.reconnectStateReset] + detachActions)
        switch target {
        case .cloud(let titleId):
            await performStartCloudStream(titleId: titleId, bridge: bridge)
        case .home(let consoleId):
            guard
                let console = dependencies?.consoleController.consoles.first(where: { $0.serverId == consoleId })
            else { return }
            await performStartHomeStream(console: console, bridge: bridge)
        }
    }

    public func setOverlayVisible(_ visible: Bool) async {
        await setOverlayVisible(visible, trigger: .automatic)
    }

    public func setOverlayVisible(_ visible: Bool, trigger: StreamOverlayTrigger) async {
        if !visible, shouldIgnoreOverlayDismiss(trigger: trigger) {
            logger.info("Ignoring overlay dismiss during post-open guard window")
            return
        }

        let wasVisible = state.isStreamOverlayVisible

        if let overlayVisibilityWorkflow {
            overlayVisibilityWorkflow(visible)
        } else {
            await performSetOverlayVisible(visible, trigger: trigger)
        }

        if !visible {
            clearOverlayDismissGuard()
        } else if trigger == .userToggle, !wasVisible, state.isStreamOverlayVisible {
            armOverlayDismissGuard()
        }
    }

    public func enterStreamPriorityMode(context: StreamRuntimeContext) async {
        await priorityModeCoordinator.enter(
            context: context,
            state: state,
            environment: makePriorityModeEnvironment(),
            publish: { [weak self] actions in
                self?.apply(actions)
            }
        )
    }

    public func exitStreamPriorityMode() async {
        await priorityModeCoordinator.exit(
            state: state,
            environment: makePriorityModeEnvironment(),
            publish: { [weak self] actions in
                self?.apply(actions)
            }
        )
    }

    public func requestOverlayToggle() {
        overlayController.requestOverlayToggle()
    }

    public func requestDisconnect() {
        overlayController.requestDisconnect()
    }

    public func toggleStatsHUD() {
        overlayController.toggleStatsHUD()
    }

    public func recordStreamUserActivity() {
        inactivityWatchdog.recordActivity()
    }

    public func makeCommandStream() -> AsyncStream<StreamUICommand> {
        overlayController.makeCommandStream()
    }

    public func regionOverrideDiagnostics(for rawValue: String) -> String? {
        regionDiagnosticsResolver.regionOverrideDiagnostics(
            rawValue: rawValue,
            availableRegions: dependencies?.sessionController.xcloudRegions ?? []
        )
    }

    func resetForSignOut() async {
        inactivityWatchdog.stop()
        await overlayVisibilityCoordinator.stopPresentationRefresh()
        await streamReconnectCoordinator.reset()
        overlayController.reset()
        clearOverlayDismissGuard()
        runtimeAttachmentService.reset(
            environment: makeRuntimeAttachmentEnvironment()
        )
        apply([
            .reconnectStateReset,
            .signedOutReset
        ])
    }

    func performStartHomeStream(console: RemoteConsole, bridge: any WebRTCBridge) async {
        guard let dependencies,
              let launchEnvironment = makeLaunchEnvironment(),
              case .authenticated(let tokens) = dependencies.sessionController.authState else { return }
        await launchWorkflow.startHome(
            console: console,
            bridge: bridge,
            state: { [weak self] in self?.state ?? .empty },
            reconnectCoordinator: streamReconnectCoordinator,
            environment: StreamHomeLaunchWorkflowEnvironment(
                launchEnvironment: launchEnvironment,
                runtimeAttachmentEnvironment: makeRuntimeAttachmentEnvironment(),
                priorityModeEnvironment: makePriorityModeEnvironment(),
                logger: logger,
                tokens: tokens,
                updateControllerSettings: { [weak dependencies] in dependencies?.updateControllerSettings() },
                prepareVideoCapabilities: { [weak dependencies] in dependencies?.prepareStreamVideoCapabilitiesIfNeeded() },
                apiSession: dependencies.apiSession(),
                publish: { [weak self] actions in self?.apply(actions) },
                onLifecycleChange: { [weak self] event in
                    Task { @MainActor in
                        await self?.handleLifecycleEvent(event)
                    }
                }
            )
        )
    }

    func performStartCloudStream(titleId: TitleID, bridge: any WebRTCBridge) async {
        guard let dependencies,
              let launchEnvironment = makeLaunchEnvironment(),
              case .authenticated = dependencies.sessionController.authState else {
            logger.error("No xCloud token available")
            return
        }
        await launchWorkflow.startCloud(
            titleId: titleId,
            bridge: bridge,
            state: { [weak self] in self?.state ?? .empty },
            reconnectCoordinator: streamReconnectCoordinator,
            environment: StreamCloudLaunchWorkflowEnvironment(
                launchEnvironment: launchEnvironment,
                runtimeAttachmentEnvironment: makeRuntimeAttachmentEnvironment(),
                priorityModeEnvironment: makePriorityModeEnvironment(),
                overlayEnvironment: makeOverlayEnvironment(
                    activeTitleProvider: { [weak self] in
                        self?.state.activeLaunchTarget?.titleId
                    },
                    shouldContinuePresentationRefresh: { [weak self] in
                        guard let self else { return false }
                        return self.state.isStreamOverlayVisible && self.state.streamingSession != nil
                    },
                    publish: { [weak self] actions in
                        self?.apply(actions)
                    }
                ),
                logger: logger,
                updateControllerSettings: { [weak dependencies] in dependencies?.updateControllerSettings() },
                prepareVideoCapabilities: { [weak dependencies] in dependencies?.prepareStreamVideoCapabilitiesIfNeeded() },
                cloudConnectAuth: { [weak dependencies] in
                    guard let dependencies else { throw APIError.decodingError("Missing stream dependencies") }
                    return try await dependencies.sessionController.cloudConnectAuth(logContext: "cloud stream start")
                },
                setLastAuthError: { [weak dependencies] message in
                    dependencies?.sessionController.setLastAuthError(message)
                },
                cachedHeroURL: { [weak dependencies] requestedTitleId in
                    dependencies?.libraryController.item(titleID: requestedTitleId)?.heroImageURL
                        ?? dependencies?.libraryController.item(titleID: requestedTitleId)?.posterImageURL
                        ?? dependencies?.libraryController.item(titleID: requestedTitleId)?.artURL
                },
                apiSession: dependencies.apiSession(),
                publish: { [weak self] actions in self?.apply(actions) },
                onLifecycleChange: { [weak self] event in
                    Task { @MainActor in
                        await self?.handleLifecycleEvent(event)
                    }
                },
                requestLaunchExit: { [weak self] in
                    self?.requestDisconnect()
                }
            )
        )
    }

    public func beginLaunchInputObservation() {
        dependencies?.inputController.setupLaunchInputObservation()
    }

    func performStopStreaming(disconnectReason: StreamingDisconnectIntent = .userInitiated) async {
        inactivityWatchdog.stop()
        await stopStreamWorkflow.stop(
            state: state,
            reconnectCoordinator: streamReconnectCoordinator,
            environment: StreamStopWorkflowEnvironment(
                runtimeAttachmentEnvironment: makeRuntimeAttachmentEnvironment(),
                priorityModeEnvironment: makePriorityModeEnvironment(),
                publish: { [weak self] actions in self?.apply(actions) }
            ),
            disconnectReason: disconnectReason
        )
    }

    private func shouldIgnoreOverlayDismiss(trigger: StreamOverlayTrigger) -> Bool {
        guard trigger == .userToggle || trigger == .explicitDismiss else { return false }
        guard let overlayDismissGuardUntil else { return false }
        return ContinuousClock.now < overlayDismissGuardUntil
    }

    private func armOverlayDismissGuard() {
        overlayDismissGuardUntil = ContinuousClock.now + overlayDismissGuardDuration
    }

    private func clearOverlayDismissGuard() {
        overlayDismissGuardUntil = nil
    }

    func performSetOverlayVisible(_ visible: Bool, trigger: StreamOverlayTrigger) async {
        let actions = await overlayVisibilityCoordinator.setVisibility(
            visible,
            trigger: trigger,
            state: state,
            environment: makeOverlayEnvironment(
                activeTitleProvider: { [weak self] in
                    self?.state.activeLaunchTarget?.titleId
                },
                shouldContinuePresentationRefresh: { [weak self] in
                    guard let self else { return false }
                    return self.state.isStreamOverlayVisible && self.state.streamingSession != nil
                },
                publish: { [weak self] actions in
                    self?.apply(actions)
                }
            )
        )
        apply(actions)
        logger.info("Stream overlay visible: \(visible)")
    }

#if DEBUG
    func testingSetIsStartingStream(_ value: Bool) {
        // The launch-in-progress guard moved into StreamLaunchWorkflow.
        if value {
            apply(.runtimePhaseSet(.preparingStream))
        } else {
            apply(.runtimePhaseSet(.shellActive))
        }
    }
#endif

    private func handleLifecycleEvent(_ event: StreamSessionLifecycleEvent) async {
        switch event.lifecycle {
        case .connected:
            startInactivityWatchdogIfNeeded()
        case .disconnected, .failed, .idle:
            inactivityWatchdog.stop()
        default:
            break
        }

        await streamReconnectCoordinator.handleLifecycleChange(
            event: event,
            environment: StreamReconnectEnvironment(
                autoReconnectEnabled: dependencies?.settingsStore.stream.autoReconnect ?? false,
                isStreamConnected: { [weak self] in
                    guard let lifecycle = self?.state.streamingSession?.lifecycle else { return false }
                    if case .connected = lifecycle { return true }
                    return false
                },
                launcher: StreamReconnectLauncher(
                    disconnectCurrentSession: { [weak self] in
                        guard let self else { return }
                        self.apply(await self.detachActionsForRelaunch())
                    },
                    prepareBridge: { [weak self] in
                        guard let provider = self?.reconnectBridgeProvider else {
                            preconditionFailure("Reconnect bridge provider must be registered while StreamView is active")
                        }
                        return await provider()
                    },
                    tryHotReconnect: { [weak self] bridge in
                        guard let self else { return false }
                        guard let session = self.state.streamingSession else { return false }
                        await session.reconnectWebRTC(bridge: bridge)
                        return await self.waitForHotReconnectOutcome(
                            session: session,
                            timeout: StreamReconnectPolicy.defaultHotReconnectTimeout
                        )
                    },
                    relaunch: { [weak self] target, bridge in
                        guard let self else { return }
                        switch target {
                        case .cloud(let titleId):
                            await self.performStartCloudStream(titleId: titleId, bridge: bridge)
                        case .home(let consoleId):
                            guard
                                let console = self.dependencies?.consoleController.consoles.first(where: { $0.serverId == consoleId })
                            else { return }
                            await self.performStartHomeStream(console: console, bridge: bridge)
                        }
                    }
                ),
                publish: { [weak self] actions in
                    self?.apply(actions)
                }
            )
        )
    }

    private func makeLaunchEnvironment() -> StreamLaunchEnvironment? {
        guard let dependencies else { return nil }
        return StreamLaunchEnvironment(
            streamSettings: dependencies.settingsStore.stream,
            diagnosticsSettings: dependencies.settingsStore.diagnostics,
            controllerSettings: dependencies.settingsStore.controller,
            availableRegions: dependencies.sessionController.xcloudRegions
        )
    }

    private func makeHeroArtworkEnvironment() -> StreamHeroArtworkEnvironment? {
        guard let dependencies else { return nil }
        return StreamHeroArtworkEnvironment(
            cachedItem: { requestedTitleId in
                await MainActor.run {
                    dependencies.libraryController.item(titleID: requestedTitleId)
                }
            },
            xboxWebCredentials: { logContext in
                await dependencies.sessionController.xboxWebCredentials(logContext: logContext)
            },
            urlSession: dependencies.apiSession(),
            fetchProductDetails: { productId, credentials, session in
                try await XboxComProductDetailsClient(
                    credentials: credentials,
                    session: session
                ).getProductDetails(productId: productId)
            }
        )
    }

    private func makeAchievementLoadEnvironment(
        activeTitleProvider: @escaping @MainActor () -> TitleID?
    ) -> StreamAchievementLoadEnvironment? {
        guard let dependencies else { return nil }
        return StreamAchievementLoadEnvironment(
            activeTitleId: {
                await activeTitleProvider()
            },
            loadSnapshot: { requestedTitleId, forceRefresh in
                await dependencies.achievementsController.loadTitleAchievements(
                    titleID: requestedTitleId,
                    forceRefresh: forceRefresh
                )
                return await MainActor.run {
                    dependencies.achievementsController.titleAchievementSnapshot(titleID: requestedTitleId)
                }
            },
            loadError: { requestedTitleId in
                await MainActor.run {
                    dependencies.achievementsController.lastTitleAchievementsError(titleID: requestedTitleId)
                }
            }
        )
    }

    private func makeOverlayEnvironment(
        activeTitleProvider: @escaping @MainActor () -> TitleID?,
        shouldContinuePresentationRefresh: @escaping @MainActor () -> Bool,
        publish: @escaping @MainActor ([StreamAction]) -> Void
    ) -> StreamOverlayEnvironment {
        StreamOverlayEnvironment(
            heroArtworkEnvironment: makeHeroArtworkEnvironment(),
            achievementEnvironment: makeAchievementLoadEnvironment(activeTitleProvider: activeTitleProvider),
            shouldContinuePresentationRefresh: {
                await shouldContinuePresentationRefresh()
            },
            publishRefreshResult: publish,
            injectNeutralFrame: { [weak self] in
                self?.dependencies?.inputController.injectNeutralGamepadFrame()
            },
            injectPauseMenuTap: { [weak self] in
                self?.dependencies?.inputController.injectPauseMenuTap()
            }
        )
    }

    private func makeRuntimeAttachmentEnvironment() -> StreamRuntimeAttachmentEnvironment {
        StreamRuntimeAttachmentEnvironment(
            input: StreamRuntimeInputEnvironment(
                setupControllerObservation: { [weak self] session in
                    self?.dependencies?.inputController.setupControllerObservation(streamingSession: session)
                },
                clearStreamingInputBindings: { [weak self] in
                    self?.dependencies?.inputController.clearStreamingInputBindings()
                },
                routeVibration: { [weak self] report in
                    guard let self, let dependencies = self.dependencies else { return }
                    dependencies.inputController.routeVibration(
                        report,
                        settingsStore: dependencies.settingsStore
                    )
                }
            )
        )
    }

    private func makePriorityModeEnvironment() -> StreamPriorityModeEnvironment {
        StreamPriorityModeEnvironment(
            enterPriorityMode: { [weak self] in
                await self?.dependencies?.enterStreamPriorityMode()
            },
            exitPriorityMode: { [weak self] in
                await self?.dependencies?.exitStreamPriorityMode()
            }
        )
    }

    private func detachActionsForRelaunch() async -> [StreamAction] {
        guard state.streamingSession != nil else { return [] }
        await runtimeAttachmentService.disconnect(
            session: state.streamingSession,
            reason: .reconnectTransition
        )
        return runtimeAttachmentService.detach(
            environment: makeRuntimeAttachmentEnvironment()
        )
    }

    private func startInactivityWatchdogIfNeeded() {
        let timeoutMinutes = dependencies?.settingsStore.stream.idleDisconnectMinutes
            ?? SettingsStore.StreamSettings().idleDisconnectMinutes
        inactivityWatchdog.start(timeoutMinutes: timeoutMinutes) { [weak self] in
            await self?.handleInactivityTimeout()
        }
    }

    private func handleInactivityTimeout() async {
        guard state.streamingSession != nil else {
            inactivityWatchdog.stop()
            return
        }
        logger.info("Stream inactivity timeout reached; disconnecting without auto-reconnect")
        await performStopStreaming(disconnectReason: .inactivityTimeout)
    }

    private func waitForHotReconnectOutcome(
        session: any StreamingSessionFacade,
        timeout: Duration
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if Task.isCancelled { return false }
            switch session.lifecycle {
            case .connected:
                return true
            case .failed:
                return false
            default:
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}
