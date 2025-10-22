import Foundation

struct RemoteFileNamer {
    static func remoteName(for url: URL, renameEnabled: Bool, length: Int = 15) -> String? {
        guard renameEnabled else { return nil }
        let base = randomString(length: length)
        let ext = url.pathExtension
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var generator = SystemRandomNumberGenerator()
        var result = String()
        result.reserveCapacity(length)
        for _ in 0..<length {
            if let random = characters.randomElement(using: &generator) {
                result.append(random)
            }
        }
        return result
    }
}
