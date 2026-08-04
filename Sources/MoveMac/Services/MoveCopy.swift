import Foundation

enum MoveCopy {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "Move interface copy")
    }
}
