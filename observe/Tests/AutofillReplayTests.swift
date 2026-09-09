import Foundation
import Testing
import UIKit

@testable import CorbadoObserve

/// Replays recorded situation captures (`Fixtures/*.jsonl`, see `docs/as-af-signal-spec.md`)
/// through the public field/lifecycle surface and pins the low-event shape the SDK emits for
/// each fill path. The probe rows map 1:1 onto what an integration forwards: value lengths,
/// focus changes, and the app's active-state notifications.
extension TrackerIntegrationTests {
    private struct Row: @unchecked Sendable {
        let ts: Int64
        let event: String
        let screen: String
        let fields: [String: Any]

        var field: String? { fields["field"] as? String }
        var label: String? { fields["label"] as? String }

        /// The `UIApplication` notification an `app_state` row stands for, when it is one the
        /// tracker listens to.
        var lifecycleNotification: Notification.Name? {
            switch fields["state"] as? String {
            case "willResignActive": UIApplication.willResignActiveNotification
            case "didBecomeActive": UIApplication.didBecomeActiveNotification
            default: nil
            }
        }
    }

    private static func capture(_ name: String) throws -> [Row] {
        // Bundle fixtures so replay works in vendored packages and on physical test devices.
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map { line in
            let object = try #require(
                try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            return Row(
                ts: try #require(object["ts"] as? Int64), event: try #require(object["event"] as? String),
                screen: object["screen"] as? String ?? "", fields: object)
        }
    }

    /// Rows after marker `from` up to the next marker (or marker `until`), on one screen; with
    /// `throughLogin` the slice ends at the first `login_success` (one attempt only).
    private static func slice(
        _ rows: [Row], from: String, until: String? = nil, screen: String, throughLogin: Bool = false
    ) throws -> [Row] {
        let start = try #require(rows.lastIndex(where: { $0.event == "marker" && $0.label == from }))
        var out: [Row] = []
        for row in rows[(start + 1)...] {
            if row.event == "marker", until == nil || row.label == until { break }
            if row.screen == screen { out.append(row) }
            if throughLogin, row.event == "login_success" { break }
        }
        try #require(!out.isEmpty, "Capture slice \(from) on \(screen) is empty")
        return out
    }

    /// Feeds one slice through a password-login operation; returns the lows in emission order.
    private func replay(_ rows: [Row], tracker: ObserveTracker, transport: CapturingTransport) async
        -> [WireLowEvent]
    {
        var op: PasswordLoginOperation?
        var pasteNext: Set<String> = []
        for row in rows {
            switch row.event {
            case "flow_start":
                tracker.flowStarted("login")
                op = tracker.passwordLoginOperation()
                op?.start(specType: .withIdentifier)
            case "field_text_changed", "field_paste", "field_app_set", "field_focus":
                Self.forward(row, to: Self.observer(op, for: row.field), pasteNext: &pasteNext)
            case "app_state":
                if let name = row.lifecycleNotification {
                    await MainActor.run { NotificationCenter.default.post(name: name, object: nil) }
                }
            case "ui_tap" where row.fields["target"] as? String == "login":
                op?.postResponse.start()
            case "login_success":
                tracker.flowFinished("login")
            default:
                break
            }
        }
        _ = await drain(tracker, transport, eventCount: 1, lowCount: 1)
        return transport.lows
    }

    /// What an integration forwards for one field row: lengths (with the paste flag when the
    /// field reported one), announced app writes, focus changes.
    private static func forward(_ row: Row, to observer: FieldObserver?, pasteNext: inout Set<String>) {
        let length = row.fields["length"] as? Int ?? 0
        switch row.event {
        case "field_text_changed":
            observer?.changed(newLength: length, paste: pasteNext.remove(row.field ?? "") != nil)
        case "field_paste":
            pasteNext.insert(row.field ?? "")
        case "field_app_set":
            observer?.applicationFill(actor: "app")
            observer?.changed(newLength: length)
        case "field_focus":
            observer?.focusChanged(row.fields["state"] as? String == "begin")
        default:
            break
        }
    }

    private static func observer(_ op: PasswordLoginOperation?, for field: String?) -> FieldObserver? {
        switch field {
        case "identifier", "hidden-identifier": op?.identifierField
        case "password": op?.passwordField
        default: nil
        }
    }

