import Testing
@testable import MinchUI

@Suite("MinchStatusPhase")
struct StatusGlyphTests {
    @Test func mapsKnownTransferStatusStrings() {
        #expect(MinchStatusPhase(transferStatusRaw: "queued") == .queued)
        #expect(MinchStatusPhase(transferStatusRaw: "downloading") == .active)
        #expect(MinchStatusPhase(transferStatusRaw: "seeding") == .active)
        #expect(MinchStatusPhase(transferStatusRaw: "paused") == .paused)
        #expect(MinchStatusPhase(transferStatusRaw: "error") == .error)
        #expect(MinchStatusPhase(transferStatusRaw: "done") == .done)
    }

    @Test func mapsUnknownToIdle() {
        #expect(MinchStatusPhase(transferStatusRaw: "") == .idle)
        #expect(MinchStatusPhase(transferStatusRaw: "wat") == .idle)
    }

    @Test func everyPhaseHasNonEmptyLabel() {
        for phase in MinchStatusPhase.allCases {
            #expect(!phase.label.isEmpty)
        }
    }
}
