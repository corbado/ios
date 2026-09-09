import Testing

@testable import CorbadoObserve

@Suite struct SdkConfigTests {
    @Test func defaultsAreConservative() {
        let config = SdkConfig.default
        #expect(config.flushIntervalMs == 2_000)
        #expect(config.sessionInactivityMs == 30 * 60 * 1_000)
        #expect(config.telemetry)
        #expect(!config.flushOnTelemetry)
        #expect(config.flushOnBackground)
        #expect(config.lows)
        #expect(config.retryMaxAttempts == 1)
    }

    @Test func parsesFullConfig() throws {
        let config = try #require(
            SdkConfig.parse(
                """
                {"version":"v3","flushIntervalMs":5000,"sessionInactivityMs":600000,
                 "telemetry":false,"flushOnTelemetry":true,"flushOnFlowTypeFinished":["login"],
                 "flushOnBackground":false,"lows":false,
                 "retry":{"maxAttempts":3,"baseDelayMs":500,"maxDelayMs":10000}}
                """))
        #expect(config.version == "v3")
        #expect(config.flushIntervalMs == 5_000)
        #expect(config.sessionInactivityMs == 600_000)
        #expect(!config.telemetry)
        #expect(config.flushOnTelemetry)
        #expect(config.flushOnFlowTypeFinished == ["login"])
        #expect(!config.flushOnBackground)
        #expect(!config.lows)
        #expect(config.retryMaxAttempts == 3)
        #expect(config.retryBaseDelayMs == 500)
        #expect(config.retryMaxDelayMs == 10_000)
    }

    @Test func clampsHostileValues() throws {
        let config = try #require(
            SdkConfig.parse(
                #"{"flushIntervalMs":1,"sessionInactivityMs":1,"retry":{"maxAttempts":99,"baseDelayMs":-5}}"#))
        #expect(config.flushIntervalMs == 200)
        #expect(config.sessionInactivityMs == 60_000)
        #expect(config.retryMaxAttempts == 10)
        #expect(config.retryBaseDelayMs == 0)
    }

    @Test func unknownFieldsAndMissingFieldsKeepDefaults() throws {
        let config = try #require(SdkConfig.parse(#"{"someFutureField":{"a":1}}"#))
        #expect(config.flushIntervalMs == SdkConfig.default.flushIntervalMs)
        #expect(config.telemetry == SdkConfig.default.telemetry)
    }

    @Test func malformedBodyReturnsNil() {
        #expect(SdkConfig.parse("not json") == nil)
        #expect(SdkConfig.parse("[1,2,3]") == nil)
        #expect(SdkConfig.parse("") == nil)
    }
    @Test(arguments: ["1e100", "9223372036854775808", "1.7976931348623157e308", "-1e100"])
    func outOfRangeJsonNumbersClampWithoutTrapping(value: String) throws {
        let config = try #require(
            SdkConfig.parse("{\"sessionInactivityMs\":\(value),\"retry\":{\"maxAttempts\":\(value)}}"))
        #expect(config.sessionInactivityMs == (value.hasPrefix("-") ? 60_000 : 86_400_000))
        #expect(config.retryMaxAttempts == (value.hasPrefix("-") ? 1 : 10))
    }

}
