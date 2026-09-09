import AuthenticationServices
import CorbadoObserve

/// Shared tail of every passkey-login ceremony: backend resolution of the assertion, the
/// post-response step, flow finish. Returns the resolved identifier, nil on rejection.
@MainActor
enum PasskeyFlows {
    @discardableResult
    static func completeLogin(
        assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion,
        postResponse: StepHandle?,
        context: ScreenContext
    ) -> String? {
        postResponse?.start()
        guard let identifier = context.webAuthn.passkeyLogin(assertion) else {
            // The assertion did not verify server-side (credential unknown to the backend).
            postResponse?.error(BackendError(message: "assertion rejected"))
            return nil
        }
        let user = UserReference(userId: context.backend.userIdFor(identifier), identifier: identifier)
        postResponse?.finished(options: StepOptions(userReference: user))
        context.tracker?.flowFinished("login", options: StepOptions(userReference: user))
        Probe.log("login_success", ["identifierLength": identifier.count, "how": "passkey"])
        context.loginSuccess(identifier)
        return identifier
    }
}
