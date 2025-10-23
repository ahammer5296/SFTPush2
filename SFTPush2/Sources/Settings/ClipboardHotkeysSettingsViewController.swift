import Cocoa

final class ClipboardHotkeysSettingsViewController: NSViewController {
    private let prefs = Preferences.shared
    private var jpgRowHeightConstraint: NSLayoutConstraint?
    private var isRecordingHotkey = false
    private var hotkeyMonitor: Any?
    private var previousHotkeyString: String = ""

    // Image settings box
    private let imageBox: NSBox = {
        let b = NSBox()
        b.title = L("settings.image_settings")
        return b
    }()
    private let clipboardFormatLabel = NSTextField(labelWithString: L("settings.clipboard_format"))
    private let clipboardFormatControl = NSSegmentedControl(labels: [L("settings.clipboard_format_png"), L("settings.clipboard_format_jpg")], trackingMode: .selectOne, target: nil, action: nil)
    private let jpgQualityLabel = NSTextField(labelWithString: L("settings.jpg_quality_range"))
    private let jpgQualitySlider: NSSlider = {
        let s = NSSlider(value: 80, minValue: 10, maxValue: 100, target: nil, action: nil)
        s.numberOfTickMarks = 10
        return s
    }()
    private let jpgQualityValueLabel = NSTextField(labelWithString: "80")

    // Hotkeys box
    private let hotkeysBox: NSBox = {
        let b = NSBox()
        b.title = L("settings.hotkeys")
        return b
    }()
    private let hotkeyActionLabel = NSTextField(labelWithString: L("settings.clipboard_action_upload"))
    private let hotkeyValueField: NSTextField = {
        let f = NSTextField()
        f.isEditable = false
        f.isSelectable = false
        f.placeholderString = L("settings.hotkey_not_set")
        return f
    }()
    private let clearButton = NSButton(title: L("settings.clear"), target: nil, action: nil)

