import Cocoa

final class StatusItemDragView: NSView {
    var onDrop: (([URL]) -> Void)?

    init(onDrop: (([URL]) -> Void)?) {
        self.onDrop = onDrop
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2).cgColor
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.backgroundColor = .none
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { layer?.backgroundColor = .none }
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else {
            return false
        }
        onDrop?(urls)
        return true
    }
}

