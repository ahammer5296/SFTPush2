import Cocoa
import UserNotifications
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let prefs = Preferences.shared
    private var settingsWC: SettingsWindowController?
    private var statusController: StatusBarController?
    private let history = HistoryStore.shared
    private lazy var uploadService: Uploading = UploadServiceFactory.make(preferences: prefs)
    private let hotkeyCenter = HotkeyCenter()
    private lazy var folderWatcher: FolderWatcher = {
        FolderWatcher(
            preferences: prefs,
            uploadService: uploadService,
            notificationHandler: { [weak self] message in
                self?.sendNotification(message)
            },
            activityHandler: { [weak self] uploading in
                self?.updateUploadingIndicator(uploading)
            }
        )
    }()
    private lazy var clipboardUploader: ClipboardUploader = {
        ClipboardUploader(
            preferences: prefs,
            uploadService: uploadService,
            notificationHandler: { [weak self] message in
                self?.sendNotification(message)
            },
            activityHandler: { [weak self] uploading in
                self?.updateUploadingIndicator(uploading)
            }
        )
    }()
    
    // Dock animation
    private var dockAnimationTimer: Timer?
    private var dockAnimationFrames: [NSImage] = []
    private var currentDockFrameIndex = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply initial dock visibility
        NSApp.setActivationPolicy(prefs.showDockIcon ? .regular : .accessory)
        NSApp.applicationIconImage = NSImage(named: NSImage.applicationIconName)

        // Build status bar UI
        let sbc = StatusBarController()
        sbc.onUploadFromClipboard = { [weak self] in self?.handleUploadFromClipboard() }
        sbc.onToggleMonitoring = { [weak self] in self?.toggleMonitoring() }
        sbc.onOpenSettings = { [weak self] in self?.openSettings() }
        sbc.onTestNotification = { [weak self] in self?.sendNotification(title: "Тестовое уведомление", body: "Это проверка.") }
        sbc.onQuit = { NSApp.terminate(nil) }
        sbc.onUploadingChanged = { [weak self] uploading in
            uploading ? self?.startDockIconAnimation() : self?.stopDockIconAnimation()
        }
        sbc.onFilesDropped = { [weak self] urls in
            self?.clipboardUploader.uploadFiles(urls: urls)
        }
        sbc.onHistoryItemSelected = { [weak self] entry, forceOpen in
            guard let self, let url = entry.url else { return }
            self.copyURLToClipboard(url)
            self.sendNotification(UploadNotificationMessage(title: "URL скопирован", body: entry.name, url: url))
            if forceOpen {
                NSWorkspace.shared.open(url)
            }
        }
        statusController = sbc

        // Notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        registerNotificationCategories()

        // Observe preferences
        NotificationCenter.default.addObserver(self, selector: #selector(handleShowDockIconChanged(_:)), name: .preferencesShowDockIconChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHotkeyChanged(_:)), name: .preferencesHotkeyChanged, object: nil)

        statusController?.setMonitoring(false)
        if prefs.startMonitoringOnLaunch {
            _ = startMonitoring(showFailure: false)
        }

        // Register global hotkey if set
        setupGlobalHotkey()

        // Populate history menu on launch
        statusController?.setHistoryEntries(history.all())
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register Apple Events early, in case odoc arrives during launch
        registerAppleEventHandlers()
    }

    // MARK: - Actions (stubs)
    private func handleUploadFromClipboard() {
        if prefs.copyBeforeUpload {
            if prefs.copyOnlyFromMonosnap {
                if SystemIntegration.isFrontAppMonosnap() {
                    SystemIntegration.sendCmdC()
                }
            } else {
                if !SystemIntegration.isFrontAppFinder() {
                    SystemIntegration.sendCmdC()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.clipboardUploader.uploadFromClipboard()
            }
        } else {
            clipboardUploader.uploadFromClipboard()
        }
    }

    private func toggleMonitoring() {
        if folderWatcher.isRunning {
            folderWatcher.stop()
            statusController?.setMonitoring(false)
        } else {
            if !startMonitoring(showFailure: true) {
                statusController?.setMonitoring(false)
            }
        }
    }

    private func openSettings() {
        if settingsWC == nil { settingsWC = SettingsWindowController() }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func sendNotification(title: String, body: String) {
        let message = UploadNotificationMessage(title: title, body: body, url: nil)
        sendNotification(message)
    }

    private func sendNotification(_ message: UploadNotificationMessage) {
        // Special history-only message: add to history silently
        if message.title == "__HISTORY__", let url = message.url {
            history.add(name: message.body, url: url)
            statusController?.setHistoryEntries(history.all())
            return
        }
        // Record per-file success
        if message.title == "Файл загружен", let url = message.url {
            history.add(name: message.body, url: url)
            statusController?.setHistoryEntries(history.all())
        }

        // Post-upload actions
        if let url = message.url {
            if prefs.copyURLAfterUpload { copyURLToClipboard(url) }
            if prefs.openURLAfterUpload { NSWorkspace.shared.open(url) }
        }

        guard prefs.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        if prefs.enableSound { content.sound = .default }
        if let url = message.url {
            content.userInfo["openURL"] = url.absoluteString
            content.categoryIdentifier = NotificationCategory.uploadResult.rawValue
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let urlString = response.notification.request.content.userInfo["openURL"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }

    // MARK: - Observers
    @objc private func handleShowDockIconChanged(_ note: Notification) {
        let visible = (note.userInfo?["value"] as? Bool) ?? true
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        if !visible {
            // Ensure focus returns to UI if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Monitoring
    @discardableResult
    private func startMonitoring(showFailure: Bool) -> Bool {
        if folderWatcher.isRunning {
            statusController?.setMonitoring(true)
            return true
        }
        do {
            try folderWatcher.start()
            statusController?.setMonitoring(true)
            return true
        } catch FolderWatcher.WatcherError.folderMissing {
            if showFailure {
                sendNotification(title: "Мониторинг недоступен", body: "Укажите папку в настройках.")
            }
        } catch FolderWatcher.WatcherError.failedToOpenDescriptor {
            if showFailure {
                sendNotification(title: "Мониторинг недоступен", body: "Не удалось открыть папку для наблюдения.")
            }
        } catch {
            if showFailure {
                sendNotification(title: "Мониторинг недоступен", body: error.localizedDescription)
            }
        }
        return false
    }

    private func updateUploadingIndicator(_ uploading: Bool) {
        statusController?.setUploadingIndicator(uploading)
    }

    // MARK: - Hotkey
    private func setupGlobalHotkey() {
        let code = UInt16(prefs.globalHotkeyKeyCode)
        let mods = prefs.globalHotkeyModifiers
        if code != 0 && mods != 0 {
            hotkeyCenter.onHotkey = { [weak self] in
                guard let self else { return }
                if !self.prefs.uploadCopiedFiles {
                    self.sendNotification(title: "Горячая клавиша выключена", body: "Включите опцию 'Загружать скопированные файлы' в настройках.")
                    return
                }
                // Pre-copy behavior per preferences
                if self.prefs.copyBeforeUpload {
                    if self.prefs.copyOnlyFromMonosnap {
                        if SystemIntegration.isFrontAppMonosnap() {
                            SystemIntegration.sendCmdC()
                        }
                    } else {
                        if !SystemIntegration.isFrontAppFinder() {
                            SystemIntegration.sendCmdC()
                        }
                    }
                }
                // Small delay to allow clipboard to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.clipboardUploader.uploadFromClipboard()
                }
            }
            hotkeyCenter.register(keyCode: code, modifiers: mods)
        } else {
            hotkeyCenter.unregister()
        }
    }

    @objc private func handleHotkeyChanged(_ note: Notification) {
        setupGlobalHotkey()
    }

    private func copyURLToClipboard(_ url: URL) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .string)
        }
    }

    private func registerNotificationCategories() {
        let uploadCategory = UNNotificationCategory(identifier: NotificationCategory.uploadResult.rawValue, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories(Set([uploadCategory]))
    }

    // MARK: - Dock icon animation
    private func startDockIconAnimation() {
        guard dockAnimationTimer == nil else { return }
        dockAnimationFrames = [
            NSImage(named: "dock_loading_frame_1"),
            NSImage(named: "dock_loading_frame_2"),
            NSImage(named: "dock_loading_frame_3"),
        ].compactMap { $0 }
        guard !dockAnimationFrames.isEmpty else { return }
        currentDockFrameIndex = 0
        dockAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self] _ in
            guard let self = self, !self.dockAnimationFrames.isEmpty else { return }
            DispatchQueue.main.async {
                NSApp.applicationIconImage = self.dockAnimationFrames[self.currentDockFrameIndex]
            }
            self.currentDockFrameIndex = (self.currentDockFrameIndex + 1) % self.dockAnimationFrames.count
        })
        if let t = dockAnimationTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopDockIconAnimation() {
        dockAnimationTimer?.invalidate()
        dockAnimationTimer = nil
        currentDockFrameIndex = 0
        DispatchQueue.main.async {
            NSApp.applicationIconImage = NSImage(named: NSImage.applicationIconName)
        }
    }
}

