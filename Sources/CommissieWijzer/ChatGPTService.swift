import Foundation

/// Minimal text-only Responses transport for ChatGPT plan OAuth tokens.
enum ChatGPTService {
    static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    struct PreparedRequest {
        let model: String
        let effort: String
        let payload: [String: Any]
    }

    enum ChatGPTError: LocalizedError {
        case signInRequired
        case usageLimit
        case unclassified429(errorCode: String?, errorType: String?, retryAfter: TimeInterval?)
        case rateLimited(retryAfter: TimeInterval?)
        case temporarilyUnavailable(retryAfter: TimeInterval?)
        case planUsageLimit
        case quotaExceeded
        case http(Int)
        case invalidRequest
        case refused
        case incomplete
        case streamFailed
        case network

        var errorDescription: String? {
            switch self {
            case .signInRequired:
                return "Je ChatGPT-sessie is verlopen of heeft geen toegang. Meld je opnieuw aan via Instellingen."
            case .usageLimit:
                return "De ChatGPT-gebruiksgrens of snelheidslimiet is bereikt. Wacht even, controleer je plan en probeer opnieuw."
            case .unclassified429(_, _, let retryAfter):
                let delay = retryAfter.map { " De server gaf een wachttijd van ongeveer \(String(format: "%.0f", ceil($0))) seconden op." } ?? ""
                return "ChatGPT heeft de aanvraag begrensd. Het is nog niet duidelijk of dit tijdelijke druk of een gebruiksgrens is.\(delay) Probeer deze stap later opnieuw."
            case .rateLimited(let retryAfter):
                return retryMessage("ChatGPT verwerkt momenteel te veel aanvragen.", retryAfter: retryAfter)
            case .temporarilyUnavailable(let retryAfter):
                return retryMessage("ChatGPT is tijdelijk niet beschikbaar.", retryAfter: retryAfter)
            case .planUsageLimit:
                return "De gebruiksgrens voor deze ChatGPT-koppeling is bereikt. Controleer je gebruik in ChatGPT en probeer later opnieuw."
            case .quotaExceeded:
                return "De beschikbare ChatGPT-quota is op. Controleer de facturering en quota van het account."
            case .http(400):
                return "ChatGPT kon dit verzoek niet verwerken. Controleer de modelkeuze en probeer opnieuw."
            case .http(404):
                return "Dit ChatGPT-model is niet beschikbaar voor het aangemelde account. Kies een beschikbaar model."
            case .http(let status):
                return "ChatGPT gaf een netwerkfout (HTTP \(status)). Probeer het later opnieuw."
            case .invalidRequest:
                return "De ChatGPT-aanvraag heeft geen ondersteunde modelkeuze of JSON-uitvoerindeling."
            case .refused:
                return "ChatGPT heeft dit verzoek geweigerd. Pas de vraag aan en probeer opnieuw."
            case .incomplete:
                return "ChatGPT heeft het antwoord niet volledig afgerond. Probeer deze stap opnieuw."
            case .streamFailed:
                return "ChatGPT kon het antwoord niet afronden. Controleer je aanmelding en gebruikslimiet en probeer opnieuw."
            case .network:
                return "De verbinding met ChatGPT is mislukt. Controleer je internetverbinding en probeer opnieuw."
            }
        }

        private func retryMessage(_ message: String, retryAfter: TimeInterval?) -> String {
            guard let retryAfter else { return message + " Probeer het later opnieuw." }
            return message + " Probeer over ongeveer \(String(format: "%.0f", ceil(retryAfter))) seconden opnieuw."
        }
    }

