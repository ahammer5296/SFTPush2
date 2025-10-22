import Cocoa

final class StatusBarController: NSObject {
    private(set) var statusItem: NSStatusItem
    private let menu = NSMenu()

    // Exposed menu actions via closures for decoupling
    var onUploadFromClipboard: (() -> Void)?
    var onToggleMonitoring: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onTestNotification: (() -> Void)?
    var onQuit: (() -> Void)?
    var onUploadingChanged: ((Bool) -> Void)? // notify AppDelegate to animate Dock
    var onFilesDropped: (([URL]) -> Void)? // drag & drop to status item

    // Menu items
    private let statusLabelItem = NSMenuItem(title: L("menu.status.stopped"), action: nil, keyEquivalent: "")
    private let toggleMonitoringItem = NSMenuItem(title: L("menu.toggle_monitoring.start"), action: #selector(toggleMonitoring), keyEquivalent: "")
    private let historyRootItem = NSMenuItem(title: "История", action: nil, keyEquivalent: "")

    // State
    private var isMonitoring = false
    private var isUploading = false

    // Animation
    private var animTimer: Timer?
    private var animFrames: [NSImage] = []
    private var animIndex = 0
    private let historyMenu = NSMenu()
    private let thumbCache = NSCache<NSString, NSImage>()
    private var loadingThumbs = Set<String>()
    private let thumbSize = NSSize(width: 18, height: 18)
    private let imageExtensions: Set<String> = ["png","jpg","jpeg","gif","heic","heif","webp","bmp","tif","tiff"]
    private var previewPopover: NSPopover?
    private var dragView: StatusItemDragView?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                if let img = NSImage(named: "MenuBarIcon") {
                    img.isTemplate = true
                    button.image = img
                } else {
                    // Fallback text if asset missing
                    button.title = "MBP"
                }
                button.toolTip = L("statusbar.tooltip")
                // Install drag receiver overlay once
                if self.dragView == nil {
                    let dv = StatusItemDragView(onDrop: { [weak self] urls in
                        self?.onFilesDropped?(urls)
                    })
                    self.dragView = dv
                    button.addSubview(dv)
                    NSLayoutConstraint.activate([
                        dv.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                        dv.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                        dv.topAnchor.constraint(equalTo: button.topAnchor),
                        dv.bottomAnchor.constraint(equalTo: button.bottomAnchor)
                    ])
                }
            }
        }
    }

    private func buildMenu() {
        menu.removeAllItems()
        let upload = NSMenuItem(title: L("menu.upload_from_clipboard"), action: #selector(uploadFromClipboard), keyEquivalent: "v")
        upload.target = self
        menu.addItem(upload)
        menu.addItem(NSMenuItem.separator())

        toggleMonitoringItem.target = self
        menu.addItem(toggleMonitoringItem)

        statusLabelItem.isEnabled = false
        menu.addItem(statusLabelItem)

        // History submenu
        historyRootItem.submenu = historyMenu
        menu.addItem(historyRootItem)

        menu.addItem(NSMenuItem.separator())
        let settings = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let test = NSMenuItem(title: L("menu.test_notification"), action: #selector(testNotification), keyEquivalent: "")
        test.target = self
        menu.addItem(test)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateMenuStatus()
        rebuildHistoryMenu()
    }

    func setMonitoring(_ enabled: Bool) {
        isMonitoring = enabled
        updateMenuStatus()
    }

    private func updateMenuStatus() {
        toggleMonitoringItem.title = isMonitoring ? L("menu.toggle_monitoring.stop") : L("menu.toggle_monitoring.start")
        statusLabelItem.title = isMonitoring ? L("menu.status.running") : L("menu.status.stopped")
    }

    // No-op; kept for compatibility if needed

    // MARK: - Upload animation (Status bar)
    private func startStatusAnimation() {
        guard animTimer == nil else { return }
        animFrames = [
            NSImage(named: "loading_frame_1"),
            NSImage(named: "loading_frame_2"),
            NSImage(named: "loading_frame_3"),
        ].compactMap { $0 }
        DispatchQueue.main.async {
            guard let button = self.statusItem.button, !self.animFrames.isEmpty else { return }
            self.animIndex = 0
            button.image = self.animFrames.first
            self.animTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self = self, let button = self.statusItem.button, !self.animFrames.isEmpty else { return }
                self.animIndex = (self.animIndex + 1) % self.animFrames.count
                button.image = self.animFrames[self.animIndex]
            }
            if let t = self.animTimer {
                RunLoop.main.add(t, forMode: .common)
            }
        }
    }

    private func stopStatusAnimation() {
        DispatchQueue.main.async {
            self.animTimer?.invalidate()
            self.animTimer = nil
            self.animFrames.removeAll()
            self.configureButton() // restore base icon/text
        }
    }

    func setUploadingIndicator(_ uploading: Bool) {
        isUploading = uploading
        uploading ? startStatusAnimation() : stopStatusAnimation()
        onUploadingChanged?(uploading)
    }

    // MARK: - Actions
    @objc private func uploadFromClipboard() { onUploadFromClipboard?() }
    @objc private func toggleMonitoring() { isMonitoring.toggle(); updateMenuStatus(); onToggleMonitoring?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func testNotification() { onTestNotification?() }
    @objc private func quitApp() { onQuit?() }
    // MARK: - History
    func setHistoryEntries(_ entries: [UploadHistoryEntry]) {
        rebuildHistoryMenu(entries)
    }

    private func rebuildHistoryMenu(_ entries: [UploadHistoryEntry]? = nil) {
        let list = entries ?? []
        historyMenu.removeAllItems()
        if list.isEmpty {
            let empty = NSMenuItem(title: "Пусто", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
            return
        }
        for e in list {
            let title = e.name
            let item = NSMenuItem()
            item.title = title
            item.representedObject = e
            item.target = self
            item.action = #selector(handleHistoryClick(_:))
            configureThumbnail(for: e, on: item)

            // Custom view to support hover preview
            let hv = HistoryMenuItemView(title: title, icon: item.image)
            hv.onClick = { [weak self, weak item] flags in
                guard let self, let item else { return }
                let forceOpen = flags.contains(.command)
                self.handleHistoryClick(item, forceOpen: forceOpen)
            }
            hv.onHoverPreview = { [weak self, weak item] v in
                guard let self, let item, let entry = item.representedObject as? UploadHistoryEntry else { return }
                self.showPreview(for: entry, from: v)
            }
            hv.onHoverEnd = { [weak self] in self?.hidePreview() }
            item.view = hv
            historyMenu.addItem(item)
        }
    }

    @objc private func handleHistoryClick(_ sender: NSMenuItem) {
        handleHistoryClick(sender, forceOpen: false)
    }

    private func handleHistoryClick(_ sender: NSMenuItem, forceOpen: Bool) {
        guard let entry = sender.representedObject as? UploadHistoryEntry else { return }
        onHistoryItemSelected?(entry, forceOpen)
    }

    var onHistoryItemSelected: ((UploadHistoryEntry, Bool) -> Void)?

    // MARK: - Thumbnails
    private func configureThumbnail(for entry: UploadHistoryEntry, on item: NSMenuItem) {
        guard let url = entry.url else {
            setFileTypeIcon(for: item, ext: nil)
            return
        }
        let ext = url.pathExtension.lowercased()
        // If likely image, try load remote thumbnail
        if imageExtensions.contains(ext), url.scheme?.hasPrefix("http") == true {
            let key = url.absoluteString as NSString
            if let cached = thumbCache.object(forKey: key) {
                item.image = resized(cached, to: thumbSize)
                return
            }
            if loadingThumbs.contains(url.absoluteString) {
                setFileTypeIcon(for: item, ext: ext)
                return
            }
            loadingThumbs.insert(url.absoluteString)
            setFileTypeIcon(for: item, ext: ext) // placeholder
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self else { return }
                self.loadingThumbs.remove(url.absoluteString)
                if let d = data, let img = NSImage(data: d) {
                    self.thumbCache.setObject(img, forKey: key)
                    DispatchQueue.main.async {
                        let resized = self.resized(img, to: self.thumbSize)
                        item.image = resized
                        (item.view as? HistoryMenuItemView)?.updateIcon(resized)
                    }
                }
            }.resume()
        } else {
            setFileTypeIcon(for: item, ext: ext)
        }
    }

    private func setFileTypeIcon(for item: NSMenuItem, ext: String?) {
        let icon: NSImage
        if let ext = ext, !ext.isEmpty {
            icon = NSWorkspace.shared.icon(forFileType: ext)
        } else {
            icon = NSWorkspace.shared.icon(forFileType: "public.data")
        }
        icon.size = thumbSize
        item.image = icon
    }

    private func resized(_ image: NSImage, to target: NSSize) -> NSImage {
        let result = NSImage(size: target)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: target)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    // MARK: - Large preview popover
    private func showPreview(for entry: UploadHistoryEntry, from anchorView: NSView) {
        guard let url = entry.url else { return }
        let ext = url.pathExtension.lowercased()
        guard imageExtensions.contains(ext), url.scheme?.hasPrefix("http") == true else { return }

        func present(image: NSImage) {
            let maxSide: CGFloat = 250
            let size = image.size
            let scale = min(1.0, min(maxSide / max(size.width, 1), maxSide / max(size.height, 1)))
            let target = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))

            let iv = NSImageView(frame: NSRect(origin: .zero, size: target))
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.image = image

            let vc = NSViewController()
            vc.view = iv

            hidePreview()
            let pop = NSPopover()
            pop.behavior = .transient
            pop.contentViewController = vc
            pop.contentSize = target

            // Choose preferred side: left by default, fallback to right if not enough space
            let preferredEdge: NSRectEdge = preferredEdgeForPopover(size: target, anchorView: anchorView)
            pop.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: preferredEdge)
            previewPopover = pop
        }

        let key = url.absoluteString as NSString
        if let cached = thumbCache.object(forKey: key) {
            present(image: cached)
            return
        }
        // Fetch if not cached yet
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let d = data, let img = NSImage(data: d) {
                self.thumbCache.setObject(img, forKey: key)
                DispatchQueue.main.async { present(image: img) }
            }
        }.resume()
    }

    private func hidePreview() {
        previewPopover?.close()
        previewPopover = nil
    }

    private func preferredEdgeForPopover(size: NSSize, anchorView: NSView) -> NSRectEdge {
        guard let window = anchorView.window, let screen = window.screen else {
            return .minX // default to left
        }
        // Convert anchorView bounds to screen coordinates
        let rectInWindow = anchorView.convert(anchorView.bounds, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)
        let vis = screen.visibleFrame
        let margin: CGFloat = 16
        let roomLeft = rectOnScreen.minX - vis.minX
        let roomRight = vis.maxX - rectOnScreen.maxX
        // Prefer left
        if roomLeft >= size.width + margin { return .minX }
        if roomRight >= size.width + margin { return .maxX }
        // If nowhere fits, still prefer left
        return .minX
    }
}
