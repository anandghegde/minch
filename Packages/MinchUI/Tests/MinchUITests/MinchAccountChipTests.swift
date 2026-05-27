import SwiftUI
import Testing
@testable import MinchUI

@Suite("MinchAccountChip")
struct MinchAccountChipTests {
    @Test func statusDotIsGreenWhenSubscribed() {
        #expect(MinchAccountChip.statusDotColor(isSubscribed: true) == Color.minchSuccess)
    }

    @Test func statusDotIsAmberWhenInactive() {
        #expect(MinchAccountChip.statusDotColor(isSubscribed: false) == Color.minchWarning)
    }

    @Test func initialUppercasesFirstCharacterOfName() {
        #expect(MinchAccountChip.initial(name: "anand") == "A")
        #expect(MinchAccountChip.initial(name: "Zoë") == "Z")
    }

    @Test func initialFallsBackToQuestionMarkWhenEmpty() {
        #expect(MinchAccountChip.initial(name: "") == "?")
    }

    @Test func initialFallsBackToQuestionMarkOnWhitespace() {
        #expect(MinchAccountChip.initial(name: "   ") == "?")
    }
}
