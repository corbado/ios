# AS/AF situations catalog

The situations in which AuthenticationServices (AS) and Password AutoFill (AF) typically
participate in authentication flows on iOS. Design input for the Observe SDK's tracking model:
every situation the library should be able to express and observe. Companion of
[as-af-research.md](as-af-research.md).

Notation: **trigger** (who starts it) · **request** (what is asked for) · **UI** (what the user
can see) · **effects** (how the login can be advanced). "S#" ids are referenced by the example-app
screens and later by the tracking-model proposal. `[verify]` marks what the example-app
experiments must pin down; `native2` marks what the reference integration does in production.

---

## A. AS modal ceremonies during login

Everything modal comes from one app call (`performRequests`), so the call site observes the
whole ceremony: request mix, options, timing, typed result or error. The two behaviors that
split situations are `.preferImmediatelyAvailableCredentials` (silent probe vs guaranteed
sheet) and the request mix.

### S1 — Silent opportunistic probe (welcome / gate)
Auto on the welcome, onboarding or gate screen, before any auth UI exists. Platform-passkey
assertion, discoverable (no `allowCredentials`), `.preferImmediatelyAvailableCredentials`.
UI: none when no local passkey matches — the delegate fires instantly with `.canceled` (1001),
the same code as a user dismissal. Effects: nothing visible; the app renders its normal welcome.
native2 fires this on welcome and onboarding and swallows the result today. The flag is
ignored when a security-key request is in the mix; whether third-party-provider passkeys count
as "immediately available" `[verify]`.

### S2 — Silent probe with a local match → auto sheet
Same call as S1, a passkey exists. UI: the full sheet including cross-device options; a single
credential collapses toward a direct Face ID confirm `[verify collapse conditions]`. Effects:
full passkey login (UV in-ceremony, server verification pending) or dismissal → user continues
by typing the identifier (AF may then offer a fill, → B). One credential can produce several
sheet appearances per session (→ S8).

### S3 — Button-triggered passkey login, identifier known (native2 pattern)
Post-identifier / password screen, "Sign in with passkey" button. Platform assertion (plus
security key when server-sent transports say so), server-side `allowCredentials`, no options.
UI: sheet always — with zero local credentials it still appears as "Choose how you'd like to
sign in" with hybrid/QR (→ S7). Effects: passkey login or typed failure: 1001 cancel, 1004
domain/generic failure, plus non-AS error domains at the same delegate (classify by
domain+code, never code alone).

### S4 — Button-triggered usernameless passkey login
Welcome screen, "Sign in with a passkey" button. Discoverable credentials, no allowList, no
options. Same UI/effects as S3 plus an account chooser among multiple discoverable passkeys.

### S5 — Mixed sheet: passkey + password (+ Sign in with Apple) in one request
The WWDC22 launch pattern: several providers in one controller, exactly one credential comes
back. UI: account chooser — passkeys first, passwords behind "Other Sign-in Options"; whether
passkey and password of the *same* account both show `[verify]`. Effects: passkey login,
`ASPasswordCredential` (username+password handed to app code — submit or prefill is
app-defined), or an Apple ID token → full login. On iOS 26 a passkey request can also end in
1009 `preferSignInWithApple`. native2 never mixes password or Apple ID requests in.

### S6 — Password-only AS request
`ASAuthorizationPasswordProvider` alone: the only app-triggerable saved-password retrieval
(AF has no API). UI: password chooser sheet + Face ID; no match → 1001. Effects:
`ASPasswordCredential`, app submits. Catalog entry only, no screen (group B stub): no known
customer usage; maps onto the system-credential operation as a password result.

### S7 — Hybrid / cross-device QR ceremony
Inside any passkey sheet (S2–S5): "use a passkey from another device" → QR/BLE ceremony.
Same delegate, much longer duration, distinct outcome semantics (device transfer, not local).
Suppressed only by `.preferImmediatelyAvailableCredentials`.

### S8 — Re-trigger after cancel
User dismissed an auto sheet (S2), then taps a button that fires a new request (S3/S4) —
user actor this time. Hazard: one in-flight request per app — an immediate retry, especially
with a pending assisted request (→ C), fails with "already in progress"; the surfaced error
code `[verify]`; `cancel()` on the old controller or a ~1s delay are the known workarounds.
No documented dampening after repeated cancels `[verify]`.

