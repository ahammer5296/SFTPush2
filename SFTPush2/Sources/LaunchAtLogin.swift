import Foundation
import AppKit
import ServiceManagement

/// Manages the app's "Open at Login" setting via SMAppService (macOS 13+).
enum LaunchAtLogin {
    /// Returns true if the main app is registered to launch at login.
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return true
            default:
                return false
            }
        } else {
            // Deployment target is macOS 13.0, but keep a safe fallback.
            return false
        }
    }

    /// Enables or disables launch at login for the main app.
    /// Errors are swallowed and returned for optional handling by callers.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Error? {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return nil
            } catch {
                return error
            }
        } else {
            return nil
        }
    }
}

