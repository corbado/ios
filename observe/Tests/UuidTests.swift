import Foundation
import Testing

@testable import CorbadoObserve

@Suite struct UuidTests {
    @Test func formatAndBits() {
        let id = Uuid.v7()
        #expect(id.count == 36)
        let parts = id.split(separator: "-")
        #expect(parts.map(\.count) == [8, 4, 4, 4, 12])
        #expect(parts[2].first == "7")  // version 7
        #expect("89ab".contains(parts[3].first!))  // RFC 4122 variant
    }

    @Test func timestampPrefixOrders() {
        let earlier = Uuid.v7(now: 1_000_000)
        let later = Uuid.v7(now: 2_000_000)
        #expect(String(earlier.prefix(13)) < String(later.prefix(13)))
    }

    @Test func uniqueness() {
        let ids = Set((0..<1000).map { _ in Uuid.v7() })
        #expect(ids.count == 1000)
    }
}
