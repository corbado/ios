import SwiftUI

struct LoginSuccessScreen: View {
    let context: ScreenContext

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Theme.greenSoft).frame(width: 132, height: 132)
                Circle().fill(Theme.green).frame(width: 92, height: 92)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
            }
            Text("You're in").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.ink)
            if let identifier = context.lastLoginIdentifier {
                Text(identifier).font(.callout).foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Button("Run again") {
                Probe.log("ui_tap", ["target": "run-again"])
                context.restartFlow()
            }
            .buttonStyle(.pill)
        }
        .padding(24)
    }
}