### S9 — Modal passkey registration
`createCredentialRegistrationRequest` on the platform provider. Variants: post-login upsell
(auto or button), settings-manual, signup-hosted. UI: creation sheet + Face ID; iOS 26 ends
with 1010 when the device has no passcode. Effects: passkey-enrollment outcome; an exclude
match surfaces as 1006 (18+) or 1004 (pre-18, native2 string-matches the message). Changes
what S1/S2 offer next time — experiment sequencing matters. native2 has both the upsell and
the settings variant.

### S10 — Third-party provider ceremony
iOS 17+ with a passkey-provider extension active: the sheet aggregates provider entries and a
selection routes through the provider's own unlock UI before the result arrives. App-side the
delegate is identical; the latency tail differs `[verify]`.

### Stub — security-key ceremony
`ASAuthorizationSecurityKeyPublicKeyCredentialProvider` in the mix: insert/tap prompts, silent
probe disabled. native2 requests it whenever server-sent transports include it. Catalog shape
only; no screen until a customer needs it.

## B. AF during login

AF is the opposite of AS: the system triggers it (field focus, given a saved password and — for
chips — an associated domain) and app code gets no first-class event for anything. What the app
can see is the **fill signature**: one bulk text insertion per filled view, forced
first-responder churn, and for password fills the Face ID lifecycle blip
(`willResignActive` → `didBecomeActive`). Situations differ by what that signature looks like,
not by an API.

### S11 — Two-field password fill on a combined form
Focus on either field of an identifier+password form → QuickType chip → Face ID → both fields
populate in one pass (system force-moves first responder onto each). Signature: blip + two
bulk changes + responder churn without taps; same-runloop ordering `[verify]`. Effects: fill
only, user submits — Apple discourages auto-submit on fill detection.

### S12 — Password fill, identifier known (native2 pattern)
Post-identifier password screen. Chip fills the password only. Two-step flows need a hidden
`.username` field on the screen so the system can pair the credential (native2 keeps a 1px
one). Effects: fill, user submits — native2 auto-submits 0.1s after a >1-char bulk insert.

### S13 — Identifier-only fill on a lone identifier field
Welcome / identifier screen with a `.username` field. Chip fills the identifier; user continues
manually. Whether the Face ID blip fires when no password is filled `[verify]`.

### S14 — Out-of-band credential harvest (native2 pattern)
A hidden `.password` field on the welcome screen receives the password half of a chip pick
made on the identifier field; the app carries it forward, skips the password screen and
submits. The credential arrives **before its screen exists** — the tracking model must be able
to express that.

### S15 — Manual key-icon picker
Key icon in the QuickType bar any time the keyboard is up: full picker over all device
credentials, cross-domain. Explicitly user-initiated, typically after ignoring the chip; the
only fill path without an associated domain. Same signature as S11–S13.

### S16 — Post-modal-dismissal AF takeover
User dismissed the auto sheet (S2), then focuses the form → the *same credential* is offered
again as a chip through a different surface. One credential, two journeys, identical final
submission. Key attribution challenge, as on Android.

### S17 — Third-party provider chip
Provider extension active (17+): chip rendered from provider metadata; tap → provider's own
unlock UI → same system fill. Identical app-side signature, different latency; slotting with
up to three providers `[verify]`.

### S18 — OTP autofill (stub)
`.oneTimeCode` field: SMS code offered as a chip for ~3 min, pushed live into the bar if
focused, no Face ID gate `[verify]`. The system inserts the whole code; segmented inputs
redistribute it in `shouldChangeCharactersIn` — arrives with an empty `replacementString` on
iOS 26. Interaction evidence for the sms-otp subflow only. Catalog entry, stub screen.

### S19 — Manual paste from a password-manager app
User copies the password in a manager app and pastes: bulk change with **no** blip and no
responder churn. Together with dictation and CJK marked-text commits this is the main false
positive of bulk-change heuristics; `paste:` is the only one app code can tell apart.

### S20 — WKWebView form fill
Login forms in web content participate in AF like native fields (chip, Face ID, fill). native2
has web surfaces; the JS SDK may run there → double coverage to avoid.

## C. Conditional UI and automatic upgrades

Same controller as A with one different call (`performAutoFillAssistedRequests`), so the SDK
sees armed → (silence | success | error) and never chip display. Two rules generate the
situations: one in-flight request per app, and the CUI passkey chip coexists with independent
AF password chips on the same field. native2 uses neither CUI nor upgrades.

### S21 — Armed CUI, passkey chip picked
Arm before the `.username` field gets focus; chip → Face ID → `didCompleteWithAuthorization`,
same as modal. A login without any button. Platform assertion only, challenge minted without a
username.

