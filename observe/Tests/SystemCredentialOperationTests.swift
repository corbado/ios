import Testing

@testable import CorbadoObserve

extension TrackerIntegrationTests {
    @Test(
        arguments: [
            [SystemCredentialOperation.RequestedOption.federated, .passkey, .password],
            [.password, .federated, .passkey],
            [.passkey, .password, .federated, .passkey, .federated],
        ], [false, true])
    func systemCredentialOptionSetsHaveCanonicalSpecs(
        requested: [SystemCredentialOperation.RequestedOption], autoTriggered: Bool
    ) async {
        let (tracker, transport) = await makeTracker()
        _ = tracker.systemCredentialOperation().begin(requested: requested, autoTriggered: autoTriggered)

        let events = await drain(tracker, transport, eventCount: 2)
        #expect(events.map(\.name) == ["subflow_started", "subflow_step_started"])
        #expect(
            events[0].data.objectValue?["explicitSpecType"]
                == .string(autoTriggered ? "federated-passkey-password-auto" : "federated-passkey-password"))
        #expect(events[0].data.objectValue?["ignoreAsInteraction"] == (autoTriggered ? .bool(true) : nil))
    }
}
