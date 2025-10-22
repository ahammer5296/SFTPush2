import Foundation

// MARK: - Build-time flag for visibility in logs
#if canImport(mft)
private let MFT_AVAILABLE = true
#else
private let MFT_AVAILABLE = false
#endif

enum UploadSource {
    case folder(URL)
    case clipboardFile
    case clipboardTemporary
}

struct UploadRequest {
    let fileURL: URL
    let source: UploadSource
    let remoteFileName: String?
}

struct UploadResponse {
    let remotePath: String?
    let publicURL: URL?
}

enum UploadError: Error {
    case notConfigured(String)
    case keyAuthNotSupported
    case fileOpenFailed(String)
    case connectFailed(String)
    case authFailed(String)
    case writeFailed(String)

    var localizedDescription: String {
        switch self {
        case .notConfigured(let what):
            return "SFTP не настроен: \(what)"
        case .keyAuthNotSupported:
            return "Авторизация по ключу пока не поддерживается"
        case .fileOpenFailed(let msg):
            return "Файл недоступен: \(msg)"
        case .connectFailed(let msg):
            return "Не удалось подключиться: \(msg)"
        case .authFailed(let msg):
            return "Ошибка аутентификации: \(msg)"
        case .writeFailed(let msg):
            return "Ошибка загрузки: \(msg)"
        }
    }
}

protocol Uploading {
    func upload(request: UploadRequest, completion: @escaping (Result<UploadResponse, UploadError>) -> Void)
}

// MARK: - Real SFTP implementation (mft)

#if canImport(mft)
import mft

final class SFTPUploadService: Uploading {
    private let preferences: Preferences
    private let queue = DispatchQueue(label: "UploadService.SFTP")

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        print("[UploadService] Using REAL mft SFTP implementation (mft.framework linked)")
    }

    func upload(request: UploadRequest, completion: @escaping (Result<UploadResponse, UploadError>) -> Void) {
        // Validate configuration
        let host = preferences.sftpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = preferences.sftpUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = preferences.sftpPort
        let useKey = preferences.sftpUseKeyAuth
        let password = preferences.sftpPassword

        guard !host.isEmpty else { completion(.failure(.notConfigured("Host"))); return }
        guard !user.isEmpty else { completion(.failure(.notConfigured("Username"))); return }
        if useKey { completion(.failure(.keyAuthNotSupported)); return }
        guard !password.isEmpty else { completion(.failure(.notConfigured("Password"))); return }

        let remoteName = request.remoteFileName ?? request.fileURL.lastPathComponent
        let remotePath = Self.joinRemote(parent: preferences.sftpRemotePath, name: remoteName)

        print("[UploadService][mft] Start upload → host=\(host), port=\(port), user=\(user), file=\(request.fileURL.lastPathComponent), remotePath=\(remotePath)")
        queue.async {
            let sftp = MFTSftpConnection(hostname: host, port: port, username: user, password: password)
            do {
                do { try sftp.connect() } catch { throw UploadError.connectFailed(error.localizedDescription) }
                do { try sftp.authenticate() } catch { throw UploadError.authFailed(error.localizedDescription) }

                guard let inStream = InputStream(fileAtPath: request.fileURL.path) else {
                    throw UploadError.fileOpenFailed("\(request.fileURL.lastPathComponent)")
                }

                do {
                    try sftp.write(stream: inStream, toFileAtPath: remotePath, append: false) { _ in
                        return true
                    }
                } catch {
                    throw UploadError.writeFailed(error.localizedDescription)
                }

                let publicURL = Self.makePublicURL(base: self.preferences.sftpBaseURL, name: remoteName)
                print("[UploadService][mft] Upload OK → remote=\(remotePath), publicURL=\(publicURL?.absoluteString ?? "nil")")
                completion(.success(UploadResponse(remotePath: remotePath, publicURL: publicURL)))
            } catch let err as UploadError {
                print("[UploadService][mft] Upload FAILED (domain) → \(err.localizedDescription)")
                completion(.failure(err))
            } catch {
                print("[UploadService][mft] Upload FAILED (unknown) → \(error.localizedDescription)")
                completion(.failure(.writeFailed(error.localizedDescription)))
            }
            sftp.disconnect()
        }
    }

    private static func joinRemote(parent: String, name: String) -> String {
        var base = parent.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "/" }
        if !base.hasPrefix("/") { base = "/" + base }
        if base.hasSuffix("/") { base.removeLast() }
        return base == "/" ? "/\(name)" : "\(base)/\(name)"
    }

    private static func makePublicURL(base: String, name: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url.appendingPathComponent(name)
    }
}

#else

// Fallback to a stub if mft is not available in this build configuration
final class SFTPUploadService: Uploading {
    init(preferences: Preferences = .shared) {
        print("[UploadService] Using FALLBACK SFTP stub (mft.framework unavailable)")
    }
    func upload(request: UploadRequest, completion: @escaping (Result<UploadResponse, UploadError>) -> Void) {
        print("[UploadService][fallback] Simulate upload of \(request.fileURL.lastPathComponent)")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            let remoteName = request.remoteFileName ?? request.fileURL.lastPathComponent
            let url = URL(string: "https://example.com/uploads/\(remoteName)")
            let remote = UploadResponse(remotePath: "/stub/\(remoteName)", publicURL: url)
            print("[UploadService][fallback] Upload OK → remote=\(remote.remotePath ?? "nil"), publicURL=\(remote.publicURL?.absoluteString ?? "nil")")
            completion(.success(remote))
        }
    }
}

#endif

// MARK: - Factory
enum UploadServiceFactory {
    static func make(preferences: Preferences = .shared) -> Uploading {
        print("[UploadServiceFactory] Initializing service → mftAvailable=\(MFT_AVAILABLE)")
        return SFTPUploadService(preferences: preferences)
    }
}
