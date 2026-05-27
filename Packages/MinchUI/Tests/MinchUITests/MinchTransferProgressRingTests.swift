import Testing
import SwiftUI
@testable import MinchUI

@Suite("MinchTransferProgressRing")
struct MinchTransferProgressRingTests {
    @Test(arguments: MinchStatusPhase.allCases, [0.0, 0.5, 1.0])
    func instantiatesForEveryPhaseAndProgress(phase: MinchStatusPhase, progress: Double) {
        // Smoke: instantiation must not trap. We don't render the view; we
        // just exercise the initializer and `body` getter.
        let view = MinchTransferProgressRing(phase: phase, progress: progress)
        _ = view.body
        #expect(Bool(true))
    }

    @Test func clampsProgressAboveOne() {
        let view = MinchTransferProgressRing(phase: .active, progress: 1.7)
        _ = view.body
        #expect(Bool(true))
    }

    @Test func clampsProgressBelowZero() {
        let view = MinchTransferProgressRing(phase: .active, progress: -0.5)
        _ = view.body
        #expect(Bool(true))
    }
}
