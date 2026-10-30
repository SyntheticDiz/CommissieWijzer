import AppKit
import Combine
import CryptoKit
import Foundation
import Network
import Security

struct ChatGPTModel: Identifiable, Sendable {
    let id: String
    let displayName: String
    let reasoningEfforts: [String]
}

struct ChatGPTAccountProfile: Sendable {
    let email: String
    let subject: String
}

enum ChatGPTOAuth {
    static let issuer = "https://auth.openai.com"
    static let resource = "https://api.openai.com/v1"
    static let requiredScopes: Set<String> = ["openid", "profile", "email", "offline_access", "resource.invoke", "chatgpt.tokens.use.direct"]

    struct Callback: Sendable {
        let code: String?
        let state: String
        let clientID: String?
        let error: String?
    }

    struct Identity: Sendable {
        let subject: String
        let email: String
    }

    static func randomURLSafeValue(byteCount: Int = 32) throws -> String {
        guard byteCount >= 16, byteCount <= 128 else { throw AccountError.invalidRequest }
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else { throw AccountError.randomnessUnavailable }
        return base64URL(Data(bytes))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decodeBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: base64)
    }

    static func pkceChallenge(verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func authorizationURL(clientID: String, callbackURI: String, state: String, nonce: String,
                                 challenge: String, hostID: String, reauthorization: Bool,
                                 idTokenHint: String? = nil, loginHint: String? = nil) throws -> URL {
        guard var components = URLComponents(string: issuer + "/api/accounts/authorize"),
              let callback = URL(string: callbackURI), callback.scheme == "http", callback.host == "127.0.0.1",
              callback.path == "/auth/callback", callback.port != nil else { throw AccountError.invalidRequest }
        var items = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: callbackURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "ext_agent_host_id", value: hostID)
        ]
        if !reauthorization { items.append(URLQueryItem(name: "agent_name_hint", value: "CommissieWijzer")) }
        if reauthorization, let idTokenHint, !idTokenHint.isEmpty { items.append(URLQueryItem(name: "id_token_hint", value: idTokenHint)) }
        if reauthorization, let loginHint, !loginHint.isEmpty { items.append(URLQueryItem(name: "login_hint", value: loginHint)) }
        components.queryItems = items
        guard let url = components.url else { throw AccountError.invalidRequest }
        return url
    }

    /// Accepts only a small HTTP/1.1 GET for the exact loopback callback route.
    static func parseCallbackRequest(_ data: Data, expectedHost: String) -> Callback? {
        guard data.count <= 16_384, let request = String(data: data, encoding: .utf8),
              let headerEnd = request.range(of: "\r\n\r\n") else { return nil }
        let header = String(request[..<headerEnd.lowerBound])
        let lines = header.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let requestParts = first.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count == 3, requestParts[0] == "GET", requestParts[2].hasPrefix("HTTP/1."),
              requestParts[2] == "HTTP/1.0" || requestParts[2] == "HTTP/1.1" else { return nil }
        guard let hostLine = lines.dropFirst().first(where: { $0.lowercased().hasPrefix("host:") }),
              String(hostLine.dropFirst(5)).trimmingCharacters(in: .whitespaces) == expectedHost else { return nil }
        let target = String(requestParts[1])
        guard target.hasPrefix("/auth/callback?"), !target.contains("#"),
              let components = URLComponents(string: "http://127.0.0.1" + target),
              components.path == "/auth/callback", let queryItems = components.queryItems,
              !queryItems.isEmpty else { return nil }
        var values: [String: String] = [:]
        for item in queryItems {
            guard values[item.name] == nil, let value = item.value, value.utf8.count <= 4096 else { return nil }
            values[item.name] = value
        }
        guard let state = values["state"], !state.isEmpty else { return nil }
        let code = values["code"]
        let error = values["error"]
        guard (code != nil) != (error != nil), code?.isEmpty != true else { return nil }
        return Callback(code: code, state: state, clientID: values["client_id"], error: error)
    }

    static func callbackMatches(_ callback: Callback, expectedState: String, expectedClientID: String?, isNewRegistration: Bool) -> Bool {
        guard callback.state == expectedState, callback.error == nil else { return false }
        if isNewRegistration { return callback.code != nil && callback.clientID.map { $0 != "dynamic_agent_client" && !$0.isEmpty } == true }
        guard let expectedClientID else { return false }
        return callback.clientID == nil || callback.clientID == expectedClientID
    }

    static func parseModels(_ data: Data) throws -> [ChatGPTModel] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["models"] as? [[String: Any]] else { throw AccountError.invalidResponse }
        let allowed: Set<String> = ["none", "low", "medium", "high", "xhigh", "max"]
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard entry["visibility"] as? String == "list",
                  let slug = entry["slug"] as? String, !slug.isEmpty,
                  slug.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
                  seen.insert(slug).inserted,
                  let name = entry["display_name"] as? String, !name.isEmpty else { return nil }
            let values = entry["supported_reasoning_levels"] as? [Any] ?? []
            let supplied = values.compactMap { value -> String? in
                if let value = value as? String { return value }
                if let value = value as? [String: Any] { return value["effort"] as? String ?? value["name"] as? String }
                return nil
            }.filter { allowed.contains($0) }
            var seenEfforts = Set<String>()
            let effortLevels = (entry["supported_reasoning_levels"] == nil ? fallbackEfforts(for: slug) : supplied).filter { seenEfforts.insert($0).inserted }
            return ChatGPTModel(id: slug, displayName: name, reasoningEfforts: effortLevels)
        }
    }

    static func catalogNotice(_ data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let entries = root["models"] as? [[String: Any]] else { return "Modellenlijst niet leesbaar." }
        guard let sol = entries.first(where: { $0["slug"] as? String == "gpt-6.1-sol" }) else {
            return "OpenAI heeft GPT-6.1 Sol niet opgenomen in de opgehaalde modellenlijst van dit account."
        }
        guard sol["visibility"] as? String == "list" else {
            return "OpenAI heeft GPT-6.1 Sol teruggegeven, maar niet als zichtbare modelkeuze voor dit account."
        }
        if (sol["display_name"] as? String ?? "").isEmpty {
            return "GPT-6.1 Sol staat in de serverlijst, maar mist de benodigde weergavenaam."
        }
        return "De modelkeuzes volgen de actuele lijst van OpenAI voor dit account."
    }

    static func fallbackEfforts(for modelID: String) -> [String] {
        let id = modelID.lowercased()
        if id.contains("luna") { return ["none", "low", "medium", "high", "xhigh", "max"] }
        if id.contains("sol") { return ["low", "medium", "high", "xhigh", "max"] }
        return []
    }

    /// Verifies a compact RS256 JWT against a JWKS document before trusting its claims.
    static func verifyIDToken(_ token: String, jwksData: Data, audience: String, nonce: String?,
                              expectedSubject: String? = nil, now: Date = Date()) throws -> Identity {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let headerData = decodeBase64URL(String(parts[0])),
              let claimsData = decodeBase64URL(String(parts[1])),
              let signature = decodeBase64URL(String(parts[2])),
              let header = try JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              header["alg"] as? String == "RS256", let keyID = header["kid"] as? String,
              let claims = try JSONSerialization.jsonObject(with: claimsData) as? [String: Any],
              let jwks = try JSONSerialization.jsonObject(with: jwksData) as? [String: Any],
              let keys = jwks["keys"] as? [[String: Any]],
              let jwk = keys.first(where: { $0["kid"] as? String == keyID && $0["kty"] as? String == "RSA" }),
              let modulus = jwk["n"] as? String, let exponent = jwk["e"] as? String,
              let n = decodeBase64URL(modulus), let e = decodeBase64URL(exponent),
              let publicKeyData = rsaPublicKeyDER(modulus: n, exponent: e) else { throw AccountError.invalidIdentityToken }
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: n.count * 8
        ]
        var keyError: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData, attributes as CFDictionary, &keyError) else {
            throw AccountError.invalidIdentityToken
        }
        let signedBytes = Data((String(parts[0]) + "." + String(parts[1])).utf8)
        guard SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256,
                                    signedBytes as CFData, signature as CFData, &keyError) else {
            throw AccountError.invalidIdentityToken
        }
        let audiences = (claims["aud"] as? String).map { [$0] } ?? (claims["aud"] as? [String] ?? [])
        guard claims["iss"] as? String == issuer, audiences.contains(audience),
              let expiration = claims["exp"] as? TimeInterval, expiration > now.timeIntervalSince1970,
              (nonce == nil || claims["nonce"] as? String == nonce),
              let subject = claims["sub"] as? String, !subject.isEmpty,
              expectedSubject == nil || expectedSubject == subject,
              let email = claims["email"] as? String, !email.isEmpty else { throw AccountError.invalidIdentityToken }
        return Identity(subject: subject, email: email)
    }

    private static func rsaPublicKeyDER(modulus: Data, exponent: Data) -> Data? {
        func integer(_ bytes: Data) -> Data? {
            var value = Array(bytes.drop(while: { $0 == 0 }))
            guard !value.isEmpty else { return nil }
            if value[0] & 0x80 != 0 { value.insert(0, at: 0) }
            return derElement(tag: 0x02, body: Data(value))
        }
        guard let n = integer(modulus), let e = integer(exponent) else { return nil }
        return derElement(tag: 0x30, body: n + e)
    }

    private static func derElement(tag: UInt8, body: Data) -> Data {
        var result = Data([tag])
        let count = body.count
        if count < 128 { result.append(UInt8(count)) }
        else {
            var length = count.bigEndian
            let bytes = withUnsafeBytes(of: &length) { Array($0.drop(while: { $0 == 0 })) }
            result.append(0x80 | UInt8(bytes.count)); result.append(contentsOf: bytes)
        }
        result.append(body)
        return result
    }
}

