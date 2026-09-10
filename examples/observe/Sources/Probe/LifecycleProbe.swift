import UIKit

/// Application active-state churn. The Face ID gate of a password AutoFill is a
/// `willResignActive` → `didBecomeActive` blip right before the fill; field probes stamp their
/// lines with the time since the last `didBecomeActive` so the pairing is visible in a capture.
@MainActor
final class LifecycleProbe {
    static let shared = LifecycleProbe()

    private(set) var lastResignAt: Date?
    private(set) var lastBecomeActiveAt: Date?

    func install() {
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(resign), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(active), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(
            self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    /// Milliseconds since the last `didBecomeActive`, when one happened.
    var msSinceBecomeActive: Int? {
        lastBecomeActiveAt.map { Int(Date().timeIntervalSince($0) * 1000) }
    }

    @objc private func resign() {
        lastResignAt = Date()
        Probe.log("app_state", ["state": "willResignActive"])
    }

    @objc private func active() {
        lastBecomeActiveAt = Date()
        let blipMs = lastResignAt.map { Int(Date().timeIntervalSince($0) * 1000) }
        Probe.log("app_state", ["state": "didBecomeActive", "blipMs": blipMs])
    }

    @objc private func background() {
        Probe.log("app_state", ["state": "didEnterBackground"])
    }

    @objc private func foreground() {
        Probe.log("app_state", ["state": "willEnterForeground"])
    }
}
