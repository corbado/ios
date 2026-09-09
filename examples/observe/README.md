# Observe example app

SwiftUI situation-screen app for the Observe SDK — its development vehicle, never published.
One screen per situation from `docs/as-af-situations.md`; the devbar (gear button) switches
screens, environment, rpId and flow auto-start.

The Xcode project is generated, not checked in:

```bash
brew install xcodegen   # once
cd examples/observe
xcodegen generate
open ObserveExample.xcodeproj
```

Edit targets/settings in `project.yml`, then re-run `xcodegen generate`.

## Passkeys

Ceremonies need the rpId's `apple-app-site-association` to list `T9A667JL6T.com.corbado.observe-example`
(default rpId `corbado-demo.com` does). Device: Settings → Developer → Associated Domains
Development on, and sign in with the team in Xcode. Simulator: Features → Face ID → Enrolled.

## Experiment output

Every observation is one JSON line (`Probe`), written to unified logging and to the app's
`Documents/probe.jsonl`; the SDK's debug log (`Track: <event> <json>`) rides the same unified-log
stream. Pull it without touching the UI:

```bash
tools/capture.sh sim-stream start # simulator: live probe + SDK events → /tmp/observe-capture.ndjson
tools/capture.sh sim-stream show  #   ... print what was streamed so far (stop with `sim-stream stop`)
tools/capture.sh sim --last 15m   # simulator: persisted log (probe lines only; SDK debug lines are not persisted)
tools/capture.sh sim-file         # simulator: probe.jsonl
tools/capture.sh device-file      # USB device: probe.jsonl via devicectl
tools/capture.sh device-log       # USB device: unified log via `log collect --device`
```

Devbar → Probe → "Mark" drops a `marker` line to cut a capture into experiments.
