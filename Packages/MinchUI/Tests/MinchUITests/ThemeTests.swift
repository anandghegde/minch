import Testing
import SwiftUI
@testable import MinchUI

@Suite("Theme tokens")
struct ThemeTests {
    @Test func spacingScaleIsMonotonic() {
        #expect(MinchSpacing.xs < MinchSpacing.s)
        #expect(MinchSpacing.s < MinchSpacing.m)
        #expect(MinchSpacing.m < MinchSpacing.l)
        #expect(MinchSpacing.l < MinchSpacing.xl)
        #expect(MinchSpacing.xl < MinchSpacing.xxl)
    }

    @Test func radiusScaleIsMonotonic() {
        #expect(MinchRadius.s < MinchRadius.m)
        #expect(MinchRadius.m < MinchRadius.l)
    }

    @Test func surfaceTokensExist() {
        _ = Color.minchSurfacePrimary
        _ = Color.minchSurfaceElevated
        _ = Color.minchSurfaceSunken
        _ = Color.minchHairline
        _ = Color.minchSelection
    }
}
