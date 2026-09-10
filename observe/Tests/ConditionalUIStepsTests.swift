import Foundation
import Testing

@testable import CorbadoObserve

extension TrackerIntegrationTests {
    @Test func conditionalUiStepsStampSpecTypeAndShipRawErrors() async throws {
        let (tracker, transport) = await makeTracker()
        let op = tracker.passwordLoginOperation()
        op.start()

        op.cui.getOptionsStarted()
        op.cui.getOptionsFinished(assertionOptions: "{\"challenge\":\"abc\"}")
        op.cui.ceremonyStarted()
        op.cui.ceremonyFailed(
            NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: 1004))

        let events = await drain(tracker, transport, eventCount: 5)
        #expect(
            events.map(\.name) == [
                "subflow_started", "subflow_step_started", "subflow_step_finished", "subflow_step_started",
                "subflow_step_error",
            ])
        let payloads = events.map { $0.data.objectValue ?? [:] }
        #expect(payloads[1]["stepName"]?.stringValue == "cui-get-options")
        #expect(payloads[1]["ignoreAsInteraction"] == .bool(true))
        #expect(payloads[1]["stepData"]?.objectValue?["explicitSpecType"]?.stringValue == "passkey-cui")
        #expect(payloads[2]["stepData"]?.objectValue?["assertionOptions"]?.stringValue == "{\"challenge\":\"abc\"}")
        #expect(payloads[3]["stepName"]?.stringValue == "cui-ceremony")
        #expect(payloads[3]["ignoreAsInteraction"] == nil)
        #expect(payloads[3]["stepData"]?.objectValue?["explicitSpecType"]?.stringValue == "passkey-cui")
        let error = try #require(payloads[4]["stepData"]?.objectValue?["error"]?.objectValue)
        #expect(error["code"]?.stringValue == "com.apple.AuthenticationServices.AuthorizationError:1004")
        #expect(payloads.allSatisfy { $0["subflowType"]?.stringValue == "password-login" })
    }

    @Test func provideIdentifierHostsTheSameConditionalUiSteps() async throws {
        let (tracker, transport) = await makeTracker()
        let op = tracker.provideIdentifierOperation()
        op.start(specType: .email)
        op.cui.ceremonyStarted()
        op.cui.ceremonyFinished(assertionResponse: "{}")
        op.cui.postResponse.start()

        let events = await drain(tracker, transport, eventCount: 4)
        #expect(
            events.dropFirst().compactMap { $0.data.objectValue?["stepName"]?.stringValue } == [
                "cui-ceremony", "cui-ceremony", "cui-post-response",
            ])
        #expect(events.allSatisfy { $0.data.objectValue?["subflowType"]?.stringValue == "provide-identifier" })
    }
}