@MainActor
final class ChatGPTAccount: ObservableObject {
    static let shared = ChatGPTAccount()

    @Published private(set) var isSignedIn = false
    @Published private(set) var busy = false
    @Published private(set) var email = ""
    @Published private(set) var status = "Niet aangemeld"
    @Published private(set) var error: String?
    @Published private(set) var models: [ChatGPTModel] = []
    @Published private(set) var catalogNotice = ""

    private var signInTask: Task<ChatGPTAccountProfile, Error>?

    private init() {
        Task { await loadSavedAccount() }
    }

    func signIn() async {
        guard !busy else { return }
        busy = true; error = nil; status = "Verbinden met ChatGPT…"
        let task = Task { try await ChatGPTConnection.shared.signIn() }
        signInTask = task
        do {
            let profile = try await task.value
            isSignedIn = true; email = profile.email; status = "Aangemeld bij ChatGPT"
            signInTask = nil
            await refreshModels()
        } catch is CancellationError {
            status = "Aanmelden geannuleerd"
        } catch {
            self.error = error.localizedDescription
            status = "Aanmelden mislukt"
        }
        signInTask = nil; busy = false
    }

    func cancelSignIn() {
        signInTask?.cancel()
        Task { await ChatGPTConnection.shared.cancelSignIn() }
    }