    // Copy settings box
    private let copyBox: NSBox = {
        let b = NSBox()
        b.title = L("settings.copy_settings")
        return b
    }()
    private let uploadCopiedFilesCheckbox = NSButton(checkboxWithTitle: L("settings.upload_copied_files"), target: nil, action: nil)
    private let copyBeforeUploadCheckbox = NSButton(checkboxWithTitle: L("settings.copy_before_upload"), target: nil, action: nil)
    private let copyOnlyFromMonosnapCheckbox = NSButton(checkboxWithTitle: L("settings.copy_only_from_monosnap"), target: nil, action: nil)
    private let closeMonosnapCheckbox = NSButton(checkboxWithTitle: L("settings.close_monosnap_after_upload"), target: nil, action: nil)
    private let closeMonosnapDelayLabel = NSTextField(labelWithString: L("settings.close_monosnap_delay_ms"))
    private let closeMonosnapDelayField: NSTextField = {
        let f = NSTextField()
        f.alignment = .right
        f.placeholderString = "150"
        return f
    }()
    private let saveClipboardToUploadedCheckbox = NSButton(checkboxWithTitle: L("settings.save_clipboard_to_uploaded"), target: nil, action: nil)
    private let accessibilityInfoLabel: NSTextField = {
        // Kept for potential future detailed text; hidden by default.
        let l = NSTextField(labelWithString: "")
        l.isHidden = true
        l.lineBreakMode = .byWordWrapping
        l.maximumNumberOfLines = 0
        l.textColor = .secondaryLabelColor
        return l
    }()
    private let accessibilityInfoIcon: NSButton = {
        // Small help-style button with tooltip
        let b = NSButton()
        b.bezelStyle = .helpButton
        b.isBordered = true
        b.title = ""
        b.setButtonType(.momentaryPushIn)
        b.toolTip = ""
        return b
    }()
    private let accessibilityOpenButton = NSButton(title: "Открыть настройки Спец.возможностей", target: nil, action: nil)

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        load()
        wire()
        addHotkeyCapture()
        // Live updates for delay field
        closeMonosnapDelayField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(onDelayChanged(_:)), name: NSControl.textDidChangeNotification, object: closeMonosnapDelayField)
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        // Image box content
        let formatRow = NSStackView(views: [clipboardFormatLabel, clipboardFormatControl])
        formatRow.alignment = .centerY
        formatRow.spacing = 8
        let jpgRow = NSStackView(views: [jpgQualityLabel, jpgQualitySlider, jpgQualityValueLabel])
        jpgRow.alignment = .centerY
        jpgRow.spacing = 8
        let imgStack = NSStackView(views: [formatRow, jpgRow])
        imgStack.orientation = .vertical
        imgStack.alignment = .leading
        imgStack.spacing = 8
        let imageContent = NSView()
        imageBox.contentView = imageContent
        imgStack.translatesAutoresizingMaskIntoConstraints = false
        imageContent.addSubview(imgStack)
        NSLayoutConstraint.activate([
            imgStack.topAnchor.constraint(equalTo: imageContent.topAnchor, constant: 8),
            imgStack.leadingAnchor.constraint(equalTo: imageContent.leadingAnchor, constant: 12),
            imgStack.trailingAnchor.constraint(equalTo: imageContent.trailingAnchor, constant: -12),
            imgStack.bottomAnchor.constraint(equalTo: imageContent.bottomAnchor, constant: -8)
        ])
        // Keep constant height regardless of PNG/JPG toggle by fixing jpgRow height
        jpgRow.translatesAutoresizingMaskIntoConstraints = false
        jpgRowHeightConstraint = jpgRow.heightAnchor.constraint(equalToConstant: jpgRow.fittingSize.height)
        jpgRowHeightConstraint?.isActive = true
        // Fix value label width to prevent slider jitter
        jpgQualityValueLabel.alignment = .right
        jpgQualityValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        jpgQualityValueLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        // Hotkeys box content
        let hotkeyRow = NSStackView(views: [hotkeyActionLabel])
        let hotkeyInputRow = NSStackView(views: [hotkeyValueField, clearButton])
        hotkeyInputRow.spacing = 8
        // Ensure hotkey field does not shrink below 120 px
        hotkeyValueField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        hotkeyValueField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        clearButton.setContentHuggingPriority(.required, for: .horizontal)
        let hkStack = NSStackView(views: [hotkeyRow, hotkeyInputRow])
        hkStack.orientation = .vertical
        hkStack.alignment = .leading
        hkStack.spacing = 8
        let hotkeysContent = NSView()
        hotkeysBox.contentView = hotkeysContent
        hkStack.translatesAutoresizingMaskIntoConstraints = false
        hotkeysContent.addSubview(hkStack)
        NSLayoutConstraint.activate([
            hkStack.topAnchor.constraint(equalTo: hotkeysContent.topAnchor, constant: 8),
            hkStack.leadingAnchor.constraint(equalTo: hotkeysContent.leadingAnchor, constant: 12),
            hkStack.trailingAnchor.constraint(equalTo: hotkeysContent.trailingAnchor, constant: -12),
            hkStack.bottomAnchor.constraint(equalTo: hotkeysContent.bottomAnchor, constant: -8)
        ])

        // Copy box content
        let delayRow = NSStackView(views: [closeMonosnapDelayLabel, closeMonosnapDelayField])
        delayRow.alignment = .firstBaseline
        delayRow.spacing = 8
        // Make delay field compact
        closeMonosnapDelayField.translatesAutoresizingMaskIntoConstraints = false
        closeMonosnapDelayField.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let copyChildrenStack = NSStackView(views: [copyOnlyFromMonosnapCheckbox, closeMonosnapCheckbox, delayRow])
        copyChildrenStack.orientation = .vertical
        copyChildrenStack.alignment = .leading
        copyChildrenStack.spacing = 8

        // Container to indent children under the parent checkbox
        let copyChildrenContainer = NSView()
        copyChildrenContainer.translatesAutoresizingMaskIntoConstraints = false
        copyChildrenStack.translatesAutoresizingMaskIntoConstraints = false
        copyChildrenContainer.addSubview(copyChildrenStack)
        NSLayoutConstraint.activate([
            copyChildrenStack.topAnchor.constraint(equalTo: copyChildrenContainer.topAnchor),
            copyChildrenStack.leadingAnchor.constraint(equalTo: copyChildrenContainer.leadingAnchor, constant: 20),
            copyChildrenStack.trailingAnchor.constraint(equalTo: copyChildrenContainer.trailingAnchor),
            copyChildrenStack.bottomAnchor.constraint(equalTo: copyChildrenContainer.bottomAnchor)
        ])

        // Info icon with tooltip and button to open settings
        accessibilityInfoIcon.translatesAutoresizingMaskIntoConstraints = false
        accessibilityOpenButton.translatesAutoresizingMaskIntoConstraints = false
        let axStack = NSStackView(views: [accessibilityInfoIcon, accessibilityOpenButton])
        axStack.orientation = .horizontal
        axStack.alignment = .centerY
        axStack.spacing = 8

        let copyStack = NSStackView(views: [copyBeforeUploadCheckbox, copyChildrenContainer, uploadCopiedFilesCheckbox, saveClipboardToUploadedCheckbox, axStack])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 8
        let copyContent = NSView()
        copyBox.contentView = copyContent
        copyStack.translatesAutoresizingMaskIntoConstraints = false
        copyContent.addSubview(copyStack)
        NSLayoutConstraint.activate([
            copyStack.topAnchor.constraint(equalTo: copyContent.topAnchor, constant: 8),
            copyStack.leadingAnchor.constraint(equalTo: copyContent.leadingAnchor, constant: 12),
            copyStack.trailingAnchor.constraint(equalTo: copyContent.trailingAnchor, constant: -12),
            copyStack.bottomAnchor.constraint(equalTo: copyContent.bottomAnchor, constant: -8)
        ])

        // No extra constraints needed; help button is small and won’t expand width

        // Ensure boxes participate in Auto Layout when adding width constraints
        imageBox.translatesAutoresizingMaskIntoConstraints = false
        hotkeysBox.translatesAutoresizingMaskIntoConstraints = false
        copyBox.translatesAutoresizingMaskIntoConstraints = false

        root.addArrangedSubview(imageBox)
        root.addArrangedSubview(hotkeysBox)
        root.addArrangedSubview(copyBox)

        // Make blocks equal width and centered (fill root width)
        NSLayoutConstraint.activate([
            imageBox.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            imageBox.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            hotkeysBox.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            hotkeysBox.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            copyBox.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            copyBox.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func wire() {
        clipboardFormatControl.target = self; clipboardFormatControl.action = #selector(onFormat)
        jpgQualitySlider.target = self; jpgQualitySlider.action = #selector(onJpgQuality)
        clearButton.target = self; clearButton.action = #selector(onClearHotkey)
        uploadCopiedFilesCheckbox.target = self; uploadCopiedFilesCheckbox.action = #selector(onUploadCopied)
        copyBeforeUploadCheckbox.target = self; copyBeforeUploadCheckbox.action = #selector(onCopyBefore)
        copyOnlyFromMonosnapCheckbox.target = self; copyOnlyFromMonosnapCheckbox.action = #selector(onCopyOnlyFromMonosnap)
        closeMonosnapCheckbox.target = self; closeMonosnapCheckbox.action = #selector(onCloseMonosnap)
        saveClipboardToUploadedCheckbox.target = self; saveClipboardToUploadedCheckbox.action = #selector(onSaveClipboardToUploaded)
        accessibilityOpenButton.target = self; accessibilityOpenButton.action = #selector(onOpenAccessibility)
        closeMonosnapDelayField.target = self; closeMonosnapDelayField.action = #selector(onCloseMonosnapDelay)
    }

    private func load() {
        let isJPG = prefs.clipboardUploadFormat.lowercased() == "jpg"
        clipboardFormatControl.selectedSegment = isJPG ? 1 : 0
        jpgQualitySlider.doubleValue = Double(max(10, prefs.clipboardJpgQuality))
        jpgQualityValueLabel.stringValue = String(Int(jpgQualitySlider.doubleValue))
        updateJpgVisibility()

        hotkeyValueField.stringValue = currentHotkeyDisplayString()

        uploadCopiedFilesCheckbox.state = prefs.uploadCopiedFiles ? .on : .off
        copyBeforeUploadCheckbox.state = prefs.copyBeforeUpload ? .on : .off
        copyOnlyFromMonosnapCheckbox.state = prefs.copyOnlyFromMonosnap ? .on : .off
        closeMonosnapCheckbox.state = prefs.closeMonosnapAfterUpload ? .on : .off
        saveClipboardToUploadedCheckbox.state = prefs.clipboardSaveToUploaded ? .on : .off
        closeMonosnapDelayField.stringValue = String(prefs.monosnapCloseDelayMs)
        // Enable nested options only when parent is on
        copyOnlyFromMonosnapCheckbox.isEnabled = prefs.copyBeforeUpload
        closeMonosnapCheckbox.isEnabled = prefs.copyBeforeUpload
        updateDelayFieldState()
        updateAccessibilityStatus()
    }

    private func updateJpgVisibility() {
        let isJPGSelected = clipboardFormatControl.selectedSegment == 1
        jpgQualityLabel.isHidden = !isJPGSelected
        jpgQualitySlider.isHidden = !isJPGSelected
        jpgQualityValueLabel.isHidden = !isJPGSelected
    }

    // MARK: - Actions
    @objc private func onFormat() { prefs.clipboardUploadFormat = clipboardFormatControl.selectedSegment == 0 ? "png" : "jpg"; updateJpgVisibility() }
    @objc private func onJpgQuality() { let q = Int(jpgQualitySlider.doubleValue); jpgQualityValueLabel.stringValue = "\(q)"; prefs.clipboardJpgQuality = q }
    @objc private func onClearHotkey() {
        stopHotkeyRecording()
        prefs.globalHotkeyString = ""
        prefs.globalHotkeyKeyCode = 0
        prefs.globalHotkeyModifiers = 0
        hotkeyValueField.stringValue = L("settings.hotkey_not_set")
        NotificationCenter.default.post(name: .preferencesHotkeyChanged, object: nil)
    }
    @objc private func onUploadCopied() { prefs.uploadCopiedFiles = (uploadCopiedFilesCheckbox.state == .on) }
    @objc private func onCopyBefore() {
        prefs.copyBeforeUpload = (copyBeforeUploadCheckbox.state == .on)
        let enabled = prefs.copyBeforeUpload
        copyOnlyFromMonosnapCheckbox.isEnabled = enabled
        closeMonosnapCheckbox.isEnabled = enabled
        updateDelayFieldState()
        // Do not change the values of nested checkboxes when disabling
    }
    @objc private func onCopyOnlyFromMonosnap() { prefs.copyOnlyFromMonosnap = (copyOnlyFromMonosnapCheckbox.state == .on) }
    @objc private func onCloseMonosnap() { prefs.closeMonosnapAfterUpload = (closeMonosnapCheckbox.state == .on); updateDelayFieldState() }
    @objc private func onSaveClipboardToUploaded() { prefs.clipboardSaveToUploaded = (saveClipboardToUploadedCheckbox.state == .on) }
    @objc private func onCloseMonosnapDelay() { syncDelayFieldToPreferences() }
}

private extension ClipboardHotkeysSettingsViewController {
    func updateAccessibilityStatus() {
        let granted = SystemIntegration.isAccessibilityTrusted()
        let prefix = granted ? "Разрешен" : "Не разрешен"
        let base = "Доступ к Спец.возможностям: \(prefix). Для корректной работы опций \"Копировать только из Monosnap\" и \"Закрывать окно Monosnap после загрузки\" включите доступ."
        accessibilityInfoIcon.toolTip = base
    }

    @objc func onOpenAccessibility() {
        _ = SystemIntegration.ensureAccessibilityOrInform()
        // Re-check after small delay in case user grants immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateAccessibilityStatus()
        }
    }
}

