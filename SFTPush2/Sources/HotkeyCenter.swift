import Foundation
import Carbon.HIToolbox
import AppKit

final class HotkeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: HotkeyCenter.signature("SFTU"), id: 1)

    var onHotkey: (() -> Void)?

    deinit {
        unregister()
    }

    func register(keyCode: UInt16, modifiers: UInt) {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let carbonMods = HotkeyCenter.carbonFlags(from: modifiers)
        let status = RegisterEventHotKey(UInt32(keyCode), carbonMods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        } else {
            // Optional: post a debug log
            // print("[HotkeyCenter] RegisterEventHotKey failed: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let h = eventHandlerRef {
            RemoveEventHandler(h)
            eventHandlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, eventRef, userData) -> OSStatus in
            guard let eventRef = eventRef else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(eventRef, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if err == noErr {
                let mySelf = Unmanaged<HotkeyCenter>.fromOpaque(userData!).takeUnretainedValue()
                if hkID.id == mySelf.hotKeyID.id && hkID.signature == mySelf.hotKeyID.signature {
                    DispatchQueue.main.async { mySelf.onHotkey?() }
                }
            }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)
        if status != noErr {
            // print("[HotkeyCenter] InstallEventHandler failed: \(status)")
        }
    }

    private static func carbonFlags(from nsRawModifiers: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: nsRawModifiers)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        // Fn is not supported by Carbon hotkey modifiers; ignore if present
        return result
    }

    private static func signature(_ s: String) -> OSType {
        var result: OSType = 0
        for scalar in s.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}

