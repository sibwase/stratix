// CloudLibrarySettingsView.swift
// Defines the cloud library settings view used in the CloudLibrary / Settings surface.
//

import SwiftUI
import StratixCore
import StratixModels

struct CloudLibrarySettingsView: View {
    @Binding var selectedPane: CloudLibrarySettingsPane

    let profileName: String
    let profileInitials: String
    let profileImageURL: URL?
    let profileStatusText: String
    let profileStatusDetail: String
    let cloudLibraryCount: Int
    let consoleCount: Int
    let isLoadingCloudLibrary: Bool
    let regionOverrideDiagnostics: String?
    var onSignOut: () -> Void = {}
    var onRequestSideRailEntry: () -> Void = {}
    var isSideRailExpanded: Bool = false
    var onExportPreviewDump: () async -> String = { "" }

    @Environment(SettingsStore.self) var settingsStore
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @SceneStorage("stratix.gamepass.settings.advanced_mode") var isAdvancedMode = false
    @FocusState var focusedPane: CloudLibrarySettingsPane?
    @State var exportTask: Task<Void, Never>?
    @State var exportFeedback: String?
    @State var isExportingPreviewDump = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            rightPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("route_settings_root")
        .onAppear {
            syncPaneSelectionIfNeeded(restoreStoredSelection: true)
        }
        .onChange(of: selectedPane) { _, newValue in
            persistSelectedPane(newValue)
        }
        .onChange(of: isAdvancedMode) { _, _ in
            syncPaneSelectionIfNeeded()
        }
        .onChange(of: isSideRailExpanded) { _, expanded in
            guard expanded else { return }
            releaseSettingsFocusForSideRailEntry()
        }
        .onDisappear {
            exportTask?.cancel()
        }
    }

    var rightPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StratixTheme.Library.headerBelowBadgeSpacing) {
                Color.clear
                    .frame(height: StratixTheme.SideRail.collapsedBadgeHeight)

                VStack(alignment: .leading, spacing: 18) {
                    paneHeader
                        .padding(.horizontal, 32)
                        .padding(.top, 0)
                        .padding(.bottom, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedPane {
                        case .stream:
                            streamPane
                        case .controller:
                            controllerPane
                        case .videoAudio:
                            videoAudioPane
                        case .interface:
                            interfacePane
                        case .diagnostics:
                            diagnosticsPane
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
            .padding(.bottom, StratixTheme.Shell.contentBottomPadding)
            .frame(maxWidth: 1510, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollIndicators(.never)
        .environment(\.cloudLibrarySettingsPaneMoveHandler, focusSettingsSidebarOnLeftMove)
    }

    func releaseSettingsFocusForSideRailEntry() {
        focusedPane = nil
    }

    func requestShellSideRailEntry() {
        releaseSettingsFocusForSideRailEntry()
        onRequestSideRailEntry()
    }

    private func focusSettingsSidebarOnLeftMove(_ direction: MoveCommandDirection) {
        guard direction == .left else { return }
        Task { @MainActor in
            focusedPane = selectedPane
            await Task.yield()
            focusedPane = selectedPane
        }
    }

    var paneHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: selectedPane.systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(StratixTheme.Colors.focusTint)

                Text(selectedPane.title)
                    .font(StratixTypography.rounded(32, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                Spacer(minLength: 0)

                CloudLibrarySettingTag(text: isAdvancedMode ? "ADVANCED" : "BASIC")
                if showsSyncingTag {
                    CloudLibrarySettingTag(text: "SYNCING")
                }
            }

            Text(selectedPane.subtitle)
                .font(StratixTypography.rounded(20, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                CloudLibraryStatPill(icon: "cloud.fill", text: "\(cloudLibraryCount) cloud titles")
                CloudLibraryStatPill(icon: "tv.fill", text: "\(consoleCount) consoles")
                CloudLibraryStatPill(icon: "slider.horizontal.3", text: settingsStore.stream.qualityPreset)
            }
        }
    }

    func syncPaneSelectionIfNeeded(restoreStoredSelection: Bool = false) {
        selectedPane = CloudLibrarySettingsBindings.resolvedPane(
            currentPane: selectedPane,
            storedRawValue: settingsStore.shell.lastSettingsCategoryRawValue,
            isAdvancedMode: isAdvancedMode,
            restoreStoredSelection: restoreStoredSelection
        )

        persistSelectedPane(selectedPane)
    }

    var showsSyncingTag: Bool {
        isLoadingCloudLibrary
    }

    func persistSelectedPane(_ pane: CloudLibrarySettingsPane) {
        var shell = settingsStore.shell
        shell.lastSettingsCategoryRawValue = pane.rawValue
        settingsStore.shell = shell
    }

    var previewExportTitle: String {
        isExportingPreviewDump ? "Exporting Preview Dump" : "Export Preview Dump"
    }

    func startPreviewExport() {
        exportTask?.cancel()
        isExportingPreviewDump = true
        exportTask = Task { @MainActor in
            let result = await onExportPreviewDump()
            guard !Task.isCancelled else { return }
            exportFeedback = result
            isExportingPreviewDump = false
        }
    }
}

#if DEBUG
private struct CloudLibrarySettingsPreviewHost: View {
    @State private var pane: CloudLibrarySettingsPane = .stream
    @State private var coordinator = AppCoordinator()

    var body: some View {
        CloudLibrarySettingsView(
            selectedPane: $pane,
            profileName: "stratix-preview",
            profileInitials: "S",
            profileImageURL: nil,
            profileStatusText: "Online",
            profileStatusDetail: "Playing Forza Horizon 5",
            cloudLibraryCount: 248,
            consoleCount: 2,
            isLoadingCloudLibrary: false,
            regionOverrideDiagnostics: nil
        )
        .environment(coordinator.settingsStore)
    }
}

#Preview("CloudLibrarySettingsView", traits: .fixedLayout(width: 1920, height: 1080)) {
    CloudLibrarySettingsPreviewHost()
}
#endif