private extension ClipboardHotkeysSettingsViewController {
    func updateDelayFieldState() {
        let enabled = prefs.copyBeforeUpload && prefs.closeMonosnapAfterUpload
        closeMonosnapDelayLabel.isEnabled = enabled
        closeMonosnapDelayField.isEnabled = enabled
    }
}

extension ClipboardHotkeysSettingsViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        if (obj.object as? NSTextField) === closeMonosnapDelayField { syncDelayFieldToPreferences() }
    }

    @objc private func onDelayChanged(_ note: Notification) {
        if (note.object as? NSTextField) === closeMonosnapDelayField { syncDelayFieldToPreferences() }
    }

    fileprivate func syncDelayFieldToPreferences() {
        let trimmed = closeMonosnapDelayField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Int(trimmed) ?? prefs.monosnapCloseDelayMs
        let clamped = max(0, min(2000, value))
        prefs.monosnapCloseDelayMs = clamped
        closeMonosnapDelayField.stringValue = String(clamped)
    }
}

private extension ClipboardHotkeysSettingsViewController {
    func currentHotkeyDisplayString() -> String {
        let code = prefs.globalHotkeyKeyCode
        let modsRaw = prefs.globalHotkeyModifiers
        if code == 0 && modsRaw == 0 {
            // Fallback to string if present (legacy)
            let s = prefs.globalHotkeyString
            return s.isEmpty ? L("settings.hotkey_not_set") : s
        }
        let flags = NSEvent.ModifierFlags(rawValue: modsRaw)
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.function) { parts.append("Fn") }
        parts.append(keyRepresentation(forKeyCode: UInt16(code)))
        return parts.joined()
    }
}