    @Test func keychainChipFillIsFocusChurnInsideAWindowBlip() async throws {
        let rows = try Self.slice(
            Self.capture("2026-09-03-device-probe.jsonl"), from: "d-s11-fill", screen: "login-form")
        let (tracker, transport) = await makeTracker()

        let lows = await replay(rows, tracker: tracker, transport: transport)

        #expect(
            lows.map(\.lowType) == [
                "focus", "window-blur", "big-input-add", "blur", "focus", "big-input-add", "blur", "focus",
                "window-focus",
            ])
        let fills = lows.filter { $0.lowType == "big-input-add" }
        #expect(fills.map(\.fieldType) == ["provide-identifier", "password-login"])
        #expect(fills.allSatisfy { $0.actor == nil })
    }

    @Test func hiddenIdentifierFillReplacesAndPairsWithThePassword() async throws {
        let rows = try Self.slice(
            Self.capture("2026-09-03-device-probe.jsonl"), from: "d-s12-password", screen: "login-form-password",
            throughLogin: true)
        let (tracker, transport) = await makeTracker()

        let lows = await replay(rows, tracker: tracker, transport: transport)

        // The remembered identifier is an announced app fill; the system fill then replaces it
        // (delete + insert) and writes the password in the same millisecond.
        let bulk = lows.filter { $0.lowType.hasPrefix("big-input") || $0.lowType == "af-fill" }
        #expect(bulk.map(\.lowType) == ["af-fill", "big-input-rem", "big-input-add", "big-input-add"])
        let appFill = try #require(bulk.first)
        #expect(appFill.actor == "app")
        #expect(bulk.dropFirst().map(\.fieldType) == ["provide-identifier", "provide-identifier", "password-login"])
        #expect(lows.first?.lowType == "af-fill")
        #expect(lows.last?.lowType == "window-focus")
    }

    @Test func lockedProviderFillHasNoLifecycleEvidence() async throws {
        // Between the S25 re-run and the S17 marker: two fills through the locked provider's own
        // UI (no blip), then one chip fill with the provider unlocked (blip).
        let rows = try Self.slice(
            Self.capture("2026-09-03-device-probe.jsonl"), from: "d-s25-arm-after-focus", until: "d-s17-provider",
            screen: "login-form")
        let (tracker, transport) = await makeTracker()

        let lows = await replay(rows, tracker: tracker, transport: transport)

        let types = lows.map(\.lowType)
        #expect(types.filter { $0 == "big-input-add" }.count == 6)
        #expect(types.filter { $0 == "window-blur" }.count == 1)
        // The first two fills (four bulk lows) precede the only blip: bulk change is the base
        // evidence, the blip only corroborates.
        let blurIndex = try #require(types.firstIndex(of: "window-blur"))
        let fillIndexes = types.indices.filter { types[$0] == "big-input-add" }
        #expect(fillIndexes.prefix(4).allSatisfy { $0 < blurIndex })
        #expect(fillIndexes.suffix(2).allSatisfy { $0 > blurIndex })
    }

    @Test func pasteCarriesTheUserActor() async throws {
        let rows = try Self.slice(
            Self.capture("2026-09-03-simulator-probe.jsonl"), from: "s19-paste", screen: "login-form")
        let (tracker, transport) = await makeTracker()

        let lows = await replay(rows, tracker: tracker, transport: transport)

        // Typed identifier (one `input` stretch); the password was picker-filled, cleared, then
        // pasted: only the pasted bulk changes carry the user actor.
        let typed = try #require(lows.first { $0.lowType == "input" })
        #expect(typed.fieldType == "provide-identifier")
        let bulk = lows.filter { $0.lowType == "big-input-add" }
        #expect(bulk.map(\.actor) == [nil, "user", "user"])
        #expect(bulk.allSatisfy { $0.fieldType == "password-login" })
    }

    @Test func windowLowsAreArmedByCeremoniesAndFocusedFields() async throws {
        let (tracker, transport) = await makeTracker()

        let attempt = tracker.passkeyLoginOperation().begin(specType: .knownIdentifier)
        await blip()  // the sheet
        attempt.ceremonyFailed(NSError(domain: "com.apple.AuthenticationServices.AuthorizationError", code: 1001))
        await blip()
        let op = tracker.passwordLoginOperation()
        op.start()
        op.passwordField.focusChanged(true)
        await blip()  // Face ID for a fill
        op.passwordField.focusChanged(false)
        await blip()

        _ = await drain(tracker, transport, eventCount: 4, lowCount: 6)
        #expect(
            transport.lows.map(\.lowType) == [
                "window-blur", "window-focus", "focus", "window-blur", "window-focus", "blur",
            ])
    }

    /// `willResignActive` → `didBecomeActive`, as UIKit posts them.
    private func blip() async {
        await MainActor.run {
            let center = NotificationCenter.default
            center.post(name: UIApplication.willResignActiveNotification, object: nil)
            center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
}