// MARK: - Drag & Drop on Dock icon
extension AppDelegate {
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        clipboardUploader.uploadFiles(urls: [URL(fileURLWithPath: filename)])
        NSApp.reply(toOpenOrPrint: .success)
        return true
    }
    func application(_ sender: NSApplication, openFiles fileNames: [String]) {
        let urls = fileNames.map { URL(fileURLWithPath: $0) }
        clipboardUploader.uploadFiles(urls: urls)
        NSApp.reply(toOpenOrPrint: .success)
    }
}

// MARK: - Apple Events (odoc)
private extension AppDelegate {
    func registerAppleEventHandlers() {
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(self,
                                 andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
                                 forEventClass: AEEventClass(kCoreEventClass),
                                 andEventID: AEEventID(kAEOpenDocuments))
    }

    @objc func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        var urls: [URL] = []
        if let direct = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) {
            if direct.numberOfItems > 0 {
                for idx in 1...direct.numberOfItems {
                    if let item = direct.atIndex(idx), let s = item.stringValue {
                        if s.hasPrefix("file://"), let u = URL(string: s) {
                            urls.append(u)
                        } else {
                            urls.append(URL(fileURLWithPath: s))
                        }
                    }
                }
            } else if let s = direct.stringValue {
                if s.hasPrefix("file://"), let u = URL(string: s) {
                    urls.append(u)
                } else {
                    urls.append(URL(fileURLWithPath: s))
                }
            }
        }
        if !urls.isEmpty {
            clipboardUploader.uploadFiles(urls: urls)
        }
        NSApp.reply(toOpenOrPrint: .success)
    }
}

private enum NotificationCategory: String {
    case uploadResult = "upload.result"
}

enum MenuBarIconFactory {
    static func makeTemplateIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        // Draw a simple filled circle (template uses mask)
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        NSColor.black.setFill()
        path.fill()
        image.unlockFocus()
        return image
    }

    static func makeDockIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        // Background
        NSColor(calibratedRed: 0.18, green: 0.53, blue: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: size.width/5, yRadius: size.height/5).fill()
        // Foreground symbol (white cloud-like arc)
        NSColor.white.setStroke()
        let path = NSBezierPath()
        let midY = rect.midY
        let margin: CGFloat = size.width * 0.18
        path.move(to: NSPoint(x: margin, y: midY))
        path.curve(to: NSPoint(x: rect.maxX - margin, y: midY),
                   controlPoint1: NSPoint(x: rect.midX - size.width*0.20, y: midY + size.height*0.18),
                   controlPoint2: NSPoint(x: rect.midX + size.width*0.20, y: midY + size.height*0.18))
        path.lineWidth = max(4, size.width * 0.06)
        path.stroke()
        image.unlockFocus()
        return image
    }
}
