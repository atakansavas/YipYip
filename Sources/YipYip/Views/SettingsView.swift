import YipYipCore
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var showImportPicker = false
    @State private var statusMessage: String?
    @State private var isCheckingUpdate = false
    @State private var updateStatus: String?
    @State private var availableRelease: Release?

    var body: some View {
        Form {
            Section("History") {
                Stepper(
                    "Max items: \(state.settings.maxHistoryItems)",
                    value: $state.settings.maxHistoryItems,
                    in: 10...50_000,
                    step: 100
                )
                Stepper(
                    "Auto-expire after \(state.settings.defaultExpirationDays) days",
                    value: $state.settings.defaultExpirationDays,
                    in: 1...365
                )
            }

            Section("Shortcut") {
                LabeledContent("Open search") {
                    HotkeyRecorder(
                        keyCode: $state.settings.globalHotkeyKeyCode,
                        modifiers: $state.settings.globalHotkeyModifiers,
                        onChange: { NotificationCenter.default.post(name: .yipYipSettingsChanged, object: nil) }
                    )
                }
                Text("⌘⌥V shadows Finder's \"Move Item Here\" while YipYip is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Theme", selection: $state.settings.theme) {
                    ForEach(AppSettings.Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
            }

            Section("Privacy") {
                Toggle("Ignore passwords and transient clips", isOn: $state.settings.ignoreConcealedClips)
                    .onChange(of: state.settings.ignoreConcealedClips) { _, _ in
                        NotificationCenter.default.post(name: .yipYipSettingsChanged, object: nil)
                    }
                Text("Skips clips that password managers and similar apps mark as secret.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sound") {
                Toggle("Play sound when a clip is captured", isOn: $state.settings.soundOnCopy)
                    .onChange(of: state.settings.soundOnCopy) { _, enabled in
                        if enabled { SoundPlayer.play(.copy) }
                    }
                Toggle("Play sound when pasting", isOn: $state.settings.soundOnPaste)
                    .onChange(of: state.settings.soundOnPaste) { _, enabled in
                        if enabled { SoundPlayer.play(.paste) }
                    }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $state.settings.launchAtLogin)
                    .onChange(of: state.settings.launchAtLogin) { _, enabled in
                        LaunchAtLoginHelper.setEnabled(enabled)
                    }
                Toggle("Check for updates on launch", isOn: $state.settings.checkForUpdates)
                HStack {
                    Button("Check Now") { checkForUpdates() }
                        .disabled(isCheckingUpdate)
                    if isCheckingUpdate {
                        ProgressView().controlSize(.small)
                    }
                    if let updateStatus {
                        Text(updateStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let release = availableRelease {
                        Link("Download \(release.version.description)", destination: release.url)
                            .font(.caption)
                    }
                }
            }

            Section("Data") {
                Button("Export Settings…") { exportSettings() }
                Button("Import Settings…") { showImportPicker = true }
            }

            Section("About") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YipYip v\(AppInfo.version)")
                        .font(.headline)
                    Text("Local-first clipboard manager")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstall")
                        .font(.subheadline)
                        .bold()
                    Text("""
                        1. Quit YipYip
                        2. Delete ~/Library/Application Support/YipYip/
                        3. Run: security delete-generic-password -s com.benatakan.yipyip.encryption-key
                        4. Remove YipYip.app from /Applications
                        """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 500)
        .onChange(of: state.settings) { _, _ in
            state.saveSettings()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            importSettings(result)
        }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        updateStatus = nil
        availableRelease = nil

        Task {
            defer { isCheckingUpdate = false }
            do {
                switch try await UpdateChecker().check() {
                case .upToDate(let current):
                    updateStatus = "You're on the latest version (\(current))."
                case .updateAvailable(let release):
                    availableRelease = release
                    updateStatus = "Version \(release.version) is available."
                }
            } catch {
                updateStatus = error.localizedDescription
            }
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "yipyip-settings.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try state.settingsManager.exportSettings()
                try data.write(to: url, options: .atomic)
                statusMessage = "Settings exported."
                clearStatusAfterDelay()
            } catch {
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func importSettings(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let imported = try state.settingsManager.importSettings(from: data)
            state.settings = imported
            statusMessage = "Settings imported."
            clearStatusAfterDelay()
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func clearStatusAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            statusMessage = nil
        }
    }
}
