import ServiceManagement

/// Manages launch-at-login via SMAppService (macOS 13+).
enum LaunchAtLoginHelper {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                // Non-fatal: the app may not be in an app bundle.
                print("Launch at login toggle failed: \(error.localizedDescription)")
            }
        }
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
