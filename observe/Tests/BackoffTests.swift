import Testing

@testable import CorbadoObserve

@Suite struct BackoffTests {
    private var cfg: SdkConfig {
        var config = SdkConfig.default
        config.retryBaseDelayMs = 500
        config.retryMaxDelayMs = 10_000
        return config
    }

    @Test func doublesPerAttemptAndCapsAtMax() {
        #expect(backoffFor(attempt: 1, cfg: cfg) == 500)
        #expect(backoffFor(attempt: 2, cfg: cfg) == 1_000)
        #expect(backoffFor(attempt: 3, cfg: cfg) == 2_000)
        #expect(backoffFor(attempt: 6, cfg: cfg) == 10_000)
    }

    @Test func hostileAttemptValuesStayClamped() {
        #expect(backoffFor(attempt: 0, cfg: cfg) == 500)
        #expect(backoffFor(attempt: -5, cfg: cfg) == 500)
        #expect(backoffFor(attempt: 1_000, cfg: cfg) == 10_000)
    }

    @Test func zeroConfigYieldsZeroDelay() {
        #expect(backoffFor(attempt: 3, cfg: SdkConfig.default) == 0)
    }
}
