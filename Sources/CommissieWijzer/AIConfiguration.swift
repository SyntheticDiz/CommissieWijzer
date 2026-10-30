import Foundation

/// A model identifier captures provider and effort for the whole operation.
enum AIConfiguration {
    enum ChatGPTMode: String { case single, orchestrated }
    enum ChatGPTRole { case worker, orchestrator }

    static var selectedModel: String { selectedModel(defaults: .standard) }
    static func selectedModel(defaults: UserDefaults) -> String {
        guard defaults.string(forKey: "localAIProvider") == "chatgpt" else { return AppleAIService.modelID }
        ChatGPTPreferences.initializeDefaults(defaults: defaults)
        let mode = ChatGPTPreferences.mode(defaults: defaults)
        let main = defaults.string(forKey: ChatGPTPreferences.modelKey) ?? ChatGPTPreferences.defaultOrchestrator
        let effort = defaults.string(forKey: ChatGPTPreferences.effortKey) ?? ChatGPTPreferences.defaultEffort
        guard mode == .orchestrated else { return chatGPTModel(main, effort: effort) }
        return chatGPTJob(orchestrator: main, effort: effort,
                          worker: defaults.string(forKey: ChatGPTPreferences.workerModelKey).flatMap { $0.isEmpty ? nil : $0 } ?? ChatGPTPreferences.defaultWorker,
                          workerEffort: defaults.string(forKey: ChatGPTPreferences.workerEffortKey) ?? ChatGPTPreferences.defaultEffort)
    }
    static func chatGPTMode(defaults: UserDefaults) -> ChatGPTMode {
        ChatGPTPreferences.mode(defaults: defaults)
    }
    static func setChatGPTMode(_ mode: ChatGPTMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: ChatGPTPreferences.modeKey)
    }
    static func chatGPTModel(_ slug: String, effort: String) -> String { "chatgpt:\(slug):\(effort)" }
    static func chatGPTSelection(_ identifier: String) -> (model: String, effort: String)? {
        let parts = identifier.split(separator: ":", omittingEmptySubsequences: false)
        guard (parts.count == 3 || parts.count == 5), parts[0] == "chatgpt", !parts[1].isEmpty,
              parts[1].range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              ["auto", "none", "low", "medium", "high", "xhigh", "max"].contains(String(parts[2])) else { return nil }
        if parts.count == 5 {
            guard chatGPTSelection("chatgpt:" + parts[3] + ":" + parts[4]) != nil else { return nil }
        }
        return (String(parts[1]), String(parts[2]))
    }
    static func chatGPTJob(orchestrator: String, effort: String, worker: String, workerEffort: String) -> String {
        chatGPTModel(orchestrator, effort: effort) + ":" + worker + ":" + workerEffort
    }
    static func orchestratorModel(_ job: String) -> String {
        guard let selection = chatGPTSelection(job) else { return job }
        return chatGPTModel(selection.model, effort: selection.effort)
    }
    static func workerModel(_ job: String) -> String {
        guard isChatGPT(job) else { return job }
        let parts = job.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count == 5 ? chatGPTModel(String(parts[3]), effort: String(parts[4])) : job
    }
    static func isChatGPT(_ model: String) -> Bool { chatGPTSelection(model) != nil }
    static func label(_ model: String) -> String {
        guard let selection = chatGPTSelection(model) else { return "Apple Intelligence · Lokaal" }
        if model.split(separator: ":").count == 5 {
            let worker = chatGPTSelection(workerModel(model))!
            return "ChatGPT · Orchestrator: \(selection.model) (\(selection.effort)) · Subagents: \(worker.model) (\(worker.effort)) · Online"
        }
        return "ChatGPT · \(selection.model) · \(selection.effort) · Online"
    }
    static func phaseModelLabel(_ model: String, role: ChatGPTRole? = nil) -> String {
        guard isChatGPT(model) else { return "" }
        let routed: String
        if let role { routed = role == .orchestrator ? orchestratorModel(model) : workerModel(model) }
        else { routed = model }
        guard let selection = chatGPTSelection(routed) else { return "" }
        return " · ChatGPT \(selection.model) (\(selection.effort))"
    }
    @MainActor static func unavailability() -> String? {
        if isChatGPT(selectedModel) { return ChatGPTAccount.shared.isSignedIn ? nil : "Log in met ChatGPT via Instellingen om AI-analyse te starten." }
        return AppleAIService.unavailability()
    }
}