### S22 — Armed CUI, silence
User types instead, focus leaves, keyboard is dismissed, app is backgrounded: no callback at
all — which of these stay silent `[verify]`. The request stays armed indefinitely; challenge
staleness is real with no documented TTL `[verify]`.

### S23 — Armed CUI → modal handover
User taps a passkey button while a request is armed. `cancel()` first (delegate gets 1001),
else the modal fails "already in progress" (S8). The 1001 from `cancel()` must not read as a
user dismissal — same shape as the web `cui-*` guidance.

### S24 — CUI chip next to AF password chip
Same account, passkey chip from the armed request, password chip from AF. A password pick
fills the fields and leaves the CUI request running. Ordering/dedup of the two chips
`[verify]` — iOS has no Android-style "safest method" rule.

### S25 — Arming variants
Arm after focus, `.password` focus, populated `allowCredentials`, re-arm after completion or
cancel `[verify each]`. Chips were absent on 16.1–16.2: absence of chip is not absence of
passkey.

### S26 — Automatic passkey upgrade after a manager-filled password
`requestStyle: .conditional` on registration right after a password login whose password the
same credential manager just filled (S11/S12). Zero UI either way: credential, or one generic
"not this time" error indistinguishable from a plumbing bug `[verify userInfo]`. Modeling
deferred (step on password-login vs. immediate enrollment subflow — both additive).

### S27 — Automatic upgrade after a typed password
Same call after a typed or pasted password: always the generic error. Apple's guidance is to
attempt on every password sign-in, so this is the denominator of the upgrade rate.

## D. Persistence and lifecycle edges

Catalog-only: no screens. They shape experiment hygiene and error attribution rather than the
tracking model.

### S28 — Save / update prompt after submit
System prompt when credential fields leave the view hierarchy after new text; associated-domain
gated; save vs update decided by username existence. Not observable app-side, and it changes
the credential population for every later run — reset credentials between experiments. native2
wipes field text to suppress it.

### S29 — Strong-password suggestion on signup
`.newPassword` (+ domain) → pregenerated password; acceptance **auto-saves with no prompt**.
Enrollment evidence inside signup. native2 tags new-password fields as `.password`, disabling it.

### S30 — Prewarmed launch
The process may exist long before any UI (prewarming); protected data can be unavailable.
Affects when the tracker initializes and what anchors a session, not what it observes.

### S31 — Magic-link return via universal link
`applinks` share the AASA CDN and cached-failure mechanics with `webcredentials`: a failed
association opens the link in Safari and the flow finishes outside the app. Stitching stays a
backend concern.

### S32 — Biometry states
Face ID lockout, biometry disabled for the app, passcode-less device (registration → 1010 on
iOS 26). Error attribution inputs, not screens.

## E. Cross-cutting variants (multiply the above)

- **Credential population**: none / password-only / passkey-only / both (same account) /
  multiple accounts / credential in a locked third-party vault.
- **OS**: 16 (passkeys GA, no CUI chips on 16.1–16.2), 17 (third-party providers), 18
  (1006, upgrades, 3 providers), 26 (1009/1010, delegate regressions, account creation).
- **Provider config**: iCloud Keychain only / one third-party provider / three providers /
  AutoFill disabled by MDM.
- **Device**: iPhone (reference) / iPad (hardware keyboard, ambient active-state churn,
  multiple scenes) / simulator (simulated Face ID, CDN-served AASA only).

---

## Screen mapping (example app)

A situation is recorded only if it carries a `[verify]` or is a native2 reference flow;
the rest share a signal path with a recorded one.

| Screen (devbar) | Situations | Toggle | Records |
|---|---|---|---|
| `welcome-auto-probe` | S1, S2, S8, S14, S16 | hidden harvest field | population none / one / many; retry after cancel; single-credential collapse |
| `passkey-button` | S3, S4, S7 | identifier known / usernameless | native2 reference; zero-local hybrid sheet |
| `login-form` | S11, S12, S13, S15, S17, S19 | two-field / password-only / identifier-only | fill signature per shape; identifier-only blip; paste vs fill |
| `cui-identifier` | S21–S25 | arm before / after focus | silence cases; handover cancel; chip coexistence |
| `enroll-passkey` | S9 (later S26, S27) | upsell / settings | native2 reference; exclude match |
| — (stubs) | S5, S6, S10, S18, S20, security key | | none |

S15, S17 and S19 are tester actions on `login-form`. S10 and S17 need a third-party provider
installed on the test device (opt-in). S26/S27 wait for the deferred modeling decision.
