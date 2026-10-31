import XCTest
@testable import CommissieWijzer

final class AuthAuditTests: XCTestCase {
    func testIDTokenAudienceRequiresMatchingAuthorizedPartyForMultipleAudiences() {
        XCTAssertTrue(ChatGPTOAuth.audienceIsValid(["client-a"], authorizedParty: nil, expected: "client-a"))
        XCTAssertTrue(ChatGPTOAuth.audienceIsValid(["client-a", "service-b"], authorizedParty: "client-a", expected: "client-a"))
        XCTAssertFalse(ChatGPTOAuth.audienceIsValid(["client-a", "service-b"], authorizedParty: nil, expected: "client-a"))
        XCTAssertFalse(ChatGPTOAuth.audienceIsValid(["client-a", "service-b"], authorizedParty: "service-b", expected: "client-a"))
        XCTAssertFalse(ChatGPTOAuth.audienceIsValid(["client-a"], authorizedParty: "service-b", expected: "client-a"))
        XCTAssertFalse(ChatGPTOAuth.audienceIsValid(["service-b"], authorizedParty: "client-a", expected: "client-a"))
    }

    func testLoopbackCallbackRejectsWrongHostDuplicateParametersAndBodyOverflow() {
        func request(_ target: String, host: String = "127.0.0.1:49152") -> Data {
            Data("GET \(target) HTTP/1.1\r\nHost: \(host)\r\n\r\n".utf8)
        }

        XCTAssertNotNil(ChatGPTOAuth.parseCallbackRequest(
            request("/auth/callback?code=abc&state=opaque"), expectedHost: "127.0.0.1:49152"))
        XCTAssertNil(ChatGPTOAuth.parseCallbackRequest(
            request("/auth/callback?code=abc&state=opaque", host: "localhost:49152"), expectedHost: "127.0.0.1:49152"))
        XCTAssertNil(ChatGPTOAuth.parseCallbackRequest(
            request("/auth/callback?code=abc&state=opaque&state=other"), expectedHost: "127.0.0.1:49152"))
        XCTAssertNil(ChatGPTOAuth.parseCallbackRequest(
            Data(repeating: 0x41, count: 16_385), expectedHost: "127.0.0.1:49152"))
    }

    func testPKCEUsesURLSafeS256Challenge() {
        // RFC 7636 Appendix B test vector checks the exact hash/encoding,
        // rather than only asserting the shape of our own output.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = ChatGPTOAuth.pkceChallenge(verifier: verifier)
        XCTAssertEqual(challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertEqual(challenge.count, 43)
        XCTAssertTrue(challenge.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    func testOldRefreshWaiterCannotClearReplacementRefresh() {
        var flight = ChatGPTRefreshFlight()
        let oldTask = Task<String, Error> { "old" }
        let oldID = flight.install(oldTask)
        flight.cancel()

        let newTask = Task<String, Error> { "new" }
        let newID = flight.install(newTask)
        flight.clear(ifCurrent: oldID)

        XCTAssertEqual(flight.current?.id, newID)
        XCTAssertFalse(flight.current?.task.isCancelled ?? true)
        flight.clear(ifCurrent: newID)
        XCTAssertNil(flight.current)
    }

    func testResponseStreamHasConfigurableTotalByteLimit() async {
        let stream = AsyncStream<UInt8> { continuation in
            for byte in Data("data: x\n\n".utf8) { continuation.yield(byte) }
            continuation.finish()
        }
        do {
            _ = try await ChatGPTService.collect(bytes: stream, maximumBytes: 5)
            XCTFail("An over-limit response stream must be rejected")
        } catch let error as ChatGPTError {
            if case .incomplete = error { } else { XCTFail("Expected incomplete response, got \(error)") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
