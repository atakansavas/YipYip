import AppKit
import YipYipCore
import SwiftUI

@main
@MainActor
struct YipYipApp {
    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("YipYip", isDirectory: true)
    }()

    static func main() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var searchPanel: NSPanel?
    private var hotkeyManager: HotkeyManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var appState: AppState?
    private var panelCloseMonitor: Any?
    /// App that was frontmost when the panel opened — the paste target.
    private var previousApp: NSRunningApplication?
    private var headerItem: NSMenuItem!
    private var copySoundItem: NSMenuItem!
    private var pasteSoundItem: NSMenuItem!
    private var updateItem: NSMenuItem!
    private var flashTask: Task<Void, Never>?
    private var didReportAccessibility = false
    private var latestReleaseURL: URL?
    private var onboardingWindow: NSWindow?
    /// False until storage is open; menu actions are no-ops before then.
    private var isReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The menu bar icon appears immediately. Unlocking the encryption key can
        // block on a Keychain dialog, so it happens off the main thread — the app
        // stays responsive while the user answers it.
        setupStatusItem()

        Task { @MainActor in
            do {
                let storage = try await Task.detached(priority: .userInitiated) {
                    try AppState.openStorage()
                }.value

                finishLaunching(with: AppState(storage: storage))
            } catch {
                reportStartupFailure(error)
            }
        }
    }

    private func finishLaunching(with state: AppState) {
        appState = state
        isReady = true

        setupHotkey(state: state)
        setupClipboardMonitor(state: state)
        state.cleanupExpired()

        if state.settings.launchAtLogin {
            LaunchAtLoginHelper.setEnabled(true)
        }
        checkForUpdatesIfEnabled(state: state)
        refreshMenuState()

        if !state.settings.hasCompletedOnboarding {
            showOnboarding()
        }

        NotificationCenter.default.addObserver(
            forName: .yipYipSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let state = self.appState else { return }
                self.setupHotkey(state: state)
                self.clipboardMonitor?.honourExclusionMarkers = state.settings.ignoreConcealedClips
            }
        }
    }

    private func reportStartupFailure(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "YipYip failed to start"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = StatusItemIcon.idle

        let menu = NSMenu()
        menu.delegate = self

        headerItem = NSMenuItem()
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Stays hidden until an opt-in check finds something newer.
        updateItem = item("Update available", symbol: "arrow.down.circle", action: #selector(openLatestRelease))
        updateItem.isHidden = true
        menu.addItem(updateItem)
        menu.addItem(.separator())

        let search = item("Search History", symbol: "magnifyingglass", action: #selector(showSearch))
        search.keyEquivalent = "v"
        search.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(search)
        menu.addItem(.separator())

        copySoundItem = item("Copy Sound", symbol: "speaker.wave.2", action: #selector(toggleCopySound))
        pasteSoundItem = item("Paste Sound", symbol: "speaker.wave.2", action: #selector(togglePasteSound))
        menu.addItem(copySoundItem)
        menu.addItem(pasteSoundItem)

        let settings = item("Settings…", symbol: "gearshape", action: #selector(showSettings))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(item("Export Data…", symbol: "square.and.arrow.up", action: #selector(exportData)))
        menu.addItem(item("Diagnostics…", symbol: "stethoscope", action: #selector(showDiagnostics)))
        menu.addItem(.separator())

        menu.addItem(item("Clear All History", symbol: "trash", action: #selector(clearHistory)))
        let quit = item("Quit YipYip", symbol: "power", action: #selector(quitApp))
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        statusItem.menu = menu
        refreshMenuState()
    }

    /// Builds a menu item with a template symbol image, targeted at this delegate.
    private func item(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.image = AppDelegate.symbolImage(symbol)
        return menuItem
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    /// Refreshes the parts of the menu that depend on live state.
    private func refreshMenuState() {
        guard let state = appState else {
            headerItem.attributedTitle = NSAttributedString(
                string: "Starting…",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            return
        }

        let count = (try? state.store.itemCount()) ?? state.items.count
        let pinned = (try? state.store.pinnedItems().count) ?? 0

        let title = NSMutableAttributedString(
            string: "YipYip",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        var detail = "  ·  \(count) item\(count == 1 ? "" : "s")"
        if pinned > 0 { detail += "  ·  \(pinned) pinned" }
        title.append(NSAttributedString(
            string: detail,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        headerItem.attributedTitle = title

        apply(state.settings.soundOnCopy, to: copySoundItem)
        apply(state.settings.soundOnPaste, to: pasteSoundItem)
    }

    private func apply(_ enabled: Bool, to menuItem: NSMenuItem) {
        menuItem.state = enabled ? .on : .off
        menuItem.image = AppDelegate.symbolImage(enabled ? "speaker.wave.2" : "speaker.slash")
    }

    @objc private func toggleCopySound() {
        guard let state = appState else { return }
        state.settings.soundOnCopy.toggle()
        state.saveSettings()
        if state.settings.soundOnCopy { SoundPlayer.play(.copy) }
        refreshMenuState()
    }

    @objc private func togglePasteSound() {
        guard let state = appState else { return }
        state.settings.soundOnPaste.toggle()
        state.saveSettings()
        if state.settings.soundOnPaste { SoundPlayer.play(.paste) }
        refreshMenuState()
    }

    /// Briefly swaps in the solid glyph so a capture is visible as well as audible.
    private func flashStatusIcon() {
        flashTask?.cancel()
        statusItem.button?.image = StatusItemIcon.active
        flashTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            statusItem.button?.image = StatusItemIcon.idle
        }
    }

    private func setupHotkey(state: AppState) {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.register(
            keyCode: state.settings.globalHotkeyKeyCode,
            modifiers: state.settings.globalHotkeyModifiers
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.toggleSearchPanel()
            }
        }
    }

    private func setupClipboardMonitor(state: AppState) {
        let monitor = ClipboardMonitor()
        monitor.honourExclusionMarkers = state.settings.ignoreConcealedClips
        self.clipboardMonitor = monitor
        monitor.onChange = { [weak self, weak state] capture, sourceApp in
            guard let state else { return }
            // Only signal genuinely new clips — re-copying something already in
            // history is a no-op and should stay silent.
            guard state.addItem(capture, sourceApp: sourceApp) else { return }
            if state.settings.soundOnCopy { SoundPlayer.play(.copy) }
            self?.flashStatusIcon()
        }
        monitor.start()
    }

    private func toggleSearchPanel() {
        if let panel = searchPanel, panel.isVisible {
            dismissPanel()
            return
        }
        showSearch()
    }

    private func dismissPanel() {
        guard let panel = searchPanel else { return }
        // Drop the reference up front: Esc and the outside-click monitor can both
        // fire, and a second dismiss mid-animation would close the panel twice.
        searchPanel = nil

        if let monitor = panelCloseMonitor {
            NSEvent.removeMonitor(monitor)
            panelCloseMonitor = nil
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                panel.close()
                panel.alphaValue = 1
            }
        }
    }

    /// Copies the item, closes the panel, and pastes into the app the user came from.
    private func pasteSelectedIntoPreviousApp() {
        let target = previousApp
        previousApp = nil
        dismissPanel()

        if appState?.settings.soundOnPaste == true { SoundPlayer.play(.paste) }

        guard PasteHelper.isTrusted else {
            // The clip is on the pasteboard either way, but silently doing
            // nothing here reads as "the app is broken" — say what is missing.
            reportMissingAccessibility()
            return
        }

        // Without a known target app the clip stays on the pasteboard for ⌘V.
        guard let target else { return }
        PasteHelper.paste(into: target)
    }

    /// Shown at most once per launch, so a denied prompt does not nag.
    private func reportMissingAccessibility() {
        guard !didReportAccessibility else { return }
        didReportAccessibility = true

        // Ask the system first: this is the prompt that adds YipYip to the list.
        if PasteHelper.ensureAccessibilityPermission() { return }

        let alert = NSAlert()
        alert.messageText = "YipYip needs Accessibility to paste"
        alert.informativeText = """
            The clip was copied to the clipboard — press ⌘V to paste it.

            To have YipYip paste for you, enable it under Privacy & Security ▸ \
            Accessibility, then quit and reopen YipYip.

            If YipYip is already listed and checked, remove it with the “−” \
            button and add it again: a checked entry from an older build no \
            longer matches this one.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            PasteHelper.openAccessibilitySettings()
        }
    }

    @objc private func showSearch() {
        guard isReady, let state = appState else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }

        state.searchQuery = ""
        state.refreshItems()
        state.selectedIndex = 0
        state.activeTab = .all

        if let existing = searchPanel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SearchWindowView(
            state: state,
            onDismiss: { [weak self] in
                self?.dismissPanel()
            },
            onPaste: { [weak self] in
                self?.pasteSelectedIntoPreviousApp()
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        // ARC owns the panel; letting AppKit release it on close over-releases it
        // while the fade-out animation is still holding on (SIGSEGV in
        // _NSWindowTransformAnimation dealloc).
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: view)

        // Position upper-third of screen (Spotlight-like).
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 340
            let y = screenFrame.midY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.searchPanel = panel

        // Close on click outside.
        panelCloseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissPanel()
        }
    }

    /// First launch only: explains the shortcut and the two permissions before
    /// macOS asks for them out of context.
    private func showOnboarding() {
        guard let state = appState else { return }

        let view = OnboardingView(
            shortcut: HotkeyDescription.display(
                keyCode: state.settings.globalHotkeyKeyCode,
                modifiers: state.settings.globalHotkeyModifiers
            ),
            onOpenAccessibility: { PasteHelper.openAccessibilitySettings() },
            onFinish: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.appState?.settings.hasCompletedOnboarding = true
                    self.appState?.saveSettings()
                    self.onboardingWindow?.close()
                    self.onboardingWindow = nil
                }
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Welcome"
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    @objc private func showSettings() {
        guard let state = appState else { return }
        let view = SettingsView(state: state)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "YipYip Settings"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func exportData() {
        guard let state = appState else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DataExporter.safeFilename()
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let items = try state.store.recentItems(limit: 50_000)
                let data = try DataExporter.exportMetadata(items: items)
                try data.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    @objc private func showDiagnostics() {
        guard let state = appState else { return }
        do {
            let count = try state.store.itemCount()
            let report = DataExporter.diagnosticsReport(
                itemCount: count,
                dbPath: state.dbPath,
                settingsPath: state.settingsManager.settingsFileURL.path,
                accessibilityGranted: PasteHelper.isTrusted
            )
            let alert = NSAlert()
            alert.messageText = "Diagnostics"
            alert.informativeText = report
            alert.addButton(withTitle: "Copy to Clipboard")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report, forType: .string)
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This permanently deletes all clipboard history. Pinned items will also be removed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        try? appState?.store.deleteAll()
        appState?.items = []
    }

    /// Opt-in only: this is the one network request YipYip ever makes.
    private func checkForUpdatesIfEnabled(state: AppState) {
        guard state.settings.checkForUpdates else { return }

        Task { @MainActor in
            guard case .updateAvailable(let release) = try? await UpdateChecker().check() else { return }
            latestReleaseURL = release.url
            updateItem.title = "Update to \(release.version)"
            updateItem.isHidden = false
        }
    }

    @objc private func openLatestRelease() {
        NSWorkspace.shared.open(latestReleaseURL ?? AppInfo.releasesURL)
    }

    @objc private func quitApp() {
        clipboardMonitor?.stop()
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }
}
