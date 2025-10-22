import Cocoa

final class GeneralSettingsViewController: NSViewController {
    private let prefs = Preferences.shared

    // Folder group
    private let folderBox: NSBox = {
        let b = NSBox()
        b.title = L("settings.general.tracking_folder")
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let folderField = NSTextField()
    private let chooseFolderButton = NSButton(title: L("settings.general.choose_folder"), target: nil, action: nil)

    // Behavior group
    private let behaviorBox: NSBox = {
        let b = NSBox()
        b.title = L("settings.general.behavior")
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let showNotificationsCheckbox = NSButton(checkboxWithTitle: L("settings.show_notifications"), target: nil, action: nil)
    private let enableSoundCheckbox = NSButton(checkboxWithTitle: L("settings.enable_sound"), target: nil, action: nil)
    private let startMonitoringOnLaunchCheckbox = NSButton(checkboxWithTitle: L("settings.start_monitoring_on_launch"), target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: L("settings.launch_at_login"), target: nil, action: nil)
    private let renameOnUploadCheckbox = NSButton(checkboxWithTitle: L("settings.sftp.rename_on_upload"), target: nil, action: nil)
    private let showDockIconCheckbox = NSButton(checkboxWithTitle: L("settings.show_dock_icon"), target: nil, action: nil)
    private let copyURLAfterUploadCheckbox = NSButton(checkboxWithTitle: "Копировать URL в буфер после загрузки", target: nil, action: nil)
    private let openURLAfterUploadCheckbox = NSButton(checkboxWithTitle: "Открывать в браузере после загрузки", target: nil, action: nil)
    private let limitFileSizeCheckbox = NSButton(checkboxWithTitle: L("settings.limit_file_size"), target: nil, action: nil)
    private let maxFileSizeField = NSTextField()
    private let maxFileSizeSuffixLabel = NSTextField(labelWithString: L("settings.max_file_size_mb"))
    private let historySizeLabel = NSTextField(labelWithString: "Записей истории")
    private let historySizeField = NSTextField()

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        load()
        wire()
        maxFileSizeField.delegate = self
        // Live updates while typing: autosave numeric values to preferences
        NotificationCenter.default.addObserver(self, selector: #selector(onMaxFileSizeTyping(_:)), name: NSControl.textDidChangeNotification, object: maxFileSizeField)
        NotificationCenter.default.addObserver(self, selector: #selector(onHistorySizeTyping(_:)), name: NSControl.textDidChangeNotification, object: historySizeField)
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        // Folder box content
        let folderContent = NSView()
        folderBox.contentView = folderContent
        // Configure as an input: click, caret, selection, copy; scrolls with caret
        folderField.translatesAutoresizingMaskIntoConstraints = false
        folderField.isEditable = true
        folderField.isSelectable = true
        folderField.usesSingleLineMode = true
        folderField.maximumNumberOfLines = 1
        folderField.lineBreakMode = .byClipping
        folderField.cell?.isScrollable = true
        folderField.placeholderString = "/Users/…"
        let folderRow = NSStackView(views: [folderField, chooseFolderButton])
        folderRow.spacing = 8
        folderRow.alignment = .firstBaseline
        folderRow.translatesAutoresizingMaskIntoConstraints = false
        chooseFolderButton.bezelStyle = .rounded
        folderContent.addSubview(folderRow)
        NSLayoutConstraint.activate([
            folderRow.topAnchor.constraint(equalTo: folderContent.topAnchor, constant: 8),
            folderRow.leadingAnchor.constraint(equalTo: folderContent.leadingAnchor, constant: 12),
            folderRow.trailingAnchor.constraint(equalTo: folderContent.trailingAnchor, constant: -12),
            folderRow.bottomAnchor.constraint(equalTo: folderContent.bottomAnchor, constant: -8)
        ])
        chooseFolderButton.setContentHuggingPriority(.required, for: .horizontal)
        folderField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Behavior box content
        let sizeRow = NSStackView(views: [limitFileSizeCheckbox, maxFileSizeField, maxFileSizeSuffixLabel])
        sizeRow.alignment = .firstBaseline
        sizeRow.spacing = 8
        let historyRow = NSStackView(views: [historySizeLabel, historySizeField])
        historyRow.alignment = .firstBaseline
        historyRow.spacing = 8
        historySizeLabel.alignment = .right
        historySizeLabel.translatesAutoresizingMaskIntoConstraints = false
        historySizeLabel.widthAnchor.constraint(equalToConstant: 240).isActive = true
        historySizeField.translatesAutoresizingMaskIntoConstraints = false
        historySizeField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        let behaviorStack = NSStackView(views: [
            showNotificationsCheckbox,
            enableSoundCheckbox,
            startMonitoringOnLaunchCheckbox,
            launchAtLoginCheckbox,
            renameOnUploadCheckbox,
            showDockIconCheckbox,
            copyURLAfterUploadCheckbox,
            openURLAfterUploadCheckbox,
            sizeRow,
            historyRow
        ])
        behaviorStack.orientation = .vertical
        behaviorStack.alignment = .leading
        behaviorStack.spacing = 8
        behaviorStack.translatesAutoresizingMaskIntoConstraints = false
        let behaviorContent = NSView()
        behaviorBox.contentView = behaviorContent
        behaviorContent.addSubview(behaviorStack)
        NSLayoutConstraint.activate([
            behaviorStack.topAnchor.constraint(equalTo: behaviorContent.topAnchor, constant: 8),
            behaviorStack.leadingAnchor.constraint(equalTo: behaviorContent.leadingAnchor, constant: 12),
            behaviorStack.trailingAnchor.constraint(equalTo: behaviorContent.trailingAnchor, constant: -12),
            behaviorStack.bottomAnchor.constraint(equalTo: behaviorContent.bottomAnchor, constant: -8)
        ])

        root.addArrangedSubview(folderBox)
        root.addArrangedSubview(behaviorBox)

        // Make blocks equal width and centered (fill root width)
        NSLayoutConstraint.activate([
            folderBox.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            folderBox.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            behaviorBox.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            behaviorBox.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        ])

        maxFileSizeField.placeholderString = "200"
        maxFileSizeField.alignment = .right
        maxFileSizeField.controlSize = .small
        maxFileSizeField.frame.size.width = 60
        // End-edit handling is done via NSTextFieldDelegate

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func wire() {
        chooseFolderButton.target = self; chooseFolderButton.action = #selector(onChooseFolder)

        showNotificationsCheckbox.target = self; showNotificationsCheckbox.action = #selector(onShowNotifications)
        enableSoundCheckbox.target = self; enableSoundCheckbox.action = #selector(onEnableSound)
        startMonitoringOnLaunchCheckbox.target = self; startMonitoringOnLaunchCheckbox.action = #selector(onStartMonitoring)
        launchAtLoginCheckbox.target = self; launchAtLoginCheckbox.action = #selector(onLaunchAtLogin)
        renameOnUploadCheckbox.target = self; renameOnUploadCheckbox.action = #selector(onRenameOnUpload)
        showDockIconCheckbox.target = self; showDockIconCheckbox.action = #selector(onShowDockIcon)
        copyURLAfterUploadCheckbox.target = self; copyURLAfterUploadCheckbox.action = #selector(onCopyURLAfterUpload)
        openURLAfterUploadCheckbox.target = self; openURLAfterUploadCheckbox.action = #selector(onOpenURLAfterUpload)
        limitFileSizeCheckbox.target = self; limitFileSizeCheckbox.action = #selector(onLimitFileSize)
        maxFileSizeField.target = self; maxFileSizeField.action = #selector(onMaxFileSize)
        historySizeField.target = self; historySizeField.action = #selector(onHistorySize)
    }

    private func load() {
        folderField.stringValue = prefs.monitoredFolderPath

        showNotificationsCheckbox.state = prefs.showNotifications ? .on : .off
        enableSoundCheckbox.state = prefs.enableSound ? .on : .off
        startMonitoringOnLaunchCheckbox.state = prefs.startMonitoringOnLaunch ? .on : .off
        launchAtLoginCheckbox.state = prefs.launchAtSystemStartup ? .on : .off
        renameOnUploadCheckbox.state = prefs.renameFileOnUpload ? .on : .off
        showDockIconCheckbox.state = prefs.showDockIcon ? .on : .off
        copyURLAfterUploadCheckbox.state = prefs.copyURLAfterUpload ? .on : .off
        openURLAfterUploadCheckbox.state = prefs.openURLAfterUpload ? .on : .off

        limitFileSizeCheckbox.state = prefs.isMaxFileSizeLimitEnabled ? .on : .off
        maxFileSizeField.stringValue = String(prefs.maxFileSizeLimitMB)
        updateFileSizeEnabled()
        historySizeField.stringValue = String(prefs.historyMaxEntries)
    }

    // MARK: - Actions
    @objc private func onChooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) { [weak self] resp in
            guard let self = self, resp == .OK, let url = panel.url else { return }
            self.folderField.stringValue = url.path
            self.prefs.monitoredFolderPath = url.path
        }
    }

    @objc private func onShowNotifications() { prefs.showNotifications = (showNotificationsCheckbox.state == .on) }
    @objc private func onEnableSound() { prefs.enableSound = (enableSoundCheckbox.state == .on) }
    @objc private func onStartMonitoring() { prefs.startMonitoringOnLaunch = (startMonitoringOnLaunchCheckbox.state == .on) }
    @objc private func onLaunchAtLogin() { prefs.launchAtSystemStartup = (launchAtLoginCheckbox.state == .on) }
    @objc private func onRenameOnUpload() { prefs.renameFileOnUpload = (renameOnUploadCheckbox.state == .on) }
    @objc private func onShowDockIcon() { prefs.showDockIcon = (showDockIconCheckbox.state == .on) }
    @objc private func onCopyURLAfterUpload() { prefs.copyURLAfterUpload = (copyURLAfterUploadCheckbox.state == .on) }
    @objc private func onOpenURLAfterUpload() { prefs.openURLAfterUpload = (openURLAfterUploadCheckbox.state == .on) }
    @objc private func onLimitFileSize() { prefs.isMaxFileSizeLimitEnabled = (limitFileSizeCheckbox.state == .on); updateFileSizeEnabled() }
    @objc private func onMaxFileSize() {
        let trimmed = maxFileSizeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed), value > 0 {
            prefs.maxFileSizeLimitMB = value
        }
        maxFileSizeField.stringValue = String(prefs.maxFileSizeLimitMB)
    }
    @objc private func onHistorySize() {
        let trimmed = historySizeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed), value > 0 {
            prefs.historyMaxEntries = value
        }
        historySizeField.stringValue = String(prefs.historyMaxEntries)
    }

    // Live autosave on every change (typing)
    @objc private func onMaxFileSizeTyping(_ note: Notification) {
        guard note.object as? NSTextField === maxFileSizeField else { return }
        let digits = maxFileSizeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Int(digits), v > 0 {
            prefs.maxFileSizeLimitMB = v
        }
        // Do not rewrite field text here to avoid interfering with typing
    }
    @objc private func onHistorySizeTyping(_ note: Notification) {
        guard note.object as? NSTextField === historySizeField else { return }
        let digits = historySizeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Int(digits), v > 0 {
            prefs.historyMaxEntries = v
        }
    }

    private func updateFileSizeEnabled() {
        let enabled = (limitFileSizeCheckbox.state == .on)
        maxFileSizeField.isEnabled = enabled
        maxFileSizeSuffixLabel.textColor = enabled ? .labelColor : .secondaryLabelColor
    }
}
extension GeneralSettingsViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field == maxFileSizeField { onMaxFileSize() }
        if field == historySizeField { onHistorySize() }
    }
}
