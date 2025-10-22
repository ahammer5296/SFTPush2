import Cocoa

final class SettingsViewController: NSViewController {
    private let showDockIconCheckbox = NSButton(checkboxWithTitle: L("settings.show_dock_icon"), target: nil, action: nil)
    private let showNotificationsCheckbox = NSButton(checkboxWithTitle: L("settings.show_notifications"), target: nil, action: nil)
    private let enableSoundCheckbox = NSButton(checkboxWithTitle: L("settings.enable_sound"), target: nil, action: nil)

    private let uploadCopiedFilesCheckbox = NSButton(checkboxWithTitle: L("settings.upload_copied_files"), target: nil, action: nil)
    private let limitFileSizeCheckbox = NSButton(checkboxWithTitle: L("settings.limit_file_size"), target: nil, action: nil)
    private let maxFileSizeField = NSTextField()
    private let maxFileSizeSuffixLabel = NSTextField(labelWithString: L("settings.max_file_size_mb"))

    private let clipboardFormatLabel = NSTextField(labelWithString: L("settings.clipboard_format"))
    private let clipboardFormatControl = NSSegmentedControl(labels: [L("settings.clipboard_format_png"), L("settings.clipboard_format_jpg")], trackingMode: .selectOne, target: nil, action: nil)
    private let jpgQualityLabel = NSTextField(labelWithString: L("settings.jpg_quality"))
    private let jpgQualitySlider: NSSlider = {
        let s = NSSlider(value: 80, minValue: 0, maxValue: 100, target: nil, action: nil)
        s.numberOfTickMarks = 6
        return s
    }()
    private let jpgQualityValueLabel = NSTextField(labelWithString: "80")

    private let copyBeforeUploadCheckbox = NSButton(checkboxWithTitle: L("settings.copy_before_upload"), target: nil, action: nil)
    private let copyOnlyFromMonosnapCheckbox = NSButton(checkboxWithTitle: L("settings.copy_only_from_monosnap"), target: nil, action: nil)

    private let startMonitoringOnLaunchCheckbox = NSButton(checkboxWithTitle: L("settings.start_monitoring_on_launch"), target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: L("settings.launch_at_login"), target: nil, action: nil)

