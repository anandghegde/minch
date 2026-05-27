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
    @Test func idleDisablesPlayAndReveal() {
        let e = MinchTransferRow.actionEnablement(phase: .idle, hasPlayableMedia: true)
        #expect(e.play == false)
        #expect(e.reveal == false)
        #expect(e.copyLink == true)
        #expect(e.delete == true)
    }

    @Test func queuedDisablesPlayAndReveal() {
        let e = MinchTransferRow.actionEnablement(phase: .queued, hasPlayableMedia: true)
        #expect(e.play == false)
        #expect(e.reveal == false)
    }

    @Test func activeDisablesPlayAndReveal() {
        let e = MinchTransferRow.actionEnablement(phase: .active, hasPlayableMedia: true)
        #expect(e.play == false)
        #expect(e.reveal == false)
    }

    @Test func pausedDisablesPlayAndReveal() {
        let e = MinchTransferRow.actionEnablement(phase: .paused, hasPlayableMedia: true)
        #expect(e.play == false)
        #expect(e.reveal == false)
    }

    @Test func errorDisablesPlayAndReveal() {
        let e = MinchTransferRow.actionEnablement(phase: .error, hasPlayableMedia: true)
        #expect(e.play == false)
        #expect(e.reveal == false)
    }

    @Test func doneEnablesRevealAlways() {
        let e = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: false)
        #expect(e.reveal == true)
        #expect(e.play == false)
    }

    @Test func doneWithPlayableMediaEnablesPlay() {
        let e = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: true)
        #expect(e.play == true)
        #expect(e.reveal == true)
    }

    @Test func deleteAndCopyLinkAlwaysEnabled() {
        for phase in [MinchStatusPhase.idle, .queued, .active, .paused, .error, .done] {
            let e = MinchTransferRow.actionEnablement(phase: phase, hasPlayableMedia: false)
            #expect(e.delete == true, "delete must be enabled for \(phase)")
            #expect(e.copyLink == true, "copyLink must be enabled for \(phase)")
        }
    }
}