// MARK: - Hotkey capture
private extension ClipboardHotkeysSettingsViewController {
    func addHotkeyCapture() {
        let click = NSClickGestureRecognizer(target: self, action: #selector(onHotkeyFieldClicked))
        hotkeyValueField.addGestureRecognizer(click)
    }

    @objc func onHotkeyFieldClicked() {
        guard !isRecordingHotkey else { return }
        startHotkeyRecording()
    }

    func startHotkeyRecording() {
        isRecordingHotkey = true
        previousHotkeyString = prefs.globalHotkeyString
        hotkeyValueField.stringValue = L("settings.press_hotkey") // add this key to strings if needed
        clearButton.isEnabled = false

        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecordingHotkey else { return event }
            if event.keyCode == 53 { // Escape cancels
                self.cancelHotkeyRecording()
                return nil
            }
            if let (combo, keyCode, modsRaw) = self.formatHotkey(from: event) {
                self.prefs.globalHotkeyString = combo
                self.prefs.globalHotkeyKeyCode = Int(keyCode)
                self.prefs.globalHotkeyModifiers = modsRaw
                self.hotkeyValueField.stringValue = combo
                NotificationCenter.default.post(name: .preferencesHotkeyChanged, object: nil)
                self.stopHotkeyRecording()
                return nil
            }
            // Ignore events that don't produce a valid combo
            return nil
        }
    }