    static func response(body: [String: Any]) async throws -> String {
        try Task.checkCancellation()
        let prepared = try prepare(body: body)
        let token: String
        do {
            token = try await ChatGPTConnection.shared.accessToken()
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw CancellationError() }
            throw ChatGPTError.signInRequired
        }
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatGPTError.signInRequired }

        var request = URLRequest(url: endpoint, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: prepared.payload, options: [.sortedKeys])
        } catch {
            throw ChatGPTError.invalidRequest
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        let redirectDelegate = RedirectRefuser()
        let session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw ChatGPTError.network }
            guard (200..<300).contains(http.statusCode) else {
                let body = try await boundedBody(from: bytes)
                let error = httpError(http.statusCode, headers: http.allHeaderFields, body: body)
                ChatGPTLimitDiagnostics.record(error, status: http.statusCode,
                                               errorCode: ChatGPTLimitDiagnostics.errorCode(in: body),
                                               errorType: ChatGPTLimitDiagnostics.errorType(in: body),
                                               responseShape: ChatGPTLimitDiagnostics.responseShape(in: body),
                                               detailSignal: http.statusCode == 429 ? ChatGPTLimitDiagnostics.detailSignal(in: body) : nil,
                                               requestID: ChatGPTLimitDiagnostics.requestID(in: http.allHeaderFields),
                                               retryAfterSeconds: retryAfterValue(headers: http.allHeaderFields, now: Date()))
                throw error
            }
            do {
                return try await collect(bytes: bytes)
            } catch let error as ChatGPTError {
                ChatGPTLimitDiagnostics.record(error, status: http.statusCode,
                                               requestID: ChatGPTLimitDiagnostics.requestID(in: http.allHeaderFields))
                throw error
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ChatGPTError {
            throw error
        } catch {
            try Task.checkCancellation()
            throw ChatGPTError.network
        }
    }

    static func prepare(body: [String: Any]) throws -> PreparedRequest {
        guard let encodedModel = body["model"] as? String,
              let selection = AIConfiguration.chatGPTSelection(encodedModel),
              let instructions = body["instructions"] as? String,
              let input = body["input"] as? String,
              let text = body["text"] as? [String: Any],
              let inputFormat = text["format"] as? [String: Any],
              let formatName = inputFormat["name"] as? String, !formatName.isEmpty else {
            throw ChatGPTError.invalidRequest
        }

        let format: [String: Any]
        if let type = inputFormat["type"] as? String,
           type == "json_schema",
           let schema = inputFormat["schema"] as? [String: Any] {
            format = ["type": "json_schema", "name": formatName, "strict": true, "schema": schema]
        } else {
            format = ["type": "json_schema", "name": formatName, "strict": true, "schema": try defaultSchema(named: formatName)]
        }

        // Construct an allowlisted payload: OAuth plan inference rejects many
        // ordinary Responses fields, including temperature and token limits.
        var payload: [String: Any] = [
            "model": selection.model,
            "instructions": instructions,
            "input": [["role": "user", "content": input]],
            "store": false,
            "stream": true,
            "text": ["format": format]
        ]
        if selection.effort != "auto" { payload["reasoning"] = ["effort": selection.effort] }
        guard JSONSerialization.isValidJSONObject(payload) else { throw ChatGPTError.invalidRequest }
        return PreparedRequest(model: selection.model, effort: selection.effort, payload: payload)
    }

    private static func defaultSchema(named name: String) throws -> [String: Any] {
        func string(_ description: String? = nil) -> [String: Any] {
            var value: [String: Any] = ["type": "string"]
            if let description { value["description"] = description }
            return value
        }
        func object(_ properties: [String: Any]) -> [String: Any] {
            ["type": "object", "additionalProperties": false, "required": properties.keys.sorted(), "properties": properties]
        }
        switch name {
        case "apple_question":
            return object(["question": string(), "sourceID": string()])
        case "apple_evidence", "apple_program_evidence":
            let point = object(["title": string(), "summary": string(), "documentID": string(), "programID": string(), "relevance": string()])
            return object(["points": ["type": "array", "items": point, "maxItems": 2]])
        case "passage_neutral":
            let point = object(["title": string(), "summary": string(), "documentID": string(), "sourceIDs": ["type": "array", "items": string(), "maxItems": 8],
                                "relevanceClass": string(), "relevanceReason": string(),
                                "contextIDs": ["type": "array", "items": string(), "maxItems": 2]])
            return object(["points": ["type": "array", "items": point, "maxItems": 3]])
        case "passage_program":
            let point = object(["title": string(), "summary": string(), "documentID": string(), "sourceIDs": ["type": "array", "items": string(), "maxItems": 8], "programID": string(),
                                "relevance": string(), "relevanceClass": string(), "relevanceReason": string(),
                                "contextIDs": ["type": "array", "items": string(), "maxItems": 2]])
            return object(["points": ["type": "array", "items": point, "maxItems": 3]])
        case "apple_review":
            return object(["summary": string(), "relevance": string(), "sourceIDs": ["type": "array", "items": string(), "maxItems": 16]])
        default:
            throw ChatGPTError.invalidRequest
        }
    }

    static let maximumErrorBodyBytes = 65_536
    // A final Responses SSE event may contain a full copy of the answer in
    // addition to the deltas. Keep enough room for that while bounding hostile
    // or accidentally enormous event streams and individual JSON frames.
    static let maximumStreamBytes = 64 * 1_024 * 1_024
    static let maximumEventLineBytes = 20 * 1_024 * 1_024

    private static func boundedBody<Bytes: AsyncSequence>(from bytes: Bytes) async throws -> Data where Bytes.Element == UInt8 {
        var body = Data()
        body.reserveCapacity(maximumErrorBodyBytes)
        for try await byte in bytes {
            try Task.checkCancellation()
            guard body.count < maximumErrorBodyBytes else { break }
            body.append(byte)
        }
        return body
    }

    static func httpError(_ status: Int, headers: [AnyHashable: Any] = [:], body: Data = Data(), now: Date = Date()) -> ChatGPTError {
        let retryAfter = retryAfterValue(headers: headers, now: now)
        switch status {
        case 401, 403: return .signInRequired
        case 429: return classifyError(body: body, fallback: .unclassified429(errorCode: nil, errorType: nil, retryAfter: retryAfter), retryAfter: retryAfter, partialOutput: false)
        case 503: return classifyError(body: body, fallback: .temporarilyUnavailable(retryAfter: retryAfter), retryAfter: retryAfter, partialOutput: false)
        default: return .http(status)
        }
    }

    static func retryAfterValue(headers: [AnyHashable: Any], now: Date) -> TimeInterval? {
        guard let field = headers.first(where: { String(describing: $0.key).caseInsensitiveCompare("Retry-After") == .orderedSame })?.value,
              let value = field as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let seconds: TimeInterval?
        if let number = TimeInterval(trimmed), number.isFinite, number >= 0 {
            seconds = number
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
            formatter.isLenient = false
            seconds = formatter.date(from: trimmed).map { max(0, $0.timeIntervalSince(now)) }
        }
        guard let seconds, seconds.isFinite else { return nil }
        return seconds
    }

    private static func classifyError(body: Data, fallback: ChatGPTError, retryAfter: TimeInterval?, partialOutput: Bool) -> ChatGPTError {
        guard body.count <= maximumErrorBodyBytes,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return fallback }
        let error = json["error"] as? [String: Any]
        let code = error?["code"] as? String ?? ""
        let type = error?["type"] as? String ?? ""
        let classified = error == nil
            ? fallback
            : classify(code: code, type: type, fallback: fallback, retryAfter: retryAfter, partialOutput: partialOutput)
        if case .unclassified429 = classified {
            let signal = ChatGPTLimitDiagnostics.detailSignal(in: body)
            // A legacy detail string must not overrule an unknown structured
            // error code or type that may require account action.
            if code.isEmpty, type.isEmpty,
               retryAfter?.isFinite == true, let retryAfter, retryAfter >= 0, signal?.isStrongRateLimit == true {
                return .rateLimited(retryAfter: retryAfter)
            }
            return .unclassified429(errorCode: ChatGPTLimitDiagnostics.sanitizedTechnicalField(code),
                                    errorType: ChatGPTLimitDiagnostics.sanitizedTechnicalField(type),
                                    retryAfter: retryAfter)
        }
        return classified
    }

    private static func classify(code: String, type: String, fallback: ChatGPTError, retryAfter: TimeInterval?, partialOutput: Bool) -> ChatGPTError {
        switch code {
        case "subscription_sharing_usage_limit_exceeded": return .planUsageLimit
        case "subscription_sharing_usage_unavailable", "subscription_sharing_user_unavailable",
             "service_unavailable", "server_is_overloaded":
            return partialOutput ? .streamFailed : .temporarilyUnavailable(retryAfter: retryAfter)
        case "rate_limit_exceeded", "rate_limit_error", "slow_down":
            return partialOutput ? .streamFailed : .rateLimited(retryAfter: retryAfter)
        case "insufficient_quota", "billing_hard_limit_reached", "quota_exceeded", "credit_balance_exhausted",
             "organization_spend_limit_exceeded", "project_spend_limit_exceeded": return .quotaExceeded
        default: break
        }
        switch type {
        case "rate_limit_exceeded", "rate_limit_error", "slow_down":
            return partialOutput ? .streamFailed : .rateLimited(retryAfter: retryAfter)
        case "subscription_sharing_usage_unavailable", "subscription_sharing_user_unavailable", "service_unavailable", "server_is_overloaded":
            return partialOutput ? .streamFailed : .temporarilyUnavailable(retryAfter: retryAfter)
        case "insufficient_quota", "billing_hard_limit_reached", "quota_exceeded", "credit_balance_exhausted",
             "organization_spend_limit_exceeded", "project_spend_limit_exceeded": return .quotaExceeded
        default: return fallback
        }
    }

    private struct EventStreamParser {
        private var dataLines: [String] = []
        private(set) var output = ""
        private(set) var completed = false

        mutating func append(_ line: String) throws {
            if line.isEmpty {
                try dispatchPending()
            } else if line.hasPrefix(":") {
                return
            } else if line.hasPrefix("data:") {
                var value = String(line.dropFirst(5))
                if value.first == " " { value.removeFirst() }
                dataLines.append(value)
            }
        }

        mutating func finish() throws {
            try dispatchPending()
            guard completed else { throw ChatGPTError.incomplete }
        }

        private mutating func dispatchPending() throws {
            guard !dataLines.isEmpty else { return }
            let data = dataLines.joined(separator: "\n")
            dataLines.removeAll(keepingCapacity: true)
            if data == "[DONE]" { return }
            guard let raw = data.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  let type = event["type"] as? String else {
                throw ChatGPTError.incomplete
            }
            if type.contains("refusal") { throw ChatGPTError.refused }
            switch type {
            case "response.output_text.delta":
                guard let delta = event["delta"] as? String else { throw ChatGPTError.incomplete }
                guard output.utf8.count + delta.utf8.count <= 16_777_216 else { throw ChatGPTError.incomplete }
                output += delta
            case "response.completed":
                guard let response = event["response"] as? [String: Any], response["status"] as? String == "completed" else {
                    throw ChatGPTError.incomplete
                }
                guard !containsRefusal(response) else { throw ChatGPTError.refused }
                completed = true
            case "response.incomplete":
                throw ChatGPTError.incomplete
            case "response.failed", "error":
                let streamError = ChatGPTService.nestedError(event)
                let mapped = ChatGPTService.classify(code: streamError?.code ?? "", type: streamError?.type ?? "",
                                                     fallback: .streamFailed, retryAfter: nil, partialOutput: !output.isEmpty)
                if let streamError, ["invalid_api_key", "token_expired", "unauthorized", "invalid_token"].contains(streamError.code) {
                    throw ChatGPTService.errorForCode(streamError.code)
                }
                throw mapped
            default:
                break
            }
        }

        private func containsRefusal(_ value: Any) -> Bool {
            if let dictionary = value as? [String: Any] {
                if (dictionary["type"] as? String)?.contains("refusal") == true { return true }
                return dictionary.values.contains(where: containsRefusal)
            }
            if let array = value as? [Any] { return array.contains(where: containsRefusal) }
            return false
        }
    }

    private struct StreamError {
        let code: String
        let type: String
    }

    private static func nestedError(_ event: [String: Any]) -> StreamError? {
        let response = event["response"] as? [String: Any]
        let error = (event["error"] as? [String: Any]) ?? (response?["error"] as? [String: Any])
        return error.map { StreamError(code: $0["code"] as? String ?? "", type: $0["type"] as? String ?? "") }
    }

    private static func errorForCode(_ code: String) -> ChatGPTError {
        switch code {
        case "invalid_api_key", "token_expired", "unauthorized", "invalid_token": return .signInRequired
        case "subscription_sharing_usage_limit_exceeded": return .planUsageLimit
        case "subscription_sharing_usage_unavailable", "subscription_sharing_user_unavailable", "service_unavailable", "server_is_overloaded":
            return .temporarilyUnavailable(retryAfter: nil)
        case "rate_limit_exceeded", "rate_limit_error", "slow_down": return .rateLimited(retryAfter: nil)
        case "insufficient_quota", "billing_hard_limit_reached", "quota_exceeded", "credit_balance_exhausted",
             "organization_spend_limit_exceeded", "project_spend_limit_exceeded": return .quotaExceeded
        default: return .streamFailed
        }
    }

    // AsyncBytes.lines drops empty lines. SSE uses those lines as frame
    // boundaries, so decode the bytes ourselves and retain every delimiter.
    static func collect<Bytes: AsyncSequence>(bytes: Bytes, maximumBytes: Int = maximumStreamBytes,
                                              maximumLineBytes: Int = maximumEventLineBytes) async throws -> String where Bytes.Element == UInt8 {
        var parser = EventStreamParser()
        var line = Data()
        var streamBytes = 0
        var previousWasCR = false
        func output() throws -> String {
            guard !parser.output.isEmpty else { throw ChatGPTError.incomplete }
            return parser.output
        }
        func appendLine() throws {
            guard let text = String(data: line, encoding: .utf8) else { throw ChatGPTError.incomplete }
            try parser.append(text)
            line.removeAll(keepingCapacity: true)
        }
        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                guard streamBytes < maximumBytes else { throw ChatGPTError.incomplete }
                streamBytes += 1
                if byte == 10 && previousWasCR { previousWasCR = false; continue }
                previousWasCR = byte == 13
                if byte == 10 || byte == 13 {
                    try appendLine()
                    // A terminal event is sufficient; do not wait for a
                    // keep-alive connection to close after completed inference.
                    if parser.completed { return try output() }
                } else {
                    guard line.count < maximumLineBytes else { throw ChatGPTError.incomplete }
                    line.append(byte)
                }
            }
            try Task.checkCancellation()
            if !line.isEmpty { try appendLine() }
            try parser.finish()
            return try output()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ChatGPTError {
            throw error
        } catch {
            try Task.checkCancellation()
            throw ChatGPTError.network
        }
    }

    static func parseEventStream(_ fixture: String) throws -> String {
        var parser = EventStreamParser()
        for line in fixture.components(separatedBy: .newlines) { try parser.append(line) }
        try parser.finish()
        guard !parser.output.isEmpty else { throw ChatGPTError.incomplete }
        return parser.output
    }

    private final class RedirectRefuser: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}

typealias ChatGPTError = ChatGPTService.ChatGPTError
