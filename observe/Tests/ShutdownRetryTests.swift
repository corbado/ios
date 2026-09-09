import Foundation
import Testing

@testable import CorbadoObserve

private final class ShutdownTransport: Transporting {
    struct Attempt {
        let batch: WireEventBatch
        let time: UInt64
    }
    let attempts = Locked<[Attempt]>([])
    let lifecycle = Locked<[String]>([])

    func shutdown() { lifecycle.withLock { $0.append("shutdown") } }
    private let failures: Int

    init(failures: Int) { self.failures = failures }

    func send(_ batch: WireEventBatch, configVersionHeader: String?) async -> TransportResult {
        lifecycle.withLock { $0.append("send") }
        let count = attempts.withLock {
            $0.append(Attempt(batch: batch, time: DispatchTime.now().uptimeNanoseconds))
            return $0.count
        }
        return TransportResult(statusCode: count <= failures ? 503 : 204)
    }
}

extension TrackerIntegrationTests {
    @Test(arguments: [1, 5], [false, true])
    func shutdownUsesNormalRetryChain(failures: Int, alreadyBackingOff: Bool) async {
        ObservePrefs().sdkConfigJson = """
            {"flushIntervalMs":60000,"retry":{"maxAttempts":3,"baseDelayMs":200,"maxDelayMs":400}}
            """
        let transport = ShutdownTransport(failures: failures)
        let tracker = ObserveTracker(
            options: ObserveOptions(projectId: "pro-test", apiBaseUrl: "https://example.invalid"),
            transport: transport)
        tracker.start()
        tracker.trackCustom("must_survive_shutdown")
        if alreadyBackingOff {
            tracker.flush()
            for _ in 0..<200 {
                if !transport.attempts.value.isEmpty { break }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            #expect(transport.attempts.value.count == 1)
        }
        tracker.destroy()
        await tracker.awaitTermination()

        let attempts = transport.attempts.value
        #expect(attempts.count == min(failures + 1, 3))
        #expect(transport.lifecycle.value == Array(repeating: "send", count: attempts.count) + ["shutdown"])
        #expect(Set(attempts.flatMap { $0.batch.events.map(\.id) }).count == 1)
        #expect(attempts.map { $0.batch.meta?.retryCount ?? 0 } == Array(0..<attempts.count))
        #expect(attempts.first?.batch.meta?.flushReason == (alreadyBackingOff ? "manual" : "destroy"))
        #expect(attempts.dropFirst().allSatisfy { $0.batch.meta?.flushReason == "backoff" })
        for index in 1..<attempts.count {
            let elapsed = attempts[index].time - attempts[index - 1].time
            #expect(elapsed >= UInt64(index == 1 ? 200_000_000 : 400_000_000))
        }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("corbado_observe", isDirectory: true)
        let remaining = Outbox(directory: { directory }, logger: ObserveLogger(debug: false)).readAll()
        #expect(remaining.count == (failures >= 3 ? 1 : 0))
        // Completion includes the retry chain: no timer may send an extra attempt afterward.
        try? await Task.sleep(nanoseconds: 250_000_000)
        #expect(transport.attempts.value.count == attempts.count)
        #expect(transport.lifecycle.value.last == "shutdown")
    }

    @Test func replacementWaitsForPriorShutdownBeforeOpeningOutbox() async {
        ObservePrefs().sdkConfigJson = """
            {"flushIntervalMs":60000,"retry":{"maxAttempts":3,"baseDelayMs":200,"maxDelayMs":400}}
            """
        let options = ObserveOptions(projectId: "pro-test", apiBaseUrl: "https://example.invalid")
        let oldTransport = ShutdownTransport(failures: 1)
        let previous = ObserveTracker(options: options, transport: oldTransport)
        previous.start()
        previous.trackCustom("previous")
        previous.flush()
        for _ in 0..<200 {
            if !oldTransport.attempts.value.isEmpty { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        previous.destroy()
        let shutdown = Task { await previous.awaitTermination() }
        let newTransport = CapturingTransport()
        let replacement = ObserveTracker(options: options, transport: newTransport)
        replacement.start(after: shutdown)
        replacement.trackCustom("replacement")
        replacement.destroy()
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(newTransport.events.isEmpty)
        await replacement.awaitTermination()
        #expect(oldTransport.attempts.value.count == 2)
        #expect(newTransport.events.map(\.name) == ["replacement"])
    }
}
