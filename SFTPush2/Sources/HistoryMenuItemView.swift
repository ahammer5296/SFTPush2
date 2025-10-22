import Cocoa

final class HistoryMenuItemView: NSView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private var hoverTimer: Timer?

    var onClick: ((NSEvent.ModifierFlags) -> Void)?
    var onHoverPreview: ((HistoryMenuItemView) -> Void)?
    var onHoverEnd: (() -> Void)?

    init(title: String, icon: NSImage?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleField.stringValue = title
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleField)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 22),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        updateTrackingAreas()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let ta = NSTrackingArea(rect: bounds,
                                 options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(ta)
    }

    override func mouseEntered(with event: NSEvent) {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onHoverPreview?(self)
        }
        if let t = hoverTimer { RunLoop.main.add(t, forMode: .common) }
        // Highlight background to indicate hover
        layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.12).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        hoverTimer?.invalidate()
        hoverTimer = nil
        onHoverEnd?()
        // Remove highlight
        layer?.backgroundColor = nil
    }

    @objc private func handleClick() {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        onClick?(flags)
    }

    func updateIcon(_ image: NSImage?) {
        iconView.image = image
    }

    func setTitle(_ title: String) { titleField.stringValue = title }
}
