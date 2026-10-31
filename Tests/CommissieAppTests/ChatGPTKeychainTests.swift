import XCTest
import Security
@testable import CommissieWijzer

final class ChatGPTKeychainTests: XCTestCase {
    func testSyntheticCredentialCanBeAddedReadUpdatedAndDeleted() throws {
        let service = "nl.commissiewijzer.chatgpt-account.tests.\(UUID().uuidString)"
        let account = "synthetic"
        defer { ChatGPTKeychain.delete(service: service, account: account) }

        XCTAssertNil(ChatGPTKeychain.load(service: service, account: account))

        try ChatGPTKeychain.save(credential(email: "first@example.invalid", accessToken: "synthetic-access-1"),
                                 service: service, account: account)
        let saved = try XCTUnwrap(ChatGPTKeychain.load(service: service, account: account))
        XCTAssertEqual(saved.email, "first@example.invalid")
        XCTAssertEqual(saved.accessToken, "synthetic-access-1")
        XCTAssertEqual(saved.refreshToken, "synthetic-refresh")
        let attributes = try XCTUnwrap(itemAttributes(service: service, account: account))
        #if os(iOS)
        XCTAssertEqual(attributes[kSecAttrAccessible] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #endif
        XCTAssertNotEqual(attributes[kSecAttrSynchronizable] as? Bool, true)

        try ChatGPTKeychain.save(credential(email: "updated@example.invalid", accessToken: "synthetic-access-2"),
                                 service: service, account: account)
        let updated = try XCTUnwrap(ChatGPTKeychain.load(service: service, account: account))
        XCTAssertEqual(updated.email, "updated@example.invalid")
        XCTAssertEqual(updated.accessToken, "synthetic-access-2")

        ChatGPTKeychain.delete(service: service, account: account)
        XCTAssertNil(ChatGPTKeychain.load(service: service, account: account))
    }

    private func credential(email: String, accessToken: String) -> ChatGPTConnection.Credential {
        ChatGPTConnection.Credential(clientID: "synthetic-client", callbackURI: "http://127.0.0.1:12345/auth/callback",
                                     hostID: "synthetic-host", subject: "synthetic-subject", email: email,
                                     idToken: nil, accessToken: accessToken, refreshToken: "synthetic-refresh",
                                     expiresAt: Date(timeIntervalSince1970: 1_900_000_000), scopes: ["synthetic"])
    }

    private func itemAttributes(service: String, account: String) -> [CFString: Any]? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? [CFString: Any]
    }
}
