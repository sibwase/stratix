// ConsoleListFixtures.swift
// Provides mock remote-play console fixtures for UI-test harnesses and DEBUG previews.
//

import Foundation
import XCloudAPI

enum ConsoleListFixtures {
    /// Deterministic consoles used by `-stratix-uitest-mock-consoles` and local previews.
    static var mockConsoles: [RemoteConsole] {
        [
            makeConsole(
                deviceName: "Living Room Xbox",
                serverId: "mock-console-series-x",
                powerState: "On",
                consoleType: "Xbox Series X"
            ),
            makeConsole(
                deviceName: "Bedroom Xbox",
                serverId: "mock-console-series-s",
                powerState: "ConnectedStandby",
                consoleType: "Xbox Series S",
                wirelessWarning: true
            )
        ]
    }

    static func makeConsole(
        deviceName: String,
        serverId: String,
        powerState: String,
        consoleType: String,
        outOfHomeWarning: Bool = false,
        wirelessWarning: Bool = false,
        isDevKit: Bool = false
    ) -> RemoteConsole {
        let json = """
        {
          "deviceName": "\(deviceName)",
          "serverId": "\(serverId)",
          "powerState": "\(powerState)",
          "consoleType": "\(consoleType)",
          "playPath": "/play",
          "outOfHomeWarning": \(outOfHomeWarning),
          "wirelessWarning": \(wirelessWarning),
          "isDevKit": \(isDevKit)
        }
        """
        return try! JSONDecoder().decode(RemoteConsole.self, from: Data(json.utf8))
    }
}
