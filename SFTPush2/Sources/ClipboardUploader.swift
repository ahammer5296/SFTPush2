import Foundation
import AppKit
import UniformTypeIdentifiers

final class ClipboardUploader {
    private class BatchState {
        var successCount: Int = 0
        var errorCount: Int = 0
        var lastSuccessName: String?
        var lastSuccessURL: URL?
    }
    private struct UploadItem {
        let url: URL
        let shouldDeleteAfter: Bool
    }

    // Public: upload explicit file URLs (e.g., from Dock/status item drop)
    func uploadFiles(urls: [URL]) {
        // Accept any regular files; skip directories silently
        var items: [UploadItem] = urls.compactMap { url in
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                return UploadItem(url: url, shouldDeleteAfter: false)
            }
            return nil
        }
        guard !items.isEmpty else {
            notify(.init(title: "Загрузка не выполнена", body: "Нет файлов для загрузки.", url: nil))
            return
        }
        if items.count > 1, !confirmMultipleUploads(count: items.count) {
            return
        }
        activityHandler(true)
        let isBatch = items.count > 1
        let state = BatchState()
        process(items: items, index: 0, isBatch: isBatch, state: state)
    }

    private let preferences: Preferences
    private let uploadService: Uploading
    private let notificationHandler: (UploadNotificationMessage) -> Void
    private let activityHandler: (Bool) -> Void
    private let fileManager: FileManager

    init(preferences: Preferences = .shared,
         uploadService: Uploading,
         notificationHandler: @escaping (UploadNotificationMessage) -> Void,
         activityHandler: @escaping (Bool) -> Void,
         fileManager: FileManager = .default) {
        self.preferences = preferences
        self.uploadService = uploadService
        self.notificationHandler = notificationHandler
        self.activityHandler = activityHandler
        self.fileManager = fileManager
    }

    func uploadFromClipboard() {
        let pasteboard = NSPasteboard.general

        let hasAnyFileURLs = hasFileURLs(in: pasteboard)
        var items = collectFileItems(from: pasteboard)
        if items.isEmpty {
            // Если в буфере есть URL-адреса файлов/папок, но валидных файлов нет, не создаём временные изображения —
            // это может быть иконка папки. Показываем предупреждение и выходим.
            if hasAnyFileURLs {
                notify(.init(title: "Загрузка не выполнена", body: "Буфер содержит только папки или неподдерживаемые файлы.", url: nil))
                return
            }
            // Иначе пробуем извлечь напрямую картинку/видео из буфера (например, скриншот без файла)
            if let temp = createTemporaryItem(from: pasteboard) {
                items = [temp]
            }
        }

        guard !items.isEmpty else {
            notify(.init(title: "Загрузка не выполнена", body: "Буфер обмена не содержит подходящих файлов.", url: nil))
            return
        }

        if items.count > 1, !confirmMultipleUploads(count: items.count) {
            cleanup(items: items)
            return
        }

        activityHandler(true)
        let isBatch = items.count > 1
        let state = BatchState()
        process(items: items, index: 0, isBatch: isBatch, state: state)
    }

    private func process(items: [UploadItem], index: Int, isBatch: Bool, state: BatchState) {
        if index >= items.count {
            activityHandler(false)
            // Batch summary notification
            if isBatch {
                if state.successCount > 0, let name = state.lastSuccessName {
                    let url = state.lastSuccessURL
                    let title = "Загружено \(state.successCount) файлов"
                    let body = "Ошибки: \(state.errorCount)\nПоследний загруженный:\n\(name)"
                    notify(.init(title: title, body: body, url: url))
                } else {
                    let title = "Загрузка завершена"
                    let body = "Успешно: 0, Ошибки: \(state.errorCount)"
                    notify(.init(title: title, body: body, url: nil))
                }
            }
            return
        }

        let item = items[index]
        let remoteName = RemoteFileNamer.remoteName(for: item.url, renameEnabled: preferences.renameFileOnUpload)
        let displayName = remoteName ?? item.url.lastPathComponent

        do {
            if let actualMB = try exceededFileSizeInfo(item.url) {
                let limitText = formattedLimitDescription()
                if isBatch {
                    state.errorCount += 1
                } else {
                    notify(.init(title: "Загрузка не выполнена", body: "\(displayName): Размер файла \(actualMB) МБ превышает ограничение \(limitText).", url: nil))
                }
                cleanup(item: item)
                process(items: items, index: index + 1, isBatch: isBatch, state: state)
                return
            }
        } catch {
            if isBatch {
                state.errorCount += 1
            } else {
                notify(.init(title: "Загрузка не выполнена", body: "\(displayName): \(error.localizedDescription)", url: nil))
            }
            cleanup(item: item)
            process(items: items, index: index + 1, isBatch: isBatch, state: state)
            return
        }

        let source: UploadSource = item.shouldDeleteAfter ? .clipboardTemporary : .clipboardFile
        let request = UploadRequest(fileURL: item.url, source: source, remoteFileName: remoteName)

        uploadService.upload(request: request) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                let url = response.publicURL ?? self.makeFallbackURL(for: displayName)
                if isBatch {
                    state.successCount += 1
                    state.lastSuccessName = displayName
                    state.lastSuccessURL = url
                    // Add to history silently via special message
                    if let u = url {
                        self.notify(.init(title: "__HISTORY__", body: displayName, url: u))
                    }
                } else {
                    self.notify(.init(title: "Файл загружен", body: displayName, url: url))
                }
                if item.shouldDeleteAfter { self.saveToUploadedIfNeeded(originalTempURL: item.url) }
                if self.preferences.closeMonosnapAfterUpload && SystemIntegration.isFrontAppMonosnap() {
                    let delayMs = max(0, self.preferences.monosnapCloseDelayMs)
                    let delay: DispatchTimeInterval = .milliseconds(delayMs)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        SystemIntegration.sendCmdW()
                    }
                }
            case .failure(let error):
                if isBatch {
                    state.errorCount += 1
                } else {
                    self.notify(.init(title: "Загрузка не выполнена", body: "\(displayName): \(error.localizedDescription)", url: nil))
                }
            }
            self.cleanup(item: item)
            self.process(items: items, index: index + 1, isBatch: isBatch, state: state)
        }
    }

    private func collectFileItems(from pasteboard: NSPasteboard) -> [UploadItem] {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self],
                                                   options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return []
        }
        return objects.compactMap { url in
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return nil }
            guard isSupportedFile(url) else { return nil }
            return UploadItem(url: url, shouldDeleteAfter: false)
        }
    }

    private func hasFileURLs(in pasteboard: NSPasteboard) -> Bool {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return false
        }
        return !urls.isEmpty
    }

    private func createTemporaryItem(from pasteboard: NSPasteboard) -> UploadItem? {
        // Prefer to render NSImage from pasteboard and encode to preferred format
        if let image = NSImage(pasteboard: pasteboard) {
            if let item = writeTemporaryImage(image) { return item }
        }

        // Movie types (keep original data)
        let movieTypes: [(NSPasteboard.PasteboardType, String)] = [
            (NSPasteboard.PasteboardType("public.mpeg-4"), "mp4"),
            (NSPasteboard.PasteboardType("com.apple.quicktime-movie"), "mov"),
            (NSPasteboard.PasteboardType("public.movie"), "mov")
        ]
        for (type, ext) in movieTypes {
            if let data = pasteboard.data(forType: type) {
                return writeTemporaryFile(with: data, extension: ext)
            }
        }

        // Fallback: raw image data — try to construct NSImage and re-encode
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")
        ]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type), let img = NSImage(data: data) {
                if let item = writeTemporaryImage(img) { return item }
                // As a last resort, write raw data with declared ext
                let ext: String
                switch type {
                case .png: ext = "png"
                case .tiff: ext = "tiff"
                default:
                    ext = type.rawValue.contains("jpeg") ? "jpg" : (type.rawValue.contains("heic") ? "heic" : "img")
                }
                return writeTemporaryFile(with: data, extension: ext)
            }
        }

        return nil
    }

    private func writeTemporaryImage(_ image: NSImage) -> UploadItem? {
        // Encode according to preferences (png or jpg)
        guard let rep = image.representations.first as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else { return nil }
        let format = preferences.clipboardUploadFormat.lowercased()
        let data: Data?
        let ext: String
        if format == "jpg" || format == "jpeg" {
            let q = max(10, min(100, preferences.clipboardJpgQuality))
            let factor = NSNumber(value: Double(q) / 100.0)
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: factor])
            ext = "jpg"
        } else {
            data = rep.representation(using: .png, properties: [:])
            ext = "png"
        }
        guard let out = data else { return nil }
        return writeTemporaryFile(with: out, extension: ext)
    }

    private func writeTemporaryFile(with data: Data, extension ext: String) -> UploadItem? {
        let tempDir = fileManager.temporaryDirectory
        let filename = "Clipboard-\(UUID().uuidString).\(ext)"
        let url = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return UploadItem(url: url, shouldDeleteAfter: true)
        } catch {
            notify(.init(title: "Загрузка не выполнена", body: "Не удалось создать файл из буфера: \(error.localizedDescription)", url: nil))
            return nil
        }
    }

    private func confirmMultipleUploads(count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = "В буфере есть \(count) файлов для загрузки на сервер, загрузить их?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func isSupportedFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
    }

    private func exceededFileSizeInfo(_ url: URL) throws -> Int? {
        guard preferences.isMaxFileSizeLimitEnabled else { return nil }
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? NSNumber {
            let limit = Int64(preferences.maxFileSizeLimitMB) * 1024 * 1024
            if size.int64Value > limit {
                let mb = Int((Double(truncating: size) / 1024.0 / 1024.0).rounded())
                return mb
            }
        }
        return nil
    }

    private func cleanup(items: [UploadItem]) {
        items.forEach { cleanup(item: $0) }
    }

    private func cleanup(item: UploadItem) {
        guard item.shouldDeleteAfter else { return }
        try? fileManager.removeItem(at: item.url)
    }

    private func makeFallbackURL(for name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return URL(string: "https://example.com/uploads/\(encoded)")
    }

    private func formattedLimitDescription() -> String {
        "\(preferences.maxFileSizeLimitMB) МБ"
    }

    private func notify(_ message: UploadNotificationMessage) {
        DispatchQueue.main.async {
            self.notificationHandler(message)
        }
    }

    private func saveToUploadedIfNeeded(originalTempURL: URL) {
        guard preferences.clipboardSaveToUploaded else { return }
        // Determine base folder
        let fm = fileManager
        var base: URL
        let monitored = preferences.monitoredFolderPath
        if !monitored.isEmpty {
            let url = URL(fileURLWithPath: monitored, isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                base = url
            } else {
                base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("SFTPush", isDirectory: true)
            }
        } else {
            base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("SFTPush", isDirectory: true)
        }
        let uploaded = base.appendingPathComponent("Uploaded", isDirectory: true)
        do {
            if !fm.fileExists(atPath: uploaded.path) {
                try fm.createDirectory(at: uploaded, withIntermediateDirectories: true, attributes: nil)
            }
            let dest = uniqueDestinationURL(for: originalTempURL, inside: uploaded)
            try fm.copyItem(at: originalTempURL, to: dest)
        } catch {
            // Ignore errors for now
        }
    }

    private func uniqueDestinationURL(for originalURL: URL, inside directory: URL) -> URL {
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let ext = originalURL.pathExtension
        var candidate = directory.appendingPathComponent(originalURL.lastPathComponent)
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = "-\(counter)"
            let newName = ext.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
}
