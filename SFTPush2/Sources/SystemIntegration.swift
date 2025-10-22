import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

enum SystemIntegration {
    // MARK: - Accessibility (AX) permission
    static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func ensureAccessibilityOrInform() -> Bool {
        if isAccessibilityTrusted() { return true }
        // Trigger system prompt if possible
        _ = isAccessibilityTrusted(prompt: true)
        // Show a helpful alert with instructions
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Требуются разрешения Специальных возможностей"
            alert.informativeText = "Для отправки Cmd+C/Cmd+W в другие приложения предоставьте MenuBarProbe доступ: Системные настройки → Конфиденциальность и безопасность → Специальные возможности → включите MenuBarProbe."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Открыть настройки")
            alert.addButton(withTitle: "Позже")
            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        return false
    }
    static func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func isFrontAppMonosnap() -> Bool {
        guard let b = frontmostBundleID()?.lowercased() else { return false }
        return b.contains("monosnap")
    }

    static func isFrontAppFinder() -> Bool {
        frontmostBundleID() == "com.apple.finder"
    }

    static func sendCmdC() {
        guard ensureAccessibilityOrInform() else { return }
        sendKeyCombo(keyCode: 8, modifiers: .maskCommand) // 'C'
    }

    static func sendCmdW() {
        guard ensureAccessibilityOrInform() else { return }
        sendKeyCombo(keyCode: 13, modifiers: .maskCommand) // 'W'
    }

    static func sendKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
