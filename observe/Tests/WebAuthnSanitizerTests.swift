import Foundation
import Testing

@testable import CorbadoObserve

@Suite struct WebAuthnSanitizerTests {
    private func json(_ value: String) -> [String: JSONValue]? {
        (try? WireJson.decoder.decode(JSONValue.self, from: Data(value.utf8)))?.objectValue
    }

    @Test func stripsAssertionSignatureKeepsRest() throws {
        let assertion = #"{"id":"cred","response":{"signature":"SIG","clientDataJSON":"CDJ","authenticatorData":"AD"}}"#
        let sanitized = WebAuthnSanitizer.sanitize(["assertionResponse": .string(assertion)])
        let raw = try #require(sanitized["assertionResponse"]?.stringValue)
        let root = try #require(json(raw))
        let response = try #require(root["response"]?.objectValue)
        #expect(response["signature"] == nil)
        #expect(response["clientDataJSON"]?.stringValue == "CDJ")
        #expect(response["authenticatorData"]?.stringValue == "AD")
        #expect(root["id"]?.stringValue == "cred")
    }

    @Test func neutralizesEnrollmentClientDataJSON() throws {
        let attestation = #"{"id":"cred","response":{"clientDataJSON":"REAL","attestationObject":"AO"}}"#
        let sanitized = WebAuthnSanitizer.sanitize(["attestationResponse": .string(attestation)])
        let raw = try #require(sanitized["attestationResponse"]?.stringValue)
        let root = try #require(json(raw))
        let response = try #require(root["response"]?.objectValue)
        let cdj = try #require(response["clientDataJSON"]?.stringValue)
        #expect(cdj != "REAL")
        // The stub must still decode as WebAuthn client data (base64url JSON without challenge).
        var padded = cdj.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.count % 4) % 4)
        let decoded = try #require(Data(base64Encoded: padded))
        let client = try #require(try JSONSerialization.jsonObject(with: decoded) as? [String: Any])
        #expect(client["challenge"] as? String == "")
        #expect(response["attestationObject"]?.stringValue == "AO")
    }

    @Test func redactsOptionsChallengeNonEmpty() throws {
        let options = #"{"challenge":"REAL","rp":{"id":"example.com"}}"#
        let sanitized = WebAuthnSanitizer.sanitize(["attestationOptions": .string(options)])
        let raw = try #require(sanitized["attestationOptions"]?.stringValue)
        let root = try #require(json(raw))
        let challenge = try #require(root["challenge"]?.stringValue)
        #expect(challenge != "REAL")
        #expect(!challenge.isEmpty)
        #expect(root["rp"]?.objectValue?["id"]?.stringValue == "example.com")
    }

    @Test func unparsablePayloadIsRedactedWholesale() {
        let sanitized = WebAuthnSanitizer.sanitize(["assertionResponse": .string("not json {")])
        #expect(sanitized["assertionResponse"]?.stringValue == "[redacted]")
    }

    @Test func recursesIntoNestedStepData() throws {
        let assertion = #"{"response":{"signature":"SIG"}}"#
        let sanitized = WebAuthnSanitizer.sanitize([
            "stepData": .object(["assertionResponse": .string(assertion)])
        ])
        let nested = try #require(sanitized["stepData"]?.objectValue?["assertionResponse"]?.stringValue)
        let root = try #require(json(nested))
        #expect(root["response"]?.objectValue?["signature"] == nil)
    }

    @Test func unrelatedPayloadPassesThrough() {
        let payload: [String: JSONValue] = [
            "flowName": .string("login"),
            "count": .int(3),
            "nested": .object(["ok": .bool(true)]),
        ]
        #expect(WebAuthnSanitizer.sanitize(payload) == payload)
    }
}
