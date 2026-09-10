import CorbadoObserve
import SwiftUI

/// S11 on plain SwiftUI controls: no UIKit delegate, so the only field signals an integration can
/// forward are `@FocusState` changes and value lengths. Records whether SwiftUI reflects the
/// responder churn of a system fill (focus hops between the fields) and how the values arrive.
struct SwiftUIFormScreen: View {
    let context: ScreenContext
    @StateObject private var model = PasswordLoginModel(specType: .withIdentifier)

    private enum Field: String { case identifier, password }
    @FocusState private var focus: Field?

    var body: some View {
        ScreenColumn {
            ScreenHeader(title: "Log in (SwiftUI)", subtitle: "Plain TextField + SecureField, FocusState only.")
            TextField("Email", text: $model.identifier)
                .textContentType(.username).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focus, equals: .identifier)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $model.password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .textFieldStyle(.roundedBorder)
            Button(model.busy ? "Signing in…" : "Log in") { model.submit(context) }
                .buttonStyle(.pill).disabled(model.busy)
            if let status = model.status { Text(status).font(.callout) }
        }
        .onChange(of: focus) { old, new in
            Probe.log("swiftui_focus", ["from": old?.rawValue, "to": new?.rawValue])
            if old == .identifier || new == .identifier { model.identifierFocus(new == .identifier) }
            if old == .password || new == .password { model.passwordFocus(new == .password) }
        }
        .onChange(of: model.identifier) { old, new in
            logText("identifier", old: old, new: new)
            model.identifierChanged(new)
        }
        .onChange(of: model.password) { old, new in
            logText("password", old: old, new: new)
            model.passwordChanged(new)
        }
        .onChange(of: context.flowActive, initial: true) { _, _ in model.flowActiveChanged(context) }
    }

    private func logText(_ field: String, old: String, new: String) {
        let delta = new.count - old.count
        Probe.log(
            "swiftui_text",
            [
                "field": field, "delta": delta, "length": new.count, "bulk": abs(delta) > 1,
                "focus": focus?.rawValue, "msSinceActive": LifecycleProbe.shared.msSinceBecomeActive,
            ])
    }
}
