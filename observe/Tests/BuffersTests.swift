import Testing

@testable import CorbadoObserve

@Suite struct BuffersTests {
    @Test func telemetryDeduplicatesPerProcess() {
        let buffer = TelemetryBuffer(enabled: { true }, currentSessionId: { "s" })
        buffer.report("error", "same message")
        buffer.report("error", "same message")
        buffer.report("info", "same message")  // different level: kept
        #expect(buffer.peek().count == 2)
    }

    @Test func telemetryHonorsCapAndKillSwitch() {
        let enabled = Locked(true)
        let buffer = TelemetryBuffer(enabled: { enabled.value }, currentSessionId: { "s" })
        for index in 0..<150 {
            buffer.report("info", "message \(index)")
        }
        #expect(buffer.peek().count == 50)  // per-batch cap

        enabled.value = false
        buffer.report("info", "dropped")
        buffer.removeDelivered(buffer.peek())
        #expect(!buffer.peek().map(\.message).contains("dropped"))
    }

    @Test func telemetryRemoveDeliveredKeepsRest() {
        let buffer = TelemetryBuffer(enabled: { true }, currentSessionId: { "s" })
        buffer.report("info", "one")
        buffer.report("info", "two")
        let delivered = [buffer.peek()[0]]
        buffer.removeDelivered(delivered)
        #expect(buffer.peek().map(\.message) == ["two"])
    }

    @Test func lowBufferCapsAndRemoves() {
        let buffer = LowBuffer(enabled: { true }, currentSessionId: { "s" })
        for index in 0..<250 {
            buffer.report(WireLowEvent(lowType: "input", ts: Int64(index)))
        }
        let peeked = buffer.peek()
        #expect(peeked.count == 100)  // per-batch cap

        buffer.removeDelivered(peeked)
        #expect(buffer.peek().count == 100)  // 200 buffered cap minus 100 delivered
    }

    @Test func lowBufferKillSwitchDropsAtSource() {
        let buffer = LowBuffer(enabled: { false }, currentSessionId: { "s" })
        buffer.report(WireLowEvent(lowType: "input", ts: 1))
        #expect(!buffer.isNotEmpty)
    }
}
