// RenderSurfaceCoordinatorDisappearTests.swift
// Verifies transient disappear does not tear down an active stream session.
//

import Testing
import InputBridge
import StratixCore
import StratixModels
import StreamingCore
@testable import Stratix

@Suite
struct RenderSurfaceCoordinatorDisappearTests {
    @Test
    @MainActor
    func handleDisappear_skipsTeardownWhileStreamPriorityModeRemainsActive() async {
        let coordinator = RenderSurfaceCoordinator()
        let session = RenderSurfaceDisappearTestSession()
        var stopCalls = 0
        var exitPriorityCalls = 0

        coordinator.handleDisappear(
            session: session,
            surfaceModel: StreamSurfaceModel(),
            shouldTearDownSession: false,
            clearAttachment: {},
            setOverlayVisible: { _, _ in },
            stopStreaming: {
                stopCalls += 1
            },
            exitPriorityMode: {
                exitPriorityCalls += 1
            }
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(stopCalls == 0)
        #expect(exitPriorityCalls == 0)
    }
}

@MainActor
private final class RenderSurfaceDisappearTestSession: StreamingSessionFacade {
    var lifecycle: StreamLifecycleState = .connected
    var stats: StreamingStatsSnapshot = .init()
    var disconnectIntent: StreamingDisconnectIntent = .reconnectable
    let inputQueueRef = InputQueue()
    var onLifecycleChange: (@MainActor (StreamLifecycleState) -> Void)?
    var onVideoTrack: ((AnyObject) -> Void)?

    func connect(type: StreamKind, targetId: String, msaUserToken: String?) async {}

    func setVibrationHandler(_ handler: @escaping (VibrationReport) -> Void) {}

    func setDiagnosticsPollingEnabled(_ enabled: Bool) {}

    func reportRendererDecodeFailure(_ details: String) {}

    func setGamepadConnectionState(index: Int, connected: Bool) {}

    func disconnect(reason: StreamingDisconnectIntent) async {}

    func reconnectWebRTC(bridge: any WebRTCBridge) async {}
}