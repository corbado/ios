import Testing

@testable import CorbadoObserve

@Suite struct SdkTests {
    @Test func identity() {
        #expect(Sdk.name == "observe-ios")
        #expect(!Sdk.version.isEmpty)
    }
}
