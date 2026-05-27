import SwiftUI
import Testing
@testable import MinchUI

@Suite("MinchSidebarFooter")
struct MinchSidebarFooterTests {
    @Test func iconRestingColorIsMutedSidebarTint() {
        #expect(MinchSidebarFooter.iconColor(isHovered: false) == Color.minchSidebarIconUnselected)
    }

    @Test func iconHoverColorIsCurrent() {
        #expect(MinchSidebarFooter.iconColor(isHovered: true) == Color.minchCurrent)
    }

    @Test func settingsClosureFiresWhenInvoked() {
        var settingsFired = 0
        let footer = MinchSidebarFooter(
            onOpenSettings: { settingsFired += 1 },
            onAdd: {}
        )
        footer.onOpenSettings()
        #expect(settingsFired == 1)
    }

    @Test func addClosureFiresWhenInvoked() {
        var addFired = 0
        let footer = MinchSidebarFooter(
            onOpenSettings: {},
            onAdd: { addFired += 1 }
        )
        footer.onAdd()
        #expect(addFired == 1)
    }
}
