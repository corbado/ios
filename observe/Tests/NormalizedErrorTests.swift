import Foundation
import Testing

@testable import CorbadoObserve

extension TrackerIntegrationTests {
    @Test func applicationStepErrorsPreserveStringCodesAndOptionalMessages() async throws {
        for error in [
            NormalizedError(code: "invalid_otp", message: "blocked"),
            NormalizedError(code: "http_error", message: "HTTP 503"),
            NormalizedError(code: "transport_failed"),
        ] {
            let (tracker, transport) = await makeTracker()
            let op = tracker.passwordLoginOperation()
            op.start()
            op.postResponse.start()
            op.postResponse.error(error)

            let events = await drain(tracker, transport, eventCount: 3)
            let event = try #require(events.first { $0.name == "subflow_step_error" })
            let stepData = try #require(event.data.objectValue?["stepData"]?.objectValue)
            let payload = try #require(stepData["error"]?.objectValue)
            #expect(payload["code"]?.stringValue == error.code)
            #expect(payload["message"]?.stringValue == error.message)
            #expect(payload["name"] == nil)
            #expect(stepData["code"] == nil)
            #expect(stepData["message"] == nil)
        }
    }

    @Test func genericStepErrorsPreserveNativeCodesInNestedPayload() async throws {
        let errors: [(any Error, String)] = [
            (URLError(.timedOut), "NSURLErrorDomain:-1001"),
            (URLError(.notConnectedToInternet), "NSURLErrorDomain:-1009"),
            (NSError(domain: "OtherDomain", code: -1001), "OtherDomain:-1001"),
        ]
        for (nativeError, expectedCode) in errors {
            let (tracker, transport) = await makeTracker()
            let op = tracker.passwordLoginOperation()
            op.start()
            op.postResponse.start()
            op.postResponse.error(nativeError)

            let events = await drain(tracker, transport, eventCount: 3)
            let event = try #require(events.first { $0.name == "subflow_step_error" })
            let payload = try #require(event.data.objectValue?["stepData"]?.objectValue?["error"]?.objectValue)
            #expect(payload["code"]?.stringValue == expectedCode)
            #expect(payload["name"]?.stringValue == String(describing: type(of: nativeError)))
            #expect(payload["message"]?.stringValue == nativeError.localizedDescription)
        }
    }
}
