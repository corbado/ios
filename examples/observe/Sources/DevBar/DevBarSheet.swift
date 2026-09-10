import CorbadoObserve
import SwiftUI

/// The devbar: switch situation screens, change endpoint/project (re-inits the SDK), rpId, flow
/// auto-start, session reset/flush, probe markers and the recent probe lines. Deliberately
/// minimal.
struct DevBarSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var apiBaseUrl = ObserveEnv.apiBaseUrl
    @State private var projectId = ObserveEnv.projectId
    @State private var marker = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Screens") {
                    ForEach(ScreenRegistry.groups, id: \.0) { group, screens in
                        Text(group).font(.caption).foregroundStyle(.secondary)
                        ForEach(screens) { screen in
                            Button {
                                model.switchScreen(screen)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(screen.id == model.screen.id ? "▶" : (screen.implemented ? "•" : "○"))
                                    Text(screen.title + (screen.implemented ? "" : " (soon)"))
                                }
                            }
                            .disabled(!screen.implemented)
                        }
                    }
                }

                Section("Flow") {
                    Toggle("Auto-start flow on screen load", isOn: $model.autoStartFlow)
                    if !model.autoStartFlow, !model.flowActive, model.screen.flowName != nil {
                        Button("Start flow") {
                            model.startFlow(model.screen)
                            dismiss()
                        }
                    }
                    Toggle("Offer enrollment after login (no-passkey accounts)", isOn: $model.offerEnrollment)
                    Text("flow: \(model.flowActive ? (model.screen.flowName ?? "-") : "none")").font(.caption)
                }

                Section("Environment") {
                    ForEach(ObserveEnv.presets, id: \.self) { preset in
                        Button(preset.label) {
                            apiBaseUrl = preset.apiBaseUrl
                            projectId = preset.projectId
                        }
                    }
                    TextField("API base URL", text: $apiBaseUrl).autocorrectionDisabled()
                    TextField("Project ID", text: $projectId).autocorrectionDisabled()
                    Button("Apply environment (re-init SDK)") {
                        model.applyEnv(apiBaseUrl: apiBaseUrl, projectId: projectId)
                    }
                    TextField("Passkey rpId (empty = no passkey requests)", text: $model.rpId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Session") {
                    Text("sessionId: \(model.tracker?.getSessionId() ?? "(sdk not initialized)")").font(.caption)
                    Button("Reset session") { model.tracker?.resetSession() }
                    Button("Flush now") { model.tracker?.flush() }
                }

                Section("Probe") {
                    HStack {
                        TextField("marker label", text: $marker)
                        Button("Mark") {
                            Probe.marker(marker.isEmpty ? "mark" : marker)
                            marker = ""
                        }
                    }
                    Button("Clear probe file") { Probe.clearFile() }
                    Text(Probe.fileURL.path).font(.caption2).foregroundStyle(.secondary)
                    ForEach(Array(Probe.recent.suffix(30).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 10, design: .monospaced)).lineLimit(3)
                    }
                }
            }
            .navigationTitle("Devbar")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
