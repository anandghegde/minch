import Testing
@testable import MinchUI

@Suite("MinchTransferRow formatting")
struct TransferRowFormattingTests {
    @Test func clampsProgressBelowZero() {
        #expect(MinchTransferRow.clampedProgress(-0.5) == 0)
    }

    @Test func clampsProgressAboveOne() {
        #expect(MinchTransferRow.clampedProgress(1.7) == 1)
    }

    @Test func passesProgressInRangeThrough() {
        #expect(MinchTransferRow.clampedProgress(0.42) == 0.42)
    }

    @Test func percentTextRoundsToZeroDecimals() {
        #expect(MinchTransferRow.percentText(0.621) == "62%")
        #expect(MinchTransferRow.percentText(0) == "0%")
        #expect(MinchTransferRow.percentText(1) == "100%")
    }

    @Test func speedTextHidesZeroAndNegative() {
        #expect(MinchTransferRow.speedText(0) == nil)
        #expect(MinchTransferRow.speedText(-1) == nil)
    }

    @Test func speedTextSuffixesPerSecond() {
        let s = MinchTransferRow.speedText(1_500_000)
        #expect(s != nil)
        #expect(s!.hasSuffix("/s"))
    }
}
