import Cocoa

final class SettingsWindowController: NSWindowController {
    enum Section: String, CaseIterable {
        case general, sftp, clipboard
        var title: String {
            switch self {
            case .general: return L("settings.section.general")
            case .sftp: return L("settings.section.sftp")
            case .clipboard: return L("settings.section.clipboard_hotkeys")
            }
        }
        var index: Int { Section.allCases.firstIndex(of: self)! }
        static func from(index: Int) -> Section { Section.allCases[index] }
    }

    // Fixed width, variable height
    private let fixedContentWidth: CGFloat = 500
    private let horizontalPadding: CGFloat = 24
    private let verticalPadding: CGFloat = 24
    private let topOffset: CGFloat = 40 // distance from top screen edge

    private let segment: NSSegmentedControl = {
        let labels = [
            L("settings.section.general"),
            L("settings.section.sftp"),
            L("settings.section.clipboard_hotkeys")
        ]
        let s = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        s.selectedSegment = 0
        return s
    }()
    private let container = NSView()

    private let generalVC = GeneralSettingsViewController()
    private let sftpVC = SFTPSettingsViewController()
    private let clipboardVC = ClipboardHotkeysSettingsViewController()
    private var current: Section = .general

    convenience init() {
        let window = NSWindow()
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
        switchTo(.general)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        positionAtTopCenter()
    }

    override func close() {
        // Завершаем редактирование, чтобы поля сохранили значения
        window?.endEditing(for: nil)
        super.close()
    }

    private func buildUI() {
        guard let window = window else { return }
        guard let root = window.contentView else { return }

        segment.target = self
        segment.action = #selector(onSegmentChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(segment)
        root.addSubview(container)

        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: root.topAnchor, constant: verticalPadding),
            segment.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: horizontalPadding),
            segment.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -horizontalPadding),

            container.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: horizontalPadding),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -horizontalPadding),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -verticalPadding)
        ])

        // Fix window width
        window.contentMinSize.width = fixedContentWidth
        window.contentMaxSize.width = fixedContentWidth
        window.setContentSize(NSSize(width: fixedContentWidth, height: 420))
    }

    @objc private func onSegmentChanged() {
        switchTo(Section.from(index: segment.selectedSegment))
    }

    private func switchTo(_ section: Section) {
        // Перед сменой секции завершаем редактирование активного поля
        window?.endEditing(for: nil)
        current = section
        window?.title = section.title

        // Replace container content
        container.subviews.forEach { $0.removeFromSuperview() }
        let newView: NSView
        switch section {
        case .general: newView = generalVC.view
        case .sftp: newView = sftpVC.view
        case .clipboard: newView = clipboardVC.view
        }
        newView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(newView)
        NSLayoutConstraint.activate([
            newView.topAnchor.constraint(equalTo: container.topAnchor),
            newView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            newView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            newView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.layoutSubtreeIfNeeded()
        updateWindowHeightToFit()
    }

    private func updateWindowHeightToFit() {
        guard let window = window, let root = window.contentView else { return }
        root.layoutSubtreeIfNeeded()
        let segH = segment.fittingSize.height
        let contentH = container.fittingSize.height
        let total = verticalPadding + segH + 16 + contentH + verticalPadding
        let minHeight: CGFloat = 320
        let newHeight = max(minHeight, total)

        // Resize without changing current on-screen position (keep top-left)
        let oldFrame = window.frame
        let maxY = oldFrame.maxY
        window.setContentSize(NSSize(width: fixedContentWidth, height: newHeight))
        var newFrame = window.frame
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = maxY - newFrame.size.height
        window.setFrame(newFrame, display: true, animate: false)
    }

    private func positionAtTopCenter() {
        setWindowContentSizeAnchored(width: fixedContentWidth, height: window?.frame.size.height ?? 420)
    }

    private func setWindowContentSizeAnchored(width: CGFloat, height: CGFloat) {
        guard let window = window else { return }
        window.setContentSize(NSSize(width: width, height: height))
        let screen = window.screen ?? NSScreen.main
        guard let vis = screen?.visibleFrame else { return }
        let x = vis.minX + (vis.width - window.frame.size.width) / 2
        let y = vis.maxY - window.frame.size.height - topOffset
        window.setFrame(NSRect(x: x, y: y, width: window.frame.size.width, height: window.frame.size.height), display: true, animate: false)
    }
}
