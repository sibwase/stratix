// AmbientBackground.swift
// Defines ambient background for the Shared / Components surface.
//

import SwiftUI
import StratixCore

/// Standard dark ambient background with smooth blurred gradient accents across all screens.
struct CloudLibraryAmbientBackground: View {
    var imageURL: URL? = nil

    var body: some View {
        ZStack {
            // Base deep dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.11),
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Blurred ambient gradient lights
            ZStack {
                // Subtle emerald glow in top-right
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.35, blue: 0.22).opacity(0.40),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 80,
                    endRadius: 750
                )

                // Soft teal / cyan glow in bottom-left
                RadialGradient(
                    colors: [
                        Color(red: 0.08, green: 0.28, blue: 0.38).opacity(0.32),
                        Color.clear
                    ],
                    center: .bottomLeading,
                    startRadius: 100,
                    endRadius: 850
                )

                // Deep indigo accent in center-top
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.16, blue: 0.30).opacity(0.35),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 50,
                    endRadius: 650
                )
            }
            .blur(radius: 60)

            // Vignette and contrast gradient overlays
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.clear,
                    Color.black.opacity(0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .drawingGroup()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

extension View {
    /// Standard outer-frame behavior for full-width shell surfaces that should stay left aligned.
    func gamePassOuterFrame() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}