    private let noteLabel: NSTextField = {
        let label = NSTextField(labelWithString: L("settings.note_applies_immediately"))
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let prefs = Preferences.shared

    override func loadView() { self.view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadFromPreferences()
        wireActions()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        // First block
        stack.addArrangedSubview(showDockIconCheckbox)
        stack.addArrangedSubview(showNotificationsCheckbox)
        stack.addArrangedSubview(enableSoundCheckbox)

        // Clipboard block
        stack.addArrangedSubview(uploadCopiedFilesCheckbox)

        let formatRow = NSStackView(views: [clipboardFormatLabel, clipboardFormatControl])
        formatRow.spacing = 8
        formatRow.alignment = .centerY
        stack.addArrangedSubview(formatRow)

        let jpgRow = NSStackView(views: [jpgQualityLabel, jpgQualitySlider, jpgQualityValueLabel])
        jpgRow.spacing = 8
        jpgRow.alignment = .centerY
        stack.addArrangedSubview(jpgRow)

        // File size block
        let sizeRow = NSStackView(views: [limitFileSizeCheckbox, maxFileSizeField, maxFileSizeSuffixLabel])
        sizeRow.spacing = 8
        sizeRow.alignment = .firstBaseline
        stack.addArrangedSubview(sizeRow)

        // Copy behavior block
        stack.addArrangedSubview(copyBeforeUploadCheckbox)
        stack.addArrangedSubview(copyOnlyFromMonosnapCheckbox)

        // Monitoring / launch
        stack.addArrangedSubview(startMonitoringOnLaunchCheckbox)
        stack.addArrangedSubview(launchAtLoginCheckbox)

        // Note
        stack.addArrangedSubview(noteLabel)

        view.addSubview(stack)

        maxFileSizeField.placeholderString = "200"
        maxFileSizeField.alignment = .right
        maxFileSizeField.controlSize = .small
        maxFileSizeField.frame.size.width = 60
        clipboardFormatControl.selectedSegment = 0

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            view.trailingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 24),
            view.bottomAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 24)
        ])
    }

    private func wireActions() {
        showDockIconCheckbox.target = self; showDockIconCheckbox.action = #selector(showDockIconChanged)
        showNotificationsCheckbox.target = self; showNotificationsCheckbox.action = #selector(showNotificationsChanged)
        enableSoundCheckbox.target = self; enableSoundCheckbox.action = #selector(enableSoundChanged)

        uploadCopiedFilesCheckbox.target = self; uploadCopiedFilesCheckbox.action = #selector(uploadCopiedFilesChanged)
        limitFileSizeCheckbox.target = self; limitFileSizeCheckbox.action = #selector(limitFileSizeChanged)
        maxFileSizeField.target = self; maxFileSizeField.action = #selector(maxFileSizeChanged)

        clipboardFormatControl.target = self; clipboardFormatControl.action = #selector(clipboardFormatChanged)
        jpgQualitySlider.target = self; jpgQualitySlider.action = #selector(jpgQualitySliderChanged)

        copyBeforeUploadCheckbox.target = self; copyBeforeUploadCheckbox.action = #selector(copyBeforeUploadChanged)
        copyOnlyFromMonosnapCheckbox.target = self; copyOnlyFromMonosnapCheckbox.action = #selector(copyOnlyFromMonosnapChanged)

        startMonitoringOnLaunchCheckbox.target = self; startMonitoringOnLaunchCheckbox.action = #selector(startMonitoringOnLaunchChanged)
        launchAtLoginCheckbox.target = self; launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
    }

    private func loadFromPreferences() {
        showDockIconCheckbox.state = prefs.showDockIcon ? .on : .off
        showNotificationsCheckbox.state = prefs.showNotifications ? .on : .off
        enableSoundCheckbox.state = prefs.enableSound ? .on : .off

        uploadCopiedFilesCheckbox.state = prefs.uploadCopiedFiles ? .on : .off
        limitFileSizeCheckbox.state = prefs.isMaxFileSizeLimitEnabled ? .on : .off
        maxFileSizeField.stringValue = String(prefs.maxFileSizeLimitMB)
        updateFileSizeLimitUIState()

        let isJPG = (prefs.clipboardUploadFormat.lowercased() == "jpg")
        clipboardFormatControl.selectedSegment = isJPG ? 1 : 0
        jpgQualitySlider.doubleValue = Double(prefs.clipboardJpgQuality)
        jpgQualityValueLabel.stringValue = String(prefs.clipboardJpgQuality)
        updateJpgQualityVisibility()

        copyBeforeUploadCheckbox.state = prefs.copyBeforeUpload ? .on : .off
        copyOnlyFromMonosnapCheckbox.state = prefs.copyOnlyFromMonosnap ? .on : .off
        copyOnlyFromMonosnapCheckbox.isEnabled = prefs.copyBeforeUpload

        startMonitoringOnLaunchCheckbox.state = prefs.startMonitoringOnLaunch ? .on : .off
        launchAtLoginCheckbox.state = prefs.launchAtSystemStartup ? .on : .off
    }

    // MARK: - Actions
    @objc private func showDockIconChanged() { prefs.showDockIcon = (showDockIconCheckbox.state == .on) }
    @objc private func showNotificationsChanged() { prefs.showNotifications = (showNotificationsCheckbox.state == .on) }
    @objc private func enableSoundChanged() { prefs.enableSound = (enableSoundCheckbox.state == .on) }

    @objc private func uploadCopiedFilesChanged() { prefs.uploadCopiedFiles = (uploadCopiedFilesCheckbox.state == .on) }

    @objc private func limitFileSizeChanged() {
        prefs.isMaxFileSizeLimitEnabled = (limitFileSizeCheckbox.state == .on)
        updateFileSizeLimitUIState()
    }

    @objc private func maxFileSizeChanged() {
        let value = Int(maxFileSizeField.stringValue) ?? prefs.maxFileSizeLimitMB
        prefs.maxFileSizeLimitMB = value
        maxFileSizeField.stringValue = String(prefs.maxFileSizeLimitMB)
    }

    @objc private func clipboardFormatChanged() {
        prefs.clipboardUploadFormat = clipboardFormatControl.selectedSegment == 0 ? "png" : "jpg"
        updateJpgQualityVisibility()
    }

    @objc private func jpgQualitySliderChanged() {
        let quality = Int(jpgQualitySlider.doubleValue)
        jpgQualityValueLabel.stringValue = "\(quality)"
        prefs.clipboardJpgQuality = quality
    }

    @objc private func copyBeforeUploadChanged() {
        prefs.copyBeforeUpload = (copyBeforeUploadCheckbox.state == .on)
        updateMonosnapCheckboxState()
    }

    @objc private func copyOnlyFromMonosnapChanged() {
        prefs.copyOnlyFromMonosnap = (copyOnlyFromMonosnapCheckbox.state == .on)
    }

    @objc private func startMonitoringOnLaunchChanged() { prefs.startMonitoringOnLaunch = (startMonitoringOnLaunchCheckbox.state == .on) }
    @objc private func launchAtLoginChanged() { prefs.launchAtSystemStartup = (launchAtLoginCheckbox.state == .on) }

    private func updateJpgQualityVisibility() {
        let isJPGSelected = clipboardFormatControl.selectedSegment == 1 // 0 PNG, 1 JPG
        jpgQualityLabel.isHidden = !isJPGSelected
        jpgQualitySlider.isHidden = !isJPGSelected
        jpgQualityValueLabel.isHidden = !isJPGSelected
    }

    private func updateMonosnapCheckboxState() {
        let enabled = (copyBeforeUploadCheckbox.state == .on)
        if !enabled { copyOnlyFromMonosnapCheckbox.state = .off }
        copyOnlyFromMonosnapCheckbox.isEnabled = enabled
    }

    private func updateFileSizeLimitUIState() {
        let enabled = (limitFileSizeCheckbox.state == .on)
        maxFileSizeField.isEnabled = enabled
        maxFileSizeSuffixLabel.textColor = enabled ? .labelColor : .secondaryLabelColor
    }
}

