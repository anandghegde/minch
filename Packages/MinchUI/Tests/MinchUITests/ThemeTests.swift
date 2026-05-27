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

    @Test func surfaceRampTokensExist() {
        _ = Color.minchSurfaceWindow
        _ = Color.minchSurfaceSidebar
        _ = Color.minchSurfacePrimary
        _ = Color.minchSurfaceCard
        _ = Color.minchSurfaceCardHover
        _ = Color.minchSurfaceOverlay
        _ = Color.minchSurfaceSunken
        _ = Color.minchHairline
        _ = Color.minchSelection
    }

    @Test func typographyTokensExist() {
        _ = Font.minchDisplay
        _ = Font.minchTitle
        _ = Font.minchHeadline
        _ = Font.minchBody
        _ = Font.minchMetadata
        _ = Font.minchCallout
        _ = Font.minchCaption
        _ = Font.minchMono
    }

    @Test func motionTokensCompile() {
        _ = MinchMotion.snap
        _ = MinchMotion.smooth
    }

    @Test func elevationHoverIsStrongerThanResting() {
        #expect(MinchElevation.hover.shadowRadius > MinchElevation.resting.shadowRadius)
        #expect(MinchElevation.hover.borderWidth >= MinchElevation.resting.borderWidth)
    }
}
