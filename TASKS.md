# Tasks

Open follow-ups, roughly ordered.

- Review `PrivacyInfo.xcprivacy` collected-data entries with a real integrator (first
  pass is conservative; required-reason part is settled).
- `deviceOwnerAuth` misreports biometry-locked-out devices as `code` (LAError discarded).
- Wall-clock-only timing distorts ceremony latencies across suspension/clock changes —
  cross-platform topic (Android identical; iOS monotonic APIs are required-reason).
- Magic-link flows: start/finish can land in different processes/sessions; unstitched.
- Prewarming: init before first unlock finds prefs/outbox unreadable; session-start
  semantics under prewarmed launches unvalidated.
- Multi-field system fills over-count: each per-field `big-input-add` is its own autofill
  match in the classifier (all platforms).
- Backend: no ceremony detector runs for `type: "app"` client environments (the passkey
  detector claims nothing without web env data, form-input falls to the strict adjacent
  overlay matcher), so native `window-blur`/`window-focus` are stored but never matched; needs
  an app-env detector with a bare bracket and the ~1.7 s Face ID blip tolerance.
- Wire-contract topics (all platforms): `clientEnvHandleMeta.timestamp`/`source: "native"` vs
    native passkey-enrollment ceremonies carry no `mediation`; `flow_finished` data duplicates
  `userId`/`identifier` that the backend ignores.
- Wire-contract topic (all platforms): `WebAuthnSanitizer` strips only `response.signature`, so
  `response.userHandle` (the RP's stable user id) travels in every `assertionResponse`; the
  backend resolves the authenticator from the credential id, so either strip it in the sanitizer
  or state the carry in the integrator docs.
- Android parity for the ambient lows iOS now emits (`focus`/`blur` per field,
  `window-blur`/`window-focus` around ceremonies and focused fields) and for the typing-batch
  flush on flow reset — Android has neither yet.
- Android parity for the typed conditional-UI helper (`passkey-cui` stamped on the CUI steps,
  raw ceremony error), for `start(ignoreAsInteraction:)` on the form operations, and for
  consuming the announced-fill window on match (Android reuses it within the second).
- OTP fill signature (`.oneTimeCode`, iOS 26 empty `replacementString`) still unmeasured;
  the example app's sms-otp screen is ready, an SMS sender is not.
- Automatic passkey upgrades: deferred model decision — step on password-login (CUI
  precedent) vs trailing subflow; purely additive, revisit on first customer use.
- Port the remaining Android test matrix (autofill-low edge cases, retry/backoff queue
  scenarios, system-credential settle matrix, typed-operation vocabulary sweep); positive
  contracts still untested: affordance `shown`/`hidden` duration, `flowReset` batch flush,
  enrollment/social/OTP/provide-data/password-enrollment vocabularies, decisions and
  multi-flow starts, `initialize` validation, `setTransportEnabled`, telemetry batching.
- Main-safety guarantee test (the Android `MainSafetyTest` sibling).
- Real-device validation: background-flush timing, outbox recovery after suspension/kill.
- Sign in with Apple: validate the social-login vs system-credential attribution guidance.
- Automatic affordance evidence: revisit the autofill-affordance gap (see docs/LIMITATIONS.md).
- Lows carry no idempotency id and share the batch's (possibly recovered) session id — raise
  as a cross-platform wire-contract topic (Android behaves identically).
- observe/README: mirror the Android section set (status, operations table, host-app
  controls, data collection & privacy, design principles).
