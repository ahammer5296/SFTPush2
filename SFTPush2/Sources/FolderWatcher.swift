import Foundation
import Darwin

final class FolderWatcher {
    enum WatcherError: Error {
        case folderMissing
        case failedToOpenDescriptor
    }

    enum FailureReason {
        case sizeLimitExceeded(limitMB: Int, actualMB: Int)
        case upload(UploadError)
        case fileMissing
        case moveFailed(Error)
        case metadata(Error)

        var message: String {
            switch self {
            case .sizeLimitExceeded(let limit, let actual):
                return "Размер файла \(actual) МБ превышает ограничение \(limit) МБ."
            case .upload(let err):
                return err.localizedDescription
            case .fileMissing:
                return "Файл недоступен для загрузки."
            case .moveFailed(let err):
                return "Не удалось переместить файл: \(err.localizedDescription)"
            case .metadata(let err):
                return "Не удалось прочитать параметры файла: \(err.localizedDescription)"
            }
        }
    }

    private let preferences: Preferences
    private let uploadService: Uploading
    private let notificationHandler: (UploadNotificationMessage) -> Void
    private let activityHandler: (Bool) -> Void
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "FolderWatcher.queue")

    private var monitoredFolderURL: URL?
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1

    private var pendingFiles = Set<String>()
    private var activeUploads = Set<String>()
    private var remoteNames: [String: String] = [:]

    private var uploadedFolderName = "Uploaded"
    private var errorFolderName = "Error"

    init(preferences: Preferences = .shared,
         uploadService: Uploading,
         fileManager: FileManager = .default,
         notificationHandler: @escaping (UploadNotificationMessage) -> Void,
         activityHandler: @escaping (Bool) -> Void) {
        self.preferences = preferences
        self.uploadService = uploadService
        self.fileManager = fileManager
        self.notificationHandler = notificationHandler
        self.activityHandler = activityHandler
    }

    var isRunning: Bool {
        source != nil
    }

    func start() throws {
        guard !isRunning else { return }
        guard let folderPath = preferences.monitoredFolderPath.nonEmpty else {
            throw WatcherError.folderMissing
        }

        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw WatcherError.folderMissing
        }

        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else {
            throw WatcherError.failedToOpenDescriptor
        }

        descriptor = fd
        monitoredFolderURL = folderURL
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                               eventMask: [.write, .rename, .extend],
                                                               queue: queue)
        source.setEventHandler { [weak self] in
            self?.scanDirectory()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.descriptor >= 0 {
                close(self.descriptor)
                self.descriptor = -1
            }
        }
        self.source = source
        source.resume()
        queue.async { [weak self] in
            self?.scanDirectory(initial: true)
        }
    }

    func stop() {
        queue.sync {
            pendingFiles.removeAll()
            activeUploads.removeAll()
            remoteNames.removeAll()
            source?.cancel()
            source = nil
            monitoredFolderURL = nil
        }
        activityHandler(false)
    }

    // MARK: - Directory scan
    private func scanDirectory(initial: Bool = false) {
        guard let folderURL = monitoredFolderURL else { return }
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for url in contents {
                scheduleProcessing(for: url, initial: initial)
            }
        } catch {
            postFailureNotification(title: "Ошибка папки", body: "Не удалось просканировать \(folderURL.path): \(error.localizedDescription)")
        }
    }

    private func scheduleProcessing(for fileURL: URL, initial: Bool) {
        guard fileURL.isFileURL else { return }
        let path = fileURL.path
        if pendingFiles.contains(path) || activeUploads.contains(path) {
            return
        }

        pendingFiles.insert(path)
        let delay: TimeInterval = initial ? 0.5 : 0.3
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.processFile(at: fileURL)
        }
    }

    private func processFile(at url: URL) {
        let path = url.path
        pendingFiles.remove(path)

        guard fileManager.fileExists(atPath: path) else {
            handleFailure(for: url, reason: .fileMissing)
            return
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values.isDirectory == true {
                return
            }

            if let actualMB = try exceededFileSizeInfo(for: url) {
                handleFailure(for: url, reason: .sizeLimitExceeded(limitMB: preferences.maxFileSizeLimitMB, actualMB: actualMB))
                return
            }

            startUpload(for: url)
        } catch {
            handleFailure(for: url, reason: .metadata(error))
        }
    }

    private func exceededFileSizeInfo(for url: URL) throws -> Int? {
        guard preferences.isMaxFileSizeLimitEnabled else { return nil }
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        guard let sizeNumber = attrs[.size] as? NSNumber else { return nil }
        let limitBytes = Int64(preferences.maxFileSizeLimitMB) * 1024 * 1024
        if sizeNumber.int64Value > limitBytes {
            let mb = Int((Double(truncating: sizeNumber) / 1024.0 / 1024.0).rounded())
            return mb
        }
        return nil
    }

    private func startUpload(for url: URL) {
        guard let folder = monitoredFolderURL else {
            handleFailure(for: url, reason: .fileMissing)
            return
        }

        let remoteName = remoteFileName(for: url)
        let path = url.path
        activeUploads.insert(path)
        if let remoteName {
            remoteNames[path] = remoteName
        } else {
            remoteNames.removeValue(forKey: path)
        }
        updateActivityIndicator()

        let request = UploadRequest(fileURL: url, source: .folder(folder), remoteFileName: remoteName)

        uploadService.upload(request: request) { [weak self] result in
            guard let self else { return }
            self.queue.async {
                self.activeUploads.remove(path)
                let appliedName = self.remoteNames[path] ?? url.lastPathComponent
                self.remoteNames.removeValue(forKey: path)
                self.updateActivityIndicator()
                switch result {
                case .success(let response):
                    self.handleSuccess(for: url, remoteName: appliedName, response: response)
                case .failure(let error):
                    self.handleFailure(for: url, reason: .upload(error), remoteName: appliedName)
                }
            }
        }
    }

    private func remoteFileName(for url: URL) -> String? {
        RemoteFileNamer.remoteName(for: url, renameEnabled: preferences.renameFileOnUpload)
    }

    private func handleSuccess(for fileURL: URL, remoteName: String, response: UploadResponse) {
        do {
            try move(fileURL: fileURL, toSubfolderNamed: uploadedFolderName)
            let url = response.publicURL ?? makeFallbackURL(for: remoteName)
            postSuccessNotification(fileName: remoteName, remoteURL: url)
        } catch {
            handleFailure(for: fileURL, reason: .moveFailed(error), remoteName: remoteName)
        }
    }

    private func handleFailure(for fileURL: URL, reason: FailureReason, remoteName: String? = nil) {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try move(fileURL: fileURL, toSubfolderNamed: errorFolderName)
            }
        } catch {
            // If secondary move fails we fall back to notification only.
        }
        let displayName = remoteName ?? fileURL.lastPathComponent
        postFailureNotification(title: "Загрузка не выполнена", body: "\(displayName): \(reason.message)")
    }

    private func move(fileURL: URL, toSubfolderNamed folderName: String) throws {
        guard let baseFolder = monitoredFolderURL else { return }
        let destinationFolder = baseFolder.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: destinationFolder.path) {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true, attributes: nil)
        }

        let destinationURL = uniqueDestinationURL(for: fileURL, inside: destinationFolder)
        try fileManager.moveItem(at: fileURL, to: destinationURL)
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

    private func postSuccessNotification(fileName: String, remoteURL: URL?) {
        let message = UploadNotificationMessage(title: "Файл загружен", body: fileName, url: remoteURL)
        postNotification(message)
    }

    private func postFailureNotification(title: String, body: String) {
        let message = UploadNotificationMessage(title: title, body: body, url: nil)
        postNotification(message)
    }

    private func postNotification(_ message: UploadNotificationMessage) {
        DispatchQueue.main.async {
            self.notificationHandler(message)
        }
    }

    private func updateActivityIndicator() {
        let hasActivity = !activeUploads.isEmpty
        DispatchQueue.main.async {
            self.activityHandler(hasActivity)
        }
    }

    private func makeFallbackURL(for remoteName: String) -> URL? {
        let encoded = remoteName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? remoteName
        return URL(string: "https://example.com/uploads/\(encoded)")
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
