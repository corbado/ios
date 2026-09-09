# Situation captures

The JSONL fixtures live in [`observe/Tests/Fixtures`](../../observe/Tests/Fixtures) and are bundled with the replay tests.

Raw probe output of the example app (`examples/observe`, `probe.jsonl` from the app's Documents)
for the situation runs recorded in `../as-af-research.md` §8. One JSON object per line:
`{"ts": <ms epoch>, "event": <name>, "screen": <screen id>, ...fields}`. Markers
(`"event":"marker"`) delimit scenarios; the label names the situation (`d-s11-fill` = device
run of S11).

| File | Environment | Scenarios |
|---|---|---|
| `2026-09-03-simulator-probe.jsonl` | iPhone 17 simulator, iOS 26.5, hardware keyboard, iCloud Keychain account with password + passkey | markers setup, s1-probe, s8-refire, s3-known, s4-usernameless, s11-fill, s19-paste, s12-password, s13-identifier, s14-harvest, s21-cui, s22-silence, s23-handover-cancel/collide, s24-chips, s25-arm-after-focus (chips never rendered, picks via key-icon picker) |
| `2026-09-03-device-probe.jsonl` | iPhone 13, iOS 27.0 beta, Keychain then Bitwarden as sole provider | setup, S1, S9, S11–S13, S21, S24, S25, S17 (three paths), S10, S1-provider, passcode fallback |

Event vocabulary (emitters in `examples/observe/Sources/Probe`):

- `as_start / as_result / as_error / as_cancel` — `ASAuthorizationController` run; `trigger`
  says who fired it, `durationMs` from `performRequests`, `biometry` is the `LAContext`
  answer at start (device run only).
- `field_focus` (begin/end editing), `field_delegate_ranges` (iOS 26+ plural delegate,
  `replacementLength` 0 = the chip-tap precursor), `field_text_changed` (`bulk` when
  |delta| > 1), `field_app_set` (programmatic value), `field_paste`.
- `app_state` — lifecycle; `blipMs` on `didBecomeActive` is the time since `willResignActive`.
- `swiftui_focus` / `swiftui_text` — the SwiftUI form's `@FocusState` and text changes.
- `password_credential` — `ASPasswordCredential` result of a password/mixed request;
  `harvest` — the hidden identifier field received a value.
- `app_launch`, `probe_cleared`, `flow_start`, `navigate`, `ui_tap`, `login_success`,
  `enrollment_success`, `account_created`, `marker`.

The simulator's live unified-log stream (SDK `Track:` lines) was not preserved; SDK-side
mapping for the simulator run is summarised in §8 only.
