import Testing

@testable import TransferKit

@Suite
struct TransferProgressTests {
    @Test func fractionForDefiniteTotals() {
        let bytes = TransferProgress(kind: .bytes, total: 200, current: 50)
        #expect(bytes.fraction == 0.25)

        let count = TransferProgress(kind: .count, total: 4, current: 1)
        #expect(count.fraction == 0.25)
    }

    @Test func fractionIsNilWhenIndefinite() {
        let empty = TransferProgress(kind: .bytes, total: nil, current: 1024)
        #expect(empty.fraction == nil)

        let zero = TransferProgress(kind: .count, total: 0, current: 0)
        #expect(zero.fraction == nil)
    }

    @Test func kindIsDistinguished() {
        #expect(TransferProgress(kind: .count, total: 1, current: 1).kind == .count)
        #expect(TransferProgress(kind: .bytes, total: 1, current: 1).kind == .bytes)
    }
}
