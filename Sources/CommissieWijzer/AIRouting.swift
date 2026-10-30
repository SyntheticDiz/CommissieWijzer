import Foundation

enum AppleAISettings {
    static func migrate(defaults: UserDefaults = .standard) {
        if defaults.string(forKey: "localAIProvider") != "chatgpt" { defaults.set("apple", forKey: "localAIProvider") }
        defaults.removeObject(forKey: "ollamaModel")
        defaults.removeObject(forKey: "automaticAIRoutingMigrated")
    }
}

enum AIRouting {
    /// Legacy identifiers remain local; explicitly selected ChatGPT never silently falls back.
    static func resolve(_ requested: String,
                        appleUnavailable: () -> String? = { AppleAIService.unavailability() }) async throws -> String {
        try Task.checkCancellation()
        if requested.hasPrefix("chatgpt:") {
            guard AIConfiguration.isChatGPT(requested) else { throw ChatGPTError.invalidRequest }
            do { _ = try await ChatGPTConnection.shared.accessToken() }
            catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                throw ChatGPTError.signInRequired
            }
            return requested
        }
        if let reason = appleUnavailable() { throw AppError(message: reason) }
        return AppleAIService.modelID
    }
}
