import SwiftUI
import Testing
@testable import MinchUI

@Suite("MinchSidebarRow selection")
struct MinchSidebarRowSelectionTests {
    @Test func iconUsesSecondaryWhenUnselected() {
        #expect(MinchSidebarRow.iconColor(isSelected: false) == Color.minchSidebarIconUnselected)
    }

    @Test func iconUsesCurrentWhenSelected() {
        #expect(MinchSidebarRow.iconColor(isSelected: true) == Color.minchCurrent)
    }

    @Test func barOpacityIsZeroWhenUnselected() {
        #expect(MinchSidebarRow.barOpacity(isSelected: false) == 0)
    }

    @Test func barOpacityIsOneWhenSelected() {
        #expect(MinchSidebarRow.barOpacity(isSelected: true) == 1)
    }
}
