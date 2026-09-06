// ConsoleListEmptyStateTests.swift
// Exercises console list empty-state messaging for discovery and offline presence.
//

import Testing

#if canImport(Stratix)
@testable import Stratix
#endif

struct ConsoleListEmptyStateTests {
    @Test
    func emptyStatePrimaryMessage_prefersDiscoveryError() {
        let message = ConsoleListView.emptyStatePrimaryMessage(
            discoveryError: "network down",
            presenceState: "Offline",
            lastSeenDeviceType: "Scarlett"
        )

        #expect(message.contains("Console discovery failed"))
    }

    @Test
    func emptyStatePrimaryMessage_reportsOfflinePresenceWithDevice() {
        let message = ConsoleListView.emptyStatePrimaryMessage(
            discoveryError: nil,
            presenceState: "Offline",
            lastSeenDeviceType: "Scarlett"
        )

        #expect(message.contains("Xbox Series X"))
        #expect(!message.contains("Scarlett"))
        #expect(message.contains("offline"))
    }

    @Test
    func displayName_mapsInternalXboxDeviceTypes() {
        #expect(ConsoleListView.displayName(forDeviceType: "Scarlett") == "Xbox Series X")
        #expect(ConsoleListView.displayName(forDeviceType: "Lockhart") == "Xbox Series S")
        #expect(ConsoleListView.displayName(forDeviceType: "SteamDeck") == "SteamDeck")
    }

    @Test
    func emptyStatePrimaryMessage_usesGenericCopyWhenNoDiagnostics() {
        let message = ConsoleListView.emptyStatePrimaryMessage(
            discoveryError: nil,
            presenceState: "Online",
            lastSeenDeviceType: nil
        )

        #expect(message.contains("find any Xbox consoles"))
    }
}
