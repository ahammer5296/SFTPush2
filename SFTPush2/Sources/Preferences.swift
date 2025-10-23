import Foundation
import AppKit

final class Preferences {
    static let shared = Preferences()

    enum Key: String {
        case showDockIcon
        case showNotifications
        case enableSound
        case uploadCopiedFiles
        case isMaxFileSizeLimitEnabled
        case maxFileSizeLimit // in MB
        case clipboardUploadFormat // "png" or "jpg"
        case clipboardJpgQuality // 0...100
        case copyBeforeUpload
        case copyOnlyFromMonosnap
        case startMonitoringOnLaunch
        case launchAtSystemStartup
        case renameFileOnUpload
        // SFTP
        case sftpHost
        case sftpPort
        case sftpUsername
        case sftpRemotePath
        case sftpUseKeyAuth
        case sftpKeyPath
        // Hotkey
        case globalHotkeyString
        case globalHotkeyKeyCode
        case globalHotkeyModifiers
        case monitoredFolderPath
        case closeMonosnapAfterUpload
        case sftpPassword
        case sftpBaseURL
        case clipboardSaveToUploaded
        case historyMaxEntries
        case copyURLAfterUpload
        case openURLAfterUpload
        case monosnapCloseDelayMs
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Key.showDockIcon.rawValue: true,
            Key.showNotifications.rawValue: true,
            Key.enableSound.rawValue: false,
            Key.uploadCopiedFiles.rawValue: true,
            Key.isMaxFileSizeLimitEnabled.rawValue: false,
            Key.maxFileSizeLimit.rawValue: 200, // MB
            Key.clipboardUploadFormat.rawValue: "png",
            Key.clipboardJpgQuality.rawValue: 80,
            Key.copyBeforeUpload.rawValue: false,
            Key.copyOnlyFromMonosnap.rawValue: false,
            Key.startMonitoringOnLaunch.rawValue: true,
            Key.launchAtSystemStartup.rawValue: false,
            Key.renameFileOnUpload.rawValue: false,
            Key.sftpHost.rawValue: "",
            Key.sftpPort.rawValue: 22,
            Key.sftpUsername.rawValue: "",
            Key.sftpRemotePath.rawValue: "",
            Key.sftpUseKeyAuth.rawValue: false,
            Key.sftpKeyPath.rawValue: "",
            Key.globalHotkeyString.rawValue: "",
            Key.globalHotkeyKeyCode.rawValue: 0,
            Key.globalHotkeyModifiers.rawValue: 0,
            Key.monitoredFolderPath.rawValue: "",
            Key.closeMonosnapAfterUpload.rawValue: false,
            Key.sftpPassword.rawValue: "",
            Key.sftpBaseURL.rawValue: ""
            ,Key.clipboardSaveToUploaded.rawValue: false
            ,Key.historyMaxEntries.rawValue: 10
            ,Key.copyURLAfterUpload.rawValue: true
            ,Key.openURLAfterUpload.rawValue: false
            ,Key.monosnapCloseDelayMs.rawValue: 150
        ])
    }

    var showDockIcon: Bool {
        get { defaults.bool(forKey: Key.showDockIcon.rawValue) }
        set {
            defaults.set(newValue, forKey: Key.showDockIcon.rawValue)
            NotificationCenter.default.post(name: .preferencesShowDockIconChanged, object: nil, userInfo: ["value": newValue])
        }
    }

    var showNotifications: Bool {
        get { defaults.bool(forKey: Key.showNotifications.rawValue) }
        set { defaults.set(newValue, forKey: Key.showNotifications.rawValue) }
    }

    var enableSound: Bool {
        get { defaults.bool(forKey: Key.enableSound.rawValue) }
        set { defaults.set(newValue, forKey: Key.enableSound.rawValue) }
    }

    var uploadCopiedFiles: Bool {
        get { defaults.bool(forKey: Key.uploadCopiedFiles.rawValue) }
        set { defaults.set(newValue, forKey: Key.uploadCopiedFiles.rawValue) }
    }

    var isMaxFileSizeLimitEnabled: Bool {
        get { defaults.bool(forKey: Key.isMaxFileSizeLimitEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.isMaxFileSizeLimitEnabled.rawValue) }
    }

    var maxFileSizeLimitMB: Int {
        get { max(1, defaults.integer(forKey: Key.maxFileSizeLimit.rawValue)) }
        set { defaults.set(max(1, newValue), forKey: Key.maxFileSizeLimit.rawValue) }
    }

    var clipboardUploadFormat: String { // "png" or "jpg"
        get { defaults.string(forKey: Key.clipboardUploadFormat.rawValue) ?? "png" }
        set { defaults.set(newValue, forKey: Key.clipboardUploadFormat.rawValue) }
    }

    var clipboardJpgQuality: Int { // 0...100
        get { min(100, max(0, defaults.integer(forKey: Key.clipboardJpgQuality.rawValue))) }
        set { defaults.set(min(100, max(0, newValue)), forKey: Key.clipboardJpgQuality.rawValue) }
    }

    var copyBeforeUpload: Bool {
        get { defaults.bool(forKey: Key.copyBeforeUpload.rawValue) }
        set { defaults.set(newValue, forKey: Key.copyBeforeUpload.rawValue) }
    }

    var copyOnlyFromMonosnap: Bool {
        get { defaults.bool(forKey: Key.copyOnlyFromMonosnap.rawValue) }
        set { defaults.set(newValue, forKey: Key.copyOnlyFromMonosnap.rawValue) }
    }

    var startMonitoringOnLaunch: Bool {
        get { defaults.bool(forKey: Key.startMonitoringOnLaunch.rawValue) }
        set { defaults.set(newValue, forKey: Key.startMonitoringOnLaunch.rawValue) }
    }

    var launchAtSystemStartup: Bool {
        get {
            // Reflect actual system state when possible
            if #available(macOS 13.0, *) {
                return LaunchAtLogin.isEnabled
            } else {
                return defaults.bool(forKey: Key.launchAtSystemStartup.rawValue)
            }
        }
        set {
            // Persist preference for fallback/debug, then apply system change
            defaults.set(newValue, forKey: Key.launchAtSystemStartup.rawValue)
            _ = LaunchAtLogin.setEnabled(newValue)
        }
    }

    var renameFileOnUpload: Bool {
        get { defaults.bool(forKey: Key.renameFileOnUpload.rawValue) }
        set { defaults.set(newValue, forKey: Key.renameFileOnUpload.rawValue) }
    }

    // MARK: - SFTP
    var sftpHost: String {
        get { defaults.string(forKey: Key.sftpHost.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpHost.rawValue) }
    }

    var sftpPort: Int {
        get { let v = defaults.integer(forKey: Key.sftpPort.rawValue); return v == 0 ? 22 : v }
        set { defaults.set(newValue, forKey: Key.sftpPort.rawValue) }
    }

    var sftpUsername: String {
        get { defaults.string(forKey: Key.sftpUsername.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpUsername.rawValue) }
    }

    var sftpRemotePath: String {
        get { defaults.string(forKey: Key.sftpRemotePath.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpRemotePath.rawValue) }
    }

    var sftpUseKeyAuth: Bool {
        get { defaults.bool(forKey: Key.sftpUseKeyAuth.rawValue) }
        set { defaults.set(newValue, forKey: Key.sftpUseKeyAuth.rawValue) }
    }

    var sftpKeyPath: String {
        get { defaults.string(forKey: Key.sftpKeyPath.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpKeyPath.rawValue) }
    }

    // MARK: - Hotkey
    var globalHotkeyString: String {
        get { defaults.string(forKey: Key.globalHotkeyString.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.globalHotkeyString.rawValue) }
    }

    var globalHotkeyKeyCode: Int {
        get { defaults.integer(forKey: Key.globalHotkeyKeyCode.rawValue) }
        set { defaults.set(newValue, forKey: Key.globalHotkeyKeyCode.rawValue) }
    }

    var globalHotkeyModifiers: UInt {
        get { UInt(bitPattern: Int(defaults.integer(forKey: Key.globalHotkeyModifiers.rawValue))) }
        set { defaults.set(Int(bitPattern: newValue), forKey: Key.globalHotkeyModifiers.rawValue) }
    }

    var monitoredFolderPath: String {
        get { defaults.string(forKey: Key.monitoredFolderPath.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.monitoredFolderPath.rawValue) }
    }

    var closeMonosnapAfterUpload: Bool {
        get { defaults.bool(forKey: Key.closeMonosnapAfterUpload.rawValue) }
        set { defaults.set(newValue, forKey: Key.closeMonosnapAfterUpload.rawValue) }
    }

    var sftpPassword: String {
        get { defaults.string(forKey: Key.sftpPassword.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpPassword.rawValue) }
    }

    var sftpBaseURL: String {
        get { defaults.string(forKey: Key.sftpBaseURL.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.sftpBaseURL.rawValue) }
    }

    var clipboardSaveToUploaded: Bool {
        get { defaults.bool(forKey: Key.clipboardSaveToUploaded.rawValue) }
        set { defaults.set(newValue, forKey: Key.clipboardSaveToUploaded.rawValue) }
    }

    // MARK: - History
    var historyMaxEntries: Int {
        get { let v = defaults.integer(forKey: Key.historyMaxEntries.rawValue); return v <= 0 ? 10 : min(max(1, v), 1000) }
        set { defaults.set(min(max(1, newValue), 1000), forKey: Key.historyMaxEntries.rawValue) }
    }

    // Post-upload actions
    var copyURLAfterUpload: Bool {
        get { defaults.bool(forKey: Key.copyURLAfterUpload.rawValue) }
        set { defaults.set(newValue, forKey: Key.copyURLAfterUpload.rawValue) }
    }
    var openURLAfterUpload: Bool {
        get { defaults.bool(forKey: Key.openURLAfterUpload.rawValue) }
        set { defaults.set(newValue, forKey: Key.openURLAfterUpload.rawValue) }
    }

    // MARK: - Monosnap behavior
    var monosnapCloseDelayMs: Int {
        get {
            let v = defaults.integer(forKey: Key.monosnapCloseDelayMs.rawValue)
            return min(max(0, v), 2000)
        }
        set {
            let clamped = min(max(0, newValue), 2000)
            defaults.set(clamped, forKey: Key.monosnapCloseDelayMs.rawValue)
        }
    }
}

extension Notification.Name {
    static let preferencesShowDockIconChanged = Notification.Name("Preferences.showDockIconChanged")
    static let preferencesHotkeyChanged = Notification.Name("Preferences.hotkeyChanged")
}
