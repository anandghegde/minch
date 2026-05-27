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


@Suite("MinchTransferRow.actionEnablement")
struct ActionEnablementTests {
    @Test func idlePhaseOnlyDeleteIsLive() {
        let a = MinchTransferRow.actionEnablement(phase: .idle, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: false, delete: true))
    }

    @Test func queuedPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .queued, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func activePhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .active, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func pausedPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .paused, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func errorPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .error, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func donePhaseWithoutMediaDimsPlay() {
        let a = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: true, copyLink: true, delete: true))
    }

    @Test func donePhaseWithMediaEnablesPlay() {
        let a = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: true)
        #expect(a == .init(play: true, reveal: true, copyLink: true, delete: true))
    }

    @Test func mediaFlagIsIgnoredOutsideDone() {
        let a = MinchTransferRow.actionEnablement(phase: .active, hasPlayableMedia: true)
        #expect(a.play == false)
    }
}