    func signOut() async {
        busy = true; error = nil
        let revoked = await ChatGPTConnection.shared.signOut()
        isSignedIn = false; email = ""; models = []; catalogNotice = ""; busy = false
        status = revoked ? "Afgemeld bij ChatGPT" : "Lokaal afgemeld; intrekken bij ChatGPT is niet bevestigd"
    }

    func refreshModels() async {
        guard isSignedIn else { models = []; return }
        do {
            let catalog = try await ChatGPTConnection.shared.refreshModelCatalog()
            models = catalog.models
            catalogNotice = catalog.notice
            status = "Modellen bijgewerkt"
            error = nil
        } catch {
            self.error = error.localizedDescription
            status = "Modellen konden niet worden opgehaald"
        }
    }

    private func loadSavedAccount() async {
        guard let profile = await ChatGPTConnection.shared.savedProfile() else { return }
        isSignedIn = true; email = profile.email; status = "Aangemeld bij ChatGPT"
    }
}

actor ChatGPTConnection {
    static let shared = ChatGPTConnection()

    fileprivate struct Credential: Codable, Sendable {
        var clientID: String
        var callbackURI: String
        var hostID: String
        var subject: String
        var email: String
        var idToken: String?
        var accessToken: String?
        var refreshToken: String?
        var expiresAt: Date?
        var scopes: [String]
    }
    private struct Discovery: Decodable, Sendable {
        let issuer: String
        let authorization_endpoint: URL
        let token_endpoint: URL
        let jwks_uri: URL
        let revocation_endpoint: URL?
    }
    private struct TokenResponse: Decodable, Sendable {
        let access_token: String
        let refresh_token: String?
        let id_token: String?
        let token_type: String
        let expires_in: TimeInterval
        let scope: String
    }
    private struct AuthorizationAttempt: Sendable {
        let clientID: String
        let isNewRegistration: Bool
        let callbackURI: String
        let state: String
        let nonce: String
        let verifier: String
    }

    private let session: URLSession
    private var credential: Credential?
    private var didLoadCredential = false
    private var callbackServer: LoopbackCallbackServer?
    private var refreshTask: Task<String, Error>?
    private var loggingOut = false
    private var generation: UInt64 = 0

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration, delegate: RedirectRefuser(), delegateQueue: nil)
    }

    func savedProfile() -> ChatGPTAccountProfile? {
        let record = loadCredential()
        guard hasPlanScopes(record.scopes), record.accessToken != nil, record.refreshToken != nil else { return nil }
        return ChatGPTAccountProfile(email: record.email, subject: record.subject)
    }

    func signIn() async throws -> ChatGPTAccountProfile {
        try Task.checkCancellation()
        guard !loggingOut else { throw AccountError.notSignedIn }
        let previous = loadCredentialIfPresent()
        let isNew = previous == nil || previous?.clientID.isEmpty == true
        let operationGeneration = generation
        let hostID = stableHostID()
        let server = try LoopbackCallbackServer()
        callbackServer = server
        defer { server.cancel(); callbackServer = nil }
        let callbackURI = try await server.start()
        let attempt = AuthorizationAttempt(
            clientID: isNew ? "dynamic_agent_client" : previous!.clientID,
            isNewRegistration: isNew,
            callbackURI: callbackURI,
            state: try ChatGPTOAuth.randomURLSafeValue(),
            nonce: try ChatGPTOAuth.randomURLSafeValue(),
            verifier: try ChatGPTOAuth.randomURLSafeValue(byteCount: 48)
        )
        let authorizeURL = try ChatGPTOAuth.authorizationURL(
            clientID: attempt.clientID, callbackURI: attempt.callbackURI, state: attempt.state, nonce: attempt.nonce,
            challenge: ChatGPTOAuth.pkceChallenge(verifier: attempt.verifier), hostID: hostID,
            reauthorization: !isNew, idTokenHint: previous?.idToken, loginHint: previous?.email
        )
        let callbackTask = Task { try await server.waitForCallback() }
        let opened = await MainActor.run { NSWorkspace.shared.open(authorizeURL) }
        guard opened else { callbackTask.cancel(); throw AccountError.browserUnavailable }
        let callback: ChatGPTOAuth.Callback
        do {
            callback = try await withTaskCancellationHandler {
                try await callbackTask.value
            } onCancel: {
                callbackTask.cancel()
                server.cancel()
            }
        } catch {
            callbackTask.cancel()
            throw error
        }
        try Task.checkCancellation()
        guard callback.state == attempt.state else { throw AccountError.invalidCallback }
        if callback.error == "access_denied" { throw AccountError.accessDenied }
        guard ChatGPTOAuth.callbackMatches(callback, expectedState: attempt.state,
                                           expectedClientID: previous?.clientID,
                                           isNewRegistration: isNew), let code = callback.code else {
            throw AccountError.invalidCallback
        }
        let issuedClientID = isNew ? try requireIssuedClientID(callback.clientID) : previous!.clientID
        if isNew {
            try ensureCurrent(operationGeneration)
            let registration = Credential(clientID: issuedClientID, callbackURI: callbackURI, hostID: hostID,
                                          subject: "", email: "", idToken: nil, accessToken: nil,
                                          refreshToken: nil, expiresAt: nil, scopes: [])
            try saveCredential(registration)
        }
        try ensureCurrent(operationGeneration)
        let discovery = try await fetchDiscovery()
        let tokens = try await exchangeCode(code, clientID: issuedClientID, attempt: attempt, endpoint: discovery.token_endpoint)
        guard hasPlanScopes(tokens.scope.split(separator: " ").map(String.init)) else { throw AccountError.planScopeMissing }
        guard let idToken = tokens.id_token else { throw AccountError.invalidIdentityToken }
        let jwks = try await fetch(discovery.jwks_uri)
        let identity = try ChatGPTOAuth.verifyIDToken(idToken, jwksData: jwks, audience: issuedClientID,
                                                     nonce: attempt.nonce,
                                                     expectedSubject: previous?.subject.isEmpty == false ? previous?.subject : nil)
        guard let refreshToken = tokens.refresh_token, tokens.token_type.lowercased() == "bearer" else { throw AccountError.invalidResponse }
        let saved = Credential(clientID: issuedClientID, callbackURI: callbackURI, hostID: hostID,
                               subject: identity.subject, email: identity.email, idToken: idToken,
                               accessToken: tokens.access_token, refreshToken: refreshToken,
                               expiresAt: Date().addingTimeInterval(tokens.expires_in),
                               scopes: tokens.scope.split(separator: " ").map(String.init))
        try ensureCurrent(operationGeneration)
        try saveCredential(saved)
        return ChatGPTAccountProfile(email: identity.email, subject: identity.subject)
    }

    func cancelSignIn() {
        callbackServer?.cancel()
    }

    func signOut() async -> Bool {
        loggingOut = true
        generation &+= 1
        callbackServer?.cancel(); callbackServer = nil
        refreshTask?.cancel(); refreshTask = nil
        defer { loggingOut = false }
        let record = loadCredential()
        var revoked = record.refreshToken == nil
        if let refreshToken = record.refreshToken, let clientID = nonEmpty(record.clientID) {
            do {
                let discovery = try await fetchDiscovery()
                guard let endpoint = discovery.revocation_endpoint else { throw AccountError.invalidResponse }
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = formBody(["token": refreshToken, "token_type_hint": "refresh_token", "client_id": clientID])
                let (_, response) = try await session.data(for: request)
                revoked = (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                revoked = false
            }
        }
        if var record = credential ?? loadCredentialIfPresent() {
            record.accessToken = nil; record.refreshToken = nil; record.idToken = nil; record.expiresAt = nil
            do { try saveCredential(record) } catch { deleteCredential() }
        } else {
            deleteCredential()
        }
        return revoked
    }

    func accessToken() async throws -> String {
        guard !loggingOut else { throw AccountError.notSignedIn }
        let record = loadCredential()
        guard hasPlanScopes(record.scopes), let token = record.accessToken, let expiry = record.expiresAt,
              record.refreshToken != nil else { throw AccountError.notSignedIn }
        if expiry.timeIntervalSinceNow > 90 { return token }
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await self.refreshAccessToken() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    func refreshModels() async throws -> [ChatGPTModel] { try await refreshModelCatalog().models }

    func refreshModelCatalog() async throws -> (models: [ChatGPTModel], notice: String) {
        let token = try await accessToken()
        var request = URLRequest(url: URL(string: ChatGPTOAuth.resource + "/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AccountError.modelsUnavailable }
        return (try ChatGPTOAuth.parseModels(data), ChatGPTOAuth.catalogNotice(data))
    }

    private func refreshAccessToken() async throws -> String {
        let operationGeneration = generation
        let record = loadCredential()
        guard let refreshToken = record.refreshToken, !record.clientID.isEmpty else { throw AccountError.notSignedIn }
        let discovery = try await fetchDiscovery()
        var request = URLRequest(url: discovery.token_endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(["grant_type": "refresh_token", "client_id": record.clientID,
                                     "refresh_token": refreshToken, "resource": ChatGPTOAuth.resource])
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AccountError.refreshFailed }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard tokens.token_type.lowercased() == "bearer",
              hasPlanScopes(tokens.scope.split(separator: " ").map(String.init)),
              let nextRefresh = tokens.refresh_token else { throw AccountError.refreshFailed }
        var updated = record
        updated.accessToken = tokens.access_token
        updated.refreshToken = nextRefresh
        updated.expiresAt = Date().addingTimeInterval(tokens.expires_in)
        updated.scopes = tokens.scope.split(separator: " ").map(String.init)
        if let idToken = tokens.id_token {
            let jwks = try await fetch(discovery.jwks_uri)
            let identity = try ChatGPTOAuth.verifyIDToken(idToken, jwksData: jwks, audience: record.clientID,
                                                          nonce: nil, expectedSubject: record.subject)
            updated.idToken = idToken
            updated.email = identity.email
        }
        try ensureCurrent(operationGeneration)
        try saveCredential(updated)
        return tokens.access_token
    }

    private func exchangeCode(_ code: String, clientID: String, attempt: AuthorizationAttempt, endpoint: URL) async throws -> TokenResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(["grant_type": "authorization_code", "client_id": clientID,
                                     "code": code, "redirect_uri": attempt.callbackURI,
                                     "code_verifier": attempt.verifier, "resource": ChatGPTOAuth.resource])
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AccountError.codeExchangeFailed }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchDiscovery() async throws -> Discovery {
        let data = try await fetch(URL(string: ChatGPTOAuth.issuer + "/.well-known/openid-configuration")!)
        let discovery = try JSONDecoder().decode(Discovery.self, from: data)
        guard discovery.issuer == ChatGPTOAuth.issuer,
              [discovery.authorization_endpoint, discovery.token_endpoint, discovery.jwks_uri]
                .allSatisfy({ $0.scheme == "https" && $0.host == "auth.openai.com" }),
              discovery.revocation_endpoint.map({ $0.scheme == "https" && $0.host == "auth.openai.com" }) ?? true else {
            throw AccountError.invalidDiscovery
        }
        return discovery
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AccountError.networkRequestFailed }
        return data
    }

    private func hasPlanScopes(_ scopes: [String]) -> Bool {
        Set(scopes).isSuperset(of: ChatGPTOAuth.requiredScopes)
    }

    private func stableHostID() -> String {
        let key = "commissiewijzer.chatgpt.extAgentHostID"
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: key), UUID(uuidString: saved) != nil { return "urn:uuid:" + saved.lowercased() }
        let uuid = UUID().uuidString.lowercased()
        defaults.set(uuid, forKey: key)
        return "urn:uuid:" + uuid
    }

    private func loadCredential() -> Credential {
        if didLoadCredential, let credential { return credential }
        didLoadCredential = true
        credential = ChatGPTKeychain.load()
        return credential ?? Credential(clientID: "", callbackURI: "", hostID: "", subject: "", email: "",
                                        idToken: nil, accessToken: nil, refreshToken: nil, expiresAt: nil, scopes: [])
    }

    private func loadCredentialIfPresent() -> Credential? {
        if didLoadCredential { return credential }
        didLoadCredential = true; credential = ChatGPTKeychain.load()
        return credential
    }

    private func saveCredential(_ record: Credential) throws {
        try ChatGPTKeychain.save(record)
        credential = record; didLoadCredential = true
    }

    private func deleteCredential() {
        ChatGPTKeychain.delete(); credential = nil; didLoadCredential = true
    }

    private func ensureCurrent(_ expected: UInt64) throws {
        try Task.checkCancellation()
        guard !loggingOut, expected == generation else { throw CancellationError() }
    }

    private func nonEmpty(_ value: String) -> String? { value.isEmpty ? nil : value }

    private func requireIssuedClientID(_ value: String?) throws -> String {
        guard let value, !value.isEmpty, value != "dynamic_agent_client" else { throw AccountError.invalidCallback }
        return value
    }

    private func formBody(_ values: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = values.keys.sorted().map { URLQueryItem(name: $0, value: values[$0]) }
        let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "%20", with: "+")
        return Data(encoded.utf8)
    }
}

