import Testing

@testable import TransferKit

@Suite
struct TransferPolicyTests {
    @Test func clampsThreads() {
        #expect(TransferPolicy.clampThreads(0) == 1)
        #expect(TransferPolicy.clampThreads(16) == 16)
        #expect(TransferPolicy.clampThreads(1_000) == TransferPolicy.maxThreads)
    }

    @Test func plansSingleVsRanged() {
        #expect(TransferPolicy.plan(sizeBytes: 1_000) == .init(mode: .single, parts: 1))
        #expect(
            TransferPolicy.plan(sizeBytes: TransferPolicy.rangeThreshold)
                == .init(mode: .ranged, parts: TransferPolicy.rangeParts)
        )
    }

    @Test func splitsRanges() {
        #expect(
            TransferPolicy.ranges(total: 1_000, count: 4)
                == [0..<250, 250..<500, 500..<750, 750..<1_000]
        )
        #expect(TransferPolicy.ranges(total: 10, count: 4) == [0..<2, 2..<4, 4..<6, 6..<10])
        #expect(TransferPolicy.ranges(total: 0, count: 4).isEmpty)
    }
}
