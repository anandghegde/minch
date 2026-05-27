import Testing
@testable import MinchUI

@Suite("MinchTransferRow.etaText")
struct EtaTextTests {
    @Test func zeroSecondsIsOmitted() {
        #expect(MinchTransferRow.etaText(0) == nil)
    }

    @Test func negativeSecondsIsOmitted() {
        #expect(MinchTransferRow.etaText(-30) == nil)
    }

    @Test func subMinuteShowsLessThanOne() {
        #expect(MinchTransferRow.etaText(45) == "<1m left")
    }

    @Test func minutesFloor() {
        #expect(MinchTransferRow.etaText(195) == "3m left")
    }

    @Test func exactlyOneMinute() {
        #expect(MinchTransferRow.etaText(60) == "1m left")
    }

    @Test func hoursAndMinutes() {
        #expect(MinchTransferRow.etaText(4500) == "1h 15m left")
    }

    @Test func exactHourDropsMinuteSegment() {
        #expect(MinchTransferRow.etaText(7200) == "2h left")
    }
}