private final class RedirectRefuser: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum ChatGPTKeychain {
    private static let service = "nl.commissiewijzer.chatgpt-account"
    private static let account = "primary"

    static func load() -> ChatGPTConnection.Credential? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(ChatGPTConnection.Credential.self, from: data)
    }

    static func save(_ credential: ChatGPTConnection.Credential) throws {
        let data: Data
        do { data = try JSONEncoder().encode(credential) }
        catch { throw AccountError.keychainFailure }
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            for (key, value) in attributes { query[key] = value }
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw AccountError.keychainFailure }
        } else if updateStatus != errSecSuccess {
            throw AccountError.keychainFailure
        }
    }

    static func delete() { SecItemDelete(baseQuery as CFDictionary) }

    private static var baseQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }
}

private final class LoopbackCallbackServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "nl.commissiewijzer.chatgpt-oauth-callback")
    private let lock = NSLock()
    private var readyContinuation: CheckedContinuation<URL, Error>?
    private var callbackContinuation: CheckedContinuation<ChatGPTOAuth.Callback, Error>?
    private var callbackResult: Result<ChatGPTOAuth.Callback, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var selectedPort: UInt16?
    private var stopped = false

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters, on: .any)
        listener.newConnectionHandler = { [weak self] connection in self?.receive(connection) }
    }

    func start() async throws -> String {
        let url = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                lock.lock()
                guard !stopped, !Task.isCancelled else {
                    lock.unlock(); continuation.resume(throwing: CancellationError()); return
                }
                readyContinuation = continuation
                lock.unlock()
                listener.stateUpdateHandler = { [weak self] state in self?.listenerStateChanged(state) }
                listener.start(queue: queue)
            }
        } onCancel: { self.cancel() }
        return url.absoluteString
    }

    func waitForCallback(timeout: TimeInterval = 300) async throws -> ChatGPTOAuth.Callback {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ChatGPTOAuth.Callback, Error>) in
                lock.lock()
                if let callbackResult {
                    lock.unlock(); continuation.resume(with: callbackResult); return
                }
                guard !stopped else { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                callbackContinuation = continuation
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)) }
                    catch { return }
                    self?.finish(.failure(AccountError.callbackTimedOut))
                }
                lock.unlock()
            }
        } onCancel: {
            self.finish(.failure(CancellationError()))
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func listenerStateChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener.port else { finishReady(.failure(AccountError.listenerUnavailable)); return }
            let host = "127.0.0.1"
            var components = URLComponents()
            components.scheme = "http"; components.host = host; components.port = Int(port.rawValue); components.path = "/auth/callback"
            guard let url = components.url else { finishReady(.failure(AccountError.listenerUnavailable)); return }
            lock.lock(); selectedPort = port.rawValue; lock.unlock()
            finishReady(.success(url))
        case .failed:
            finishReady(.failure(AccountError.listenerUnavailable))
            finish(.failure(AccountError.listenerUnavailable))
        case .cancelled:
            finishReady(.failure(CancellationError()))
        default: break
        }
    }

    private func finishReady(_ result: Result<URL, Error>) {
        lock.lock(); let continuation = readyContinuation; readyContinuation = nil; lock.unlock()
        continuation?.resume(with: result)
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        guard accumulated.count < 16_384 else { connection.cancel(); return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384 - accumulated.count) { [weak self] data, _, complete, error in
            if error != nil { connection.cancel(); return }
            var request = accumulated
            if let data { request.append(data) }
            if let range = request.range(of: Data("\r\n\r\n".utf8)) {
                let header = Data(request[..<range.upperBound])
                guard let self, let port = self.listeningPort,
                      let callback = ChatGPTOAuth.parseCallbackRequest(header, expectedHost: "127.0.0.1:\(port)") else {
                    connection.cancel(); return
                }
                self.respond(connection)
                self.finish(.success(callback))
            } else if complete { connection.cancel() }
            else { self?.receive(connection, accumulated: request) }
        }
    }

    private var listeningPort: UInt16? { lock.lock(); defer { lock.unlock() }; return selectedPort }

    private func respond(_ connection: NWConnection) {
        let body = "<!doctype html><meta charset=\"utf-8\"><title>CommissieWijzer</title><p>Aanmelden verwerkt. Je kunt dit venster sluiten en teruggaan naar CommissieWijzer.</p>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private func finish(_ result: Result<ChatGPTOAuth.Callback, Error>) {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true; callbackResult = result
        let continuation = callbackContinuation; callbackContinuation = nil
        let timeout = timeoutTask; timeoutTask = nil
        lock.unlock()
        timeout?.cancel()
        listener.cancel()
        continuation?.resume(with: result)
    }
}

