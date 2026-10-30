import Foundation

/// Retained as a launch hook for source compatibility. This independent app
/// never reads or copies data from another app's preferences, files, or keychain.
enum ForkSetup {
    static func migrate() { }
}