    func stopHotkeyRecording() {
        isRecordingHotkey = false
        clearButton.isEnabled = true
        if let monitor = hotkeyMonitor { NSEvent.removeMonitor(monitor) }
        hotkeyMonitor = nil
    }

    func cancelHotkeyRecording() {
        hotkeyValueField.stringValue = previousHotkeyString.isEmpty ? L("settings.hotkey_not_set") : previousHotkeyString
        stopHotkeyRecording()
    }

    func formatHotkey(from event: NSEvent) -> (String, UInt16, UInt)? {
        // Require a non-modifier key
        if isModifierOnly(event: event) { return nil }

        let flags = normalizedFlags(from: event.modifierFlags)
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.function) { parts.append("Fn") }

        let key = keyRepresentation(forKeyCode: event.keyCode)
        parts.append(key)
        return (parts.joined(), event.keyCode, flags.rawValue)
    }

    func normalizedFlags(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        var f = flags
        f.remove([.capsLock, .numericPad, .help])
        return f.intersection([.command, .option, .shift, .control, .function])
    }

    func isModifierOnly(event: NSEvent) -> Bool {
        // keyDown for pure modifiers usually doesn't occur; safeguard by mapping keyCode
        let key = keyRepresentation(forKeyCode: event.keyCode)
        return key.isEmpty
    }

    func keyRepresentation(forKeyCode keyCode: UInt16) -> String {
        // Special keys by keyCode (layout-independent)
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 117: return "ForwardDelete"
        case 49: return "Space"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        // US ANSI mapping for letters and digits by keyCode for layout-independent display
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        default:
            return "KeyCode \(keyCode)"
        }
    }
}
