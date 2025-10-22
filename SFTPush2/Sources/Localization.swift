import Foundation

@inline(__always)
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