private enum AccountError: LocalizedError {
    case invalidRequest, randomnessUnavailable, invalidCallback, accessDenied, callbackTimedOut, listenerUnavailable
    case invalidIdentityToken, planScopeMissing, invalidResponse, invalidDiscovery, networkRequestFailed
    case browserUnavailable, codeExchangeFailed, refreshFailed, modelsUnavailable, notSignedIn, keychainFailure

    var errorDescription: String? {
        switch self {
        case .invalidRequest: "De aanmeldverzoek is ongeldig."
        case .randomnessUnavailable: "Veilige aanmeldgegevens konden niet worden gemaakt."
        case .invalidCallback: "De lokale aanmeldreactie was ongeldig. Probeer opnieuw."
        case .accessDenied: "Aanmelden is geweigerd."
        case .callbackTimedOut: "Aanmelden duurde te lang. Probeer opnieuw."
        case .listenerUnavailable: "De lokale terugkoppeling kon niet worden gestart."
        case .invalidIdentityToken: "De identiteit van ChatGPT kon niet veilig worden bevestigd."
        case .planScopeMissing: "De ChatGPT-account heeft geen toestemming gegeven voor modelgebruik."
        case .invalidResponse: "ChatGPT gaf een ongeldige reactie."
        case .invalidDiscovery: "De officiële aanmeldconfiguratie kon niet veilig worden gevalideerd."
        case .networkRequestFailed: "Verbinding met ChatGPT is mislukt."
        case .browserUnavailable: "De systeem browser kon niet worden geopend."
        case .codeExchangeFailed: "De aanmeldcode kon niet worden ingewisseld. Probeer opnieuw."
        case .refreshFailed: "De ChatGPT-sessie kon niet worden vernieuwd. Meld opnieuw aan."
        case .modelsUnavailable: "De modellenlijst van deze ChatGPT-account kon niet worden opgehaald."
        case .notSignedIn: "Meld je eerst aan met ChatGPT."
        case .keychainFailure: "De beveiligde ChatGPT-gegevens konden niet worden opgeslagen."
        }
    }
}
