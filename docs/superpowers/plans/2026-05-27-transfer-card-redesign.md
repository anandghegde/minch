# Transfer Card Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the transfer row visible personality through typography (separator-dimmed monospace name), a phase-aware progress ring around the existing status dot, and an always-visible 4-icon action cluster — no artwork, no hover lift.

**Architecture:** Build the new visual surface in `MinchTransferRow` by composing a new `MinchTransferProgressRing` view (wraps the existing 8pt `MinchStatusGlyph` verbatim) and an action HStack of 4 plain-style buttons. Replace the outer `Button(onToggle)` wrapper with a `Rectangle` background + `onTapGesture` so nested icon buttons are first-class controls. Extend `Content` additively with new optional fields (id, etaSeconds, queuePosition, errorMessage, addedAt, hasPlayableMedia, files) so existing callers still compile. Migrate the single `LibraryView.swift` call site to populate the new fields and wire 4 action callbacks; remove the now-redundant standalone trash button.

**Tech Stack:** Swift 6 / SwiftUI / macOS 15+. Tests with `swift-testing` (`@Suite`/`@Test`/`#expect`). MinchUI is a leaf-level Swift package (depends on MinchKit only). All work lands in `Packages/MinchUI/Sources/MinchUI/` and `Packages/MinchUI/Tests/MinchUITests/`, plus a single call-site migration in `App/Minch/LibraryView.swift`.

**Spec:** `docs/superpowers/specs/2026-05-27-transfer-card-redesign-design.md`

---

## File Structure

**Create:**
- `Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift` — new public view; 24pt ZStack (hairline track + phase-tinted progress arc + centered 8pt `MinchStatusGlyph`).
- `Packages/MinchUI/Tests/MinchUITests/MinchTransferProgressRingTests.swift` — smoke instantiation per phase × progress.
- `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` — ETA, action gating, meta plain text, name dimming tests.

**Modify:**
- `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` — extend `Content` with new fields + nested `File`; add 4 action callbacks; rewrite body to use ring + adaptive meta + name attributed string + 4-icon cluster + per-file expansion; replace outer Button with Rectangle/onTapGesture.
- `App/Minch/LibraryView.swift:809-863` — populate new `Content` fields, wire callbacks (`onPlay`, `onReveal`, `onCopyLink`, `onDelete`), remove the standalone trash button outside the row.

**Do NOT touch (user WIP):**
- `App/Minch/AppModel.swift`
- `App/Minch/SettingsView.swift`
- `Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift`

**Not modified (leave verbatim):**
- `Packages/MinchUI/Sources/MinchUI/MinchStatusGlyph.swift` — dot is reused by composition.
- `Packages/MinchUI/Sources/MinchUI/Theme.swift` — uses existing tokens only.

---

## Commands Used Throughout

- Build MinchUI: `swift build --package-path Packages/MinchUI`
- Test MinchUI: `swift test --package-path Packages/MinchUI`
- Build app (full integration check): `./scripts/build-app.sh`

---

## Task 1: ETA formatter helper

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` (append static helper to existing extension)
- Test: `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` (new file)

- [ ] **Step 1: Write the failing tests**

Create `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter EtaTextTests`
Expected: FAIL with "type 'MinchTransferRow' has no member 'etaText'".

- [ ] **Step 3: Implement `etaText`**

In `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`, append inside the existing `public extension MinchTransferRow { ... }` block (right after `swarmText`):

```swift
    /// Returns "3m left" / "<1m left" / "1h 15m left". `nil` when omitted.
    static func etaText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        if seconds < 60 { return "<1m left" }
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m left" }
        if minutes == 0 { return "\(hours)h left" }
        return "\(hours)h \(minutes)m left"
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter EtaTextTests`
Expected: PASS — all 7 cases.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift
git commit -m "feat(MinchUI): add MinchTransferRow.etaText formatter"
```

---

## Task 2: Action gating helper

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` (add public nested type + static helper)
- Test: `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` (append suite)

- [ ] **Step 1: Write the failing tests**

Append to `TransferRowFormattingExtraTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter ActionEnablementTests`
Expected: FAIL — type not found.

- [ ] **Step 3: Implement `ActionEnablement` and `actionEnablement`**

In `MinchTransferRow.swift`, append inside the existing `public extension MinchTransferRow { ... }`:

```swift
    struct ActionEnablement: Equatable, Sendable {
        public let play: Bool
        public let reveal: Bool
        public let copyLink: Bool
        public let delete: Bool

        public init(play: Bool, reveal: Bool, copyLink: Bool, delete: Bool) {
            self.play = play
            self.reveal = reveal
            self.copyLink = copyLink
            self.delete = delete
        }
    }

    /// Per-phase action gating. Icons stay in the cluster either way — `false`
    /// means dimmed (`.tertiary` + `.disabled(true)`) so the row never reflows.
    static func actionEnablement(phase: MinchStatusPhase, hasPlayableMedia: Bool) -> ActionEnablement {
        switch phase {
        case .idle:
            return ActionEnablement(play: false, reveal: false, copyLink: false, delete: true)
        case .queued, .active, .paused, .error:
            return ActionEnablement(play: false, reveal: false, copyLink: true, delete: true)
        case .done:
            return ActionEnablement(play: hasPlayableMedia, reveal: true, copyLink: true, delete: true)
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter ActionEnablementTests`
Expected: PASS — all 8 cases.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift
git commit -m "feat(MinchUI): add MinchTransferRow.actionEnablement gating helper"
```

---

## Task 3: Meta line plain-text aggregator + supporting helpers

The view body will assemble styled segments; this aggregator returns the same content as a `String` for unit tests. Shared helpers (`queuedText`, `pausedText`, `relativeAddedText`) live as static methods so the view body can reuse them.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` (add helpers — depends on Content extension from Task 5; for now, the aggregator takes primitives, not Content, so Task 3 can run independently)
- Test: `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` (append suite)

- [ ] **Step 1: Write the failing tests**

Append to `TransferRowFormattingExtraTests.swift`:

```swift
@Suite("MinchTransferRow.metaPlainText")
struct MetaPlainTextTests {
    @Test func idleShowsSizeOnly() {
        let s = MinchTransferRow.metaPlainText(
            phase: .idle, sizeBytes: 2_400_000_000, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "2.4 GB")
    }

    @Test func queuedWithPosition() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: 4, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued · #4")
    }

    @Test func queuedWithoutPosition() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued")
    }

    @Test func activeWithSpeedAndEta() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 2_400_000_000, downloadSpeed: 18_000_000, progress: 0.5,
            etaSeconds: 195, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s.hasPrefix("2.4 GB · "))
        #expect(s.hasSuffix(" · 3m left"))
        #expect(s.contains("/s"))
    }

    @Test func activeOmitsZeroSpeedAndZeroEta() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 1_000_000, downloadSpeed: 0, progress: 0,
            etaSeconds: 0, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "1 MB")
    }

    @Test func pausedShowsSizeAndPercent() {
        let s = MinchTransferRow.metaPlainText(
            phase: .paused, sizeBytes: 2_400_000_000, downloadSpeed: 0, progress: 0.42,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Paused · 2.4 GB · 42%")
    }

    @Test func errorShowsMessage() {
        let s = MinchTransferRow.metaPlainText(
            phase: .error, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: "Tracker unreachable", addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Tracker unreachable")
    }

    @Test func errorFallsBackWhenMessageMissing() {
        let s = MinchTransferRow.metaPlainText(
            phase: .error, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Error")
    }

    @Test func doneWithAddedAt() {
        let now = Date(timeIntervalSince1970: 10_000)
        let added = now.addingTimeInterval(-7_200) // 2h ago
        let s = MinchTransferRow.metaPlainText(
            phase: .done, sizeBytes: 18_300_000_000, downloadSpeed: 0, progress: 1.0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: added,
            now: now
        )
        #expect(s == "18.3 GB · added 2h ago")
    }

    @Test func doneWithoutAddedAt() {
        let s = MinchTransferRow.metaPlainText(
            phase: .done, sizeBytes: 18_300_000_000, downloadSpeed: 0, progress: 1.0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "18.3 GB")
    }
}

@Suite("MinchTransferRow.relativeAddedShort")
struct RelativeAddedShortTests {
    @Test func secondsBecomeJustNow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-30)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "just now")
    }

    @Test func minutes() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-180)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "3m")
    }

    @Test func hours() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-3 * 3600)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "3h")
    }

    @Test func days() {
        let now = Date(timeIntervalSince1970: 86_400 * 10)
        let past = now.addingTimeInterval(-2 * 86_400)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "2d")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter MetaPlainTextTests`
Then: `swift test --package-path Packages/MinchUI --filter RelativeAddedShortTests`
Expected: FAIL — helpers don't exist yet.

- [ ] **Step 3: Implement the helpers**

In `MinchTransferRow.swift`, append inside the existing `public extension MinchTransferRow { ... }`:

```swift
    /// Short relative time suffix used after "added " in the done-phase meta line.
    /// Returns "just now" / "3m" / "3h" / "2d".
    static func relativeAddedShort(from date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        if elapsed < 60 { return "just now" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    /// Plain-text version of the adaptive meta line. The view body builds the
    /// styled HStack from the same inputs; this is the testable kernel.
    static func metaPlainText(
        phase: MinchStatusPhase,
        sizeBytes: Int64,
        downloadSpeed: Int64,
        progress: Double,
        etaSeconds: Int?,
        queuePosition: Int?,
        errorMessage: String?,
        addedAt: Date?,
        now: Date = Date()
    ) -> String {
        switch phase {
        case .idle:
            return sizeText(sizeBytes)

        case .queued:
            if let q = queuePosition { return "Queued · #\(q)" }
            return "Queued"

        case .active:
            var parts: [String] = [sizeText(sizeBytes)]
            if let speed = speedText(downloadSpeed) { parts.append(speed) }
            if let eta = etaSeconds.flatMap({ etaText($0) }) { parts.append(eta) }
            return parts.joined(separator: " · ")

        case .paused:
            return "Paused · \(sizeText(sizeBytes)) · \(percentText(progress))"

        case .error:
            return errorMessage ?? "Error"

        case .done:
            if let added = addedAt {
                return "\(sizeText(sizeBytes)) · added \(relativeAddedShort(from: added, now: now)) ago"
            }
            return sizeText(sizeBytes)
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter MetaPlainTextTests`
Then: `swift test --package-path Packages/MinchUI --filter RelativeAddedShortTests`
Expected: PASS for all cases in both suites.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift
git commit -m "feat(MinchUI): add adaptive meta line text helpers"
```

---

## Task 4: Name styling helper (`dimmedSeparatorIndices` + `nameAttributedString`)

The pure kernel `dimmedSeparatorIndices(_:) -> Set<Int>` is fully testable; `nameAttributedString` wraps it to produce an `AttributedString` consumed by the view.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` (append static helpers)
- Test: `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` (append suite)

- [ ] **Step 1: Write the failing tests**

Append to `TransferRowFormattingExtraTests.swift`:

```swift
@Suite("MinchTransferRow.dimmedSeparatorIndices")
struct DimmedSeparatorIndicesTests {
    @Test func emptyStringHasNoDims() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("") == [])
    }

    @Test func noSeparatorsReturnsEmpty() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("PlainName") == [])
    }

    @Test func dotsBetweenWordCharsAreDimmed() {
        // "a.b" — only the dot at index 1 is between word chars
        #expect(MinchTransferRow.dimmedSeparatorIndices("a.b") == [1])
    }

    @Test func leadingSeparatorNotDimmed() {
        // ".foo" — leading dot has no preceding word char
        #expect(MinchTransferRow.dimmedSeparatorIndices(".foo") == [])
    }

    @Test func trailingSeparatorNotDimmed() {
        // "foo." — trailing dot has no following word char
        #expect(MinchTransferRow.dimmedSeparatorIndices("foo.") == [])
    }

    @Test func mixedSeparatorsAllDimmed() {
        // "The.Matrix_1999-2160p" — indices of '.', '_', '-'
        let s = "The.Matrix_1999-2160p"
        let dims = MinchTransferRow.dimmedSeparatorIndices(s)
        // '.' is at 3, '_' at 10, '-' at 15
        #expect(dims == [3, 10, 15])
    }

    @Test func consecutiveSeparatorsOnlyDimWhenBothSidesAreWordChars() {
        // "a..b" — first '.' is between 'a' and '.', not word/word — not dimmed
        //         second '.' is between '.' and 'b', not word/word — not dimmed
        #expect(MinchTransferRow.dimmedSeparatorIndices("a..b") == [])
    }
}

@Suite("MinchTransferRow.nameAttributedString")
struct NameAttributedStringTests {
    @Test func returnsAttributedStringMatchingInputCharacters() {
        let name = "a.b"
        let attr = MinchTransferRow.nameAttributedString(name)
        #expect(String(attr.characters) == name)
    }

    @Test func plainNameProducesAttributedString() {
        let name = "PlainName"
        let attr = MinchTransferRow.nameAttributedString(name)
        #expect(String(attr.characters) == name)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter DimmedSeparatorIndicesTests`
Then: `swift test --package-path Packages/MinchUI --filter NameAttributedStringTests`
Expected: FAIL — helpers don't exist.

- [ ] **Step 3: Implement the helpers**

In `MinchTransferRow.swift`, append inside the existing `public extension MinchTransferRow { ... }`:

```swift
    /// Returns the 0-based UTF16 indices into `name` of separator characters
    /// (`.`, `_`, `-`) that sit *between* two word characters. These are the
    /// indices the view body renders at reduced opacity.
    static func dimmedSeparatorIndices(_ name: String) -> Set<Int> {
        let scalars = Array(name)
        guard scalars.count >= 3 else { return [] }
        var out: Set<Int> = []
        for i in 1..<(scalars.count - 1) {
            let c = scalars[i]
            guard c == "." || c == "_" || c == "-" else { continue }
            let prev = scalars[i - 1]
            let next = scalars[i + 1]
            if MinchTransferRow.isNameWordChar(prev), MinchTransferRow.isNameWordChar(next) {
                out.insert(i)
            }
        }
        return out
    }

    /// Builds an `AttributedString` with `.tracking(-0.2)`, default foreground,
    /// and per-character `.foregroundColor` overrides at 0.45 opacity for any
    /// separator returned by `dimmedSeparatorIndices`.
    static func nameAttributedString(_ name: String) -> AttributedString {
        var attr = AttributedString(name)
        attr.tracking = -0.2
        let dims = dimmedSeparatorIndices(name)
        guard !dims.isEmpty else { return attr }
        let chars = Array(name)
        let dimColor = Color.primary.opacity(0.45)
        for index in dims {
            let target = String(chars[index])
            // Walk runs to find the matching single-character substring.
            // Since separator chars (. _ -) appear distinctly, we find the
            // n-th occurrence whose position matches `index` in the source.
            if let range = attr.range(of: target, options: [.literal]) {
                // The first match may not be the right occurrence; advance by
                // searching forward until we hit the one at `index`.
                var current = range
                var charsBefore = MinchTransferRow.utf16Distance(from: attr.startIndex, to: current.lowerBound, in: attr)
                while charsBefore != index {
                    let next = attr[current.upperBound..<attr.endIndex].range(of: target, options: [.literal])
                    guard let next else { break }
                    current = next
                    charsBefore = MinchTransferRow.utf16Distance(from: attr.startIndex, to: current.lowerBound, in: attr)
                }
                if charsBefore == index {
                    attr[current].foregroundColor = dimColor
                }
            }
        }
        return attr
    }

    /// Internal — character (not UTF-16) distance between two AttributedString indices.
    static func utf16Distance(from start: AttributedString.Index,
                              to end: AttributedString.Index,
                              in attr: AttributedString) -> Int {
        attr.characters.distance(from: start, to: end)
    }

    /// Word char for separator-dimming purposes: ASCII letter or digit.
    static func isNameWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter DimmedSeparatorIndicesTests`
Then: `swift test --package-path Packages/MinchUI --filter NameAttributedStringTests`
Expected: PASS — all cases in both suites.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift
git commit -m "feat(MinchUI): add nameAttributedString with separator dimming"
```

---

## Task 5: New `MinchTransferProgressRing` view

**Files:**
- Create: `Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift`
- Create: `Packages/MinchUI/Tests/MinchUITests/MinchTransferProgressRingTests.swift`

- [ ] **Step 1: Write the failing smoke tests**

Create `Packages/MinchUI/Tests/MinchUITests/MinchTransferProgressRingTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter MinchTransferProgressRingTests`
Expected: FAIL — `MinchTransferProgressRing` doesn't exist.

- [ ] **Step 3: Implement the view**

Create `Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift`:

```swift
import SwiftUI

/// A 24pt phase-aware progress ring with the existing 8pt `MinchStatusGlyph`
/// centered inside it. The dot is reused verbatim; phase drives ring tint and
/// dot motion. Sits in a 28pt visual slot so it balances the icon cluster on
/// the right of `MinchTransferRow`.
public struct MinchTransferProgressRing: View {
    private let phase: MinchStatusPhase
    private let progress: Double

    private static let diameter: CGFloat = 24
    private static let strokeWidth: CGFloat = 2

    public init(phase: MinchStatusPhase, progress: Double) {
        self.phase = phase
        self.progress = MinchTransferRow.clampedProgress(progress)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.minchHairline, lineWidth: Self.strokeWidth)
                .frame(width: Self.diameter, height: Self.diameter)

            if shouldShowFill {
                Circle()
                    .trim(from: 0, to: trimEnd)
                    .stroke(ringTint, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: Self.diameter, height: Self.diameter)
            }

            MinchStatusGlyph(phase)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private var trimEnd: CGFloat {
        switch phase {
        case .done: return 1
        case .paused, .error, .active: return CGFloat(progress)
        case .queued, .idle: return 0
        }
    }

    private var shouldShowFill: Bool {
        switch phase {
        case .done: return true
        case .active, .paused, .error: return progress > 0
        case .queued, .idle: return false
        }
    }

    private var ringTint: Color {
        switch phase {
        case .active: return .minchCurrent
        case .done: return .minchSuccess
        case .paused: return .minchWarning
        case .error: return .minchDanger
        case .queued, .idle: return .minchHairline
        }
    }
}

#Preview {
    HStack(spacing: MinchSpacing.l) {
        ForEach(MinchStatusPhase.allCases, id: \.self) { phase in
            VStack(spacing: 4) {
                MinchTransferProgressRing(phase: phase, progress: 0.62)
                Text(phase.label).font(.minchCaption).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter MinchTransferProgressRingTests`
Expected: PASS — all parameterized cases.

- [ ] **Step 5: Build the package to confirm no warnings**

Run: `swift build --package-path Packages/MinchUI`
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift Packages/MinchUI/Tests/MinchUITests/MinchTransferProgressRingTests.swift
git commit -m "feat(MinchUI): add MinchTransferProgressRing"
```

---

## Task 6: Extend `Content` with new fields + nested `File`

This is an *additive* API change: every new field has a default in the `init`, so existing call sites continue to compile.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`
- Test: `Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift` (append suite)

- [ ] **Step 1: Write the failing test**

Append to `TransferRowFormattingExtraTests.swift`:

```swift
@Suite("MinchTransferRow.Content surface")
struct ContentSurfaceTests {
    @Test func existingInitStillCompilesWithDefaults() {
        let c = MinchTransferRow.Content(
            name: "Foo.mkv",
            phase: .active,
            sizeBytes: 100,
            downloadSpeed: 10,
            progress: 0.5
        )
        #expect(c.id == "")
        #expect(c.etaSeconds == nil)
        #expect(c.queuePosition == nil)
        #expect(c.errorMessage == nil)
        #expect(c.addedAt == nil)
        #expect(c.hasPlayableMedia == false)
        #expect(c.files.isEmpty)
    }

    @Test func newFieldsArePropagated() {
        let added = Date(timeIntervalSince1970: 1_000)
        let file = MinchTransferRow.Content.File(id: "f1", name: "a.mkv", sizeBytes: 42, isPlayable: true)
        let c = MinchTransferRow.Content(
            id: "t1",
            name: "Foo.mkv",
            phase: .done,
            sizeBytes: 100,
            downloadSpeed: 0,
            progress: 1.0,
            seeds: nil,
            peers: nil,
            etaSeconds: 0,
            queuePosition: nil,
            errorMessage: nil,
            addedAt: added,
            hasPlayableMedia: true,
            files: [file]
        )
        #expect(c.id == "t1")
        #expect(c.addedAt == added)
        #expect(c.hasPlayableMedia == true)
        #expect(c.files.count == 1)
        #expect(c.files[0].name == "a.mkv")
        #expect(c.files[0].isPlayable == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter ContentSurfaceTests`
Expected: FAIL — new fields don't exist.

- [ ] **Step 3: Extend the `Content` struct**

Replace the entire existing `public struct Content: Equatable, Sendable { ... }` block in `MinchTransferRow.swift` with:

```swift
public struct Content: Equatable, Sendable {
    public let id: String
    public let name: String
    public let phase: MinchStatusPhase
    public let sizeBytes: Int64
    public let downloadSpeed: Int64
    public let progress: Double
    public let seeds: Int?
    public let peers: Int?
    public let etaSeconds: Int?
    public let queuePosition: Int?
    public let errorMessage: String?
    public let addedAt: Date?
    public let hasPlayableMedia: Bool
    public let files: [File]

    public init(
        id: String = "",
        name: String,
        phase: MinchStatusPhase,
        sizeBytes: Int64,
        downloadSpeed: Int64,
        progress: Double,
        seeds: Int? = nil,
        peers: Int? = nil,
        etaSeconds: Int? = nil,
        queuePosition: Int? = nil,
        errorMessage: String? = nil,
        addedAt: Date? = nil,
        hasPlayableMedia: Bool = false,
        files: [File] = []
    ) {
        self.id = id
        self.name = name
        self.phase = phase
        self.sizeBytes = sizeBytes
        self.downloadSpeed = downloadSpeed
        self.progress = progress
        self.seeds = seeds
        self.peers = peers
        self.etaSeconds = etaSeconds
        self.queuePosition = queuePosition
        self.errorMessage = errorMessage
        self.addedAt = addedAt
        self.hasPlayableMedia = hasPlayableMedia
        self.files = files
    }

    public struct File: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let sizeBytes: Int64
        public let isPlayable: Bool

        public init(id: String, name: String, sizeBytes: Int64, isPlayable: Bool) {
            self.id = id
            self.name = name
            self.sizeBytes = sizeBytes
            self.isPlayable = isPlayable
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter ContentSurfaceTests`
Expected: PASS — both cases. Also run the full suite to confirm no regression:
Run: `swift test --package-path Packages/MinchUI`
Expected: all previous tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift Packages/MinchUI/Tests/MinchUITests/TransferRowFormattingExtraTests.swift
git commit -m "feat(MinchUI): extend MinchTransferRow.Content with id, eta, files, etc."
```

---

## Task 7: Add 4 action callbacks to `MinchTransferRow.init`

These callbacks are optional. When `nil`, the corresponding icon stays in the cluster but is rendered disabled.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`

- [ ] **Step 1: Replace the existing `init` and add storage**

In `MinchTransferRow.swift`, replace the existing stored properties and `init` with:

```swift
private let content: Content
private let isExpanded: Bool
private let onToggle: (() -> Void)?
private let onPlay: ((Content.File?) -> Void)?
private let onReveal: ((Content.File?) -> Void)?
private let onCopyLink: (() -> Void)?
private let onDelete: (() -> Void)?

public init(
    content: Content,
    isExpanded: Bool = false,
    onToggle: (() -> Void)? = nil,
    onPlay: ((Content.File?) -> Void)? = nil,
    onReveal: ((Content.File?) -> Void)? = nil,
    onCopyLink: (() -> Void)? = nil,
    onDelete: (() -> Void)? = nil
) {
    self.content = content
    self.isExpanded = isExpanded
    self.onToggle = onToggle
    self.onPlay = onPlay
    self.onReveal = onReveal
    self.onCopyLink = onCopyLink
    self.onDelete = onDelete
}
```

- [ ] **Step 2: Run the full MinchUI test suite to confirm nothing broke**

Run: `swift test --package-path Packages/MinchUI`
Expected: every existing test still PASS (the new closures default to `nil` so existing callers compile).

- [ ] **Step 3: Build the package**

Run: `swift build --package-path Packages/MinchUI`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift
git commit -m "feat(MinchUI): add play/reveal/copy/delete callbacks to MinchTransferRow"
```

---

## Task 8: Rewrite `body` — ring + name + adaptive meta + 4-icon cluster + chevron

This task swaps the entire body. The previous body used a single outer `Button(onToggle)` and a linear `ProgressView`. The new body uses a `Rectangle().contentShape` + `onTapGesture` for row-level expand, with the icon cluster as first-class buttons.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`

- [ ] **Step 1: Replace the `body` and add helper subviews**

Replace the entire existing `public var body: some View { ... }` plus the existing `accessibilityLabel` computed property with:

```swift
public var body: some View {
    VStack(spacing: 0) {
        collapsedRow

        if isExpanded {
            VStack(spacing: 0) {
                Divider().background(Color.minchHairline)
                if content.files.isEmpty {
                    Text("No files yet.")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MinchSpacing.l)
                        .padding(.vertical, MinchSpacing.s)
                } else {
                    ForEach(content.files) { file in
                        FileRow(
                            file: file,
                            onPlay: file.isPlayable ? { onPlay?(file) } : nil,
                            onReveal: { onReveal?(file) }
                        )
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    .background(
        RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
            .fill(Color.minchSurfaceCard)
    )
    .overlay(
        RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
            .stroke(Color.minchHairline, lineWidth: 1)
    )
    .animation(MinchMotion.smooth, value: isExpanded)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
}

private var collapsedRow: some View {
    HStack(spacing: MinchSpacing.l) {
        MinchTransferProgressRing(phase: content.phase, progress: content.progress)

        VStack(alignment: .leading, spacing: 4) {
            Text(MinchTransferRow.nameAttributedString(content.name))
                .font(.minchHeadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            metaLine
        }

        Spacer()

        actionCluster

        if onToggle != nil {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.minchCaption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
    }
    .padding(MinchSpacing.l)
    .frame(minHeight: 64)
    .contentShape(Rectangle())
    .onTapGesture { onToggle?() }
}

private var metaLine: some View {
    let enablement = MinchTransferRow.actionEnablement(
        phase: content.phase, hasPlayableMedia: content.hasPlayableMedia
    )
    _ = enablement // referenced in actionCluster; keep capture explicit for readability
    return Group {
        switch content.phase {
        case .idle:
            Text(MinchTransferRow.sizeText(content.sizeBytes))
                .font(.minchCaption)
                .foregroundStyle(.secondary)

        case .queued:
            HStack(spacing: MinchSpacing.s) {
                Text("Queued")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
                if let q = content.queuePosition {
                    Text("·")
                        .font(.minchCaption)
                        .foregroundStyle(.tertiary)
                    Text("#\(q)")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                }
            }

        case .active:
            HStack(spacing: MinchSpacing.s) {
                Text(MinchTransferRow.sizeText(content.sizeBytes))
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
                if let speed = MinchTransferRow.speedText(content.downloadSpeed) {
                    Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                    Text(speed).font(.minchMono).foregroundStyle(Color.minchCurrent)
                }
                if let eta = content.etaSeconds.flatMap({ MinchTransferRow.etaText($0) }) {
                    Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                    Text(eta).font(.minchCaption).foregroundStyle(.secondary)
                }
            }

        case .paused:
            HStack(spacing: MinchSpacing.s) {
                Text("Paused").font(.minchCaption).foregroundStyle(.secondary)
                Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                Text(MinchTransferRow.sizeText(content.sizeBytes))
                    .font(.minchCaption).foregroundStyle(.secondary)
                Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                Text(MinchTransferRow.percentText(content.progress))
                    .font(.minchCaption).foregroundStyle(.secondary)
            }

        case .error:
            Text(content.errorMessage ?? "Error")
                .font(.minchCaption)
                .foregroundStyle(Color.minchDanger)
                .lineLimit(1)

        case .done:
            HStack(spacing: MinchSpacing.s) {
                Text(MinchTransferRow.sizeText(content.sizeBytes))
                    .font(.minchCaption).foregroundStyle(.secondary)
                if let added = content.addedAt {
                    Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                    Text("added \(MinchTransferRow.relativeAddedShort(from: added)) ago")
                        .font(.minchCaption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private var actionCluster: some View {
    let enablement = MinchTransferRow.actionEnablement(
        phase: content.phase, hasPlayableMedia: content.hasPlayableMedia
    )
    let isCancelling = content.phase == .active || content.phase == .queued || content.phase == .paused
    return HStack(spacing: MinchSpacing.s) {
        actionIcon(
            system: "play.fill",
            help: "Play",
            enabled: enablement.play,
            action: { onPlay?(nil) }
        )
        actionIcon(
            system: "folder",
            help: "Reveal in Finder",
            enabled: enablement.reveal,
            action: { onReveal?(nil) }
        )
        actionIcon(
            system: "link",
            help: "Copy link",
            enabled: enablement.copyLink,
            action: { onCopyLink?() }
        )
        actionIcon(
            system: "trash",
            help: isCancelling ? "Cancel" : "Remove",
            enabled: enablement.delete,
            action: { onDelete?() }
        )
    }
}

private func actionIcon(
    system: String,
    help: String,
    enabled: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Image(systemName: system)
            .font(.minchCaption)
            .foregroundStyle(enabled ? .secondary : .tertiary)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .help(help)
    .accessibilityLabel(help)
}

private var accessibilityLabel: String {
    "\(content.name), \(content.phase.label), \(MinchTransferRow.percentText(content.progress))"
}

private struct FileRow: View {
    let file: Content.File
    let onPlay: (() -> Void)?
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Text(file.name)
                .font(.minchCaption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: MinchSpacing.s)
            Text(MinchTransferRow.sizeText(file.sizeBytes))
                .font(.minchCaption)
                .foregroundStyle(.secondary)
            if let onPlay {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Play")
                .accessibilityLabel("Play \(file.name)")
            }
            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal \(file.name) in Finder")
        }
        .padding(.horizontal, MinchSpacing.l)
        .frame(minHeight: 32)
    }
}
```

- [ ] **Step 2: Update the existing `#Preview` to exercise the new surface**

In `MinchTransferRow.swift`, replace the existing `#Preview { ... }` block at the bottom of the file with:

```swift
#Preview {
    VStack(spacing: MinchSpacing.s) {
        MinchTransferRow(
            content: .init(
                id: "t1",
                name: "The.Matrix.1999.2160p.UHD.BluRay.mkv",
                phase: .active,
                sizeBytes: 2_400_000_000,
                downloadSpeed: 18_000_000,
                progress: 0.62,
                etaSeconds: 195,
                hasPlayableMedia: false,
                files: []
            ),
            onToggle: {},
            onPlay: { _ in },
            onReveal: { _ in },
            onCopyLink: {},
            onDelete: {}
        )

        MinchTransferRow(
            content: .init(
                id: "t2",
                name: "Solaris.1972.Criterion.2160p.mkv",
                phase: .done,
                sizeBytes: 18_300_000_000,
                downloadSpeed: 0,
                progress: 1.0,
                addedAt: Date().addingTimeInterval(-7_200),
                hasPlayableMedia: true,
                files: [
                    .init(id: "f1", name: "Solaris.mkv", sizeBytes: 18_300_000_000, isPlayable: true)
                ]
            ),
            isExpanded: true,
            onToggle: {},
            onPlay: { _ in },
            onReveal: { _ in },
            onCopyLink: {},
            onDelete: {}
        )

        MinchTransferRow(
            content: .init(
                id: "t3",
                name: "Mishandled.tracker.torrent",
                phase: .error,
                sizeBytes: 1_200_000_000,
                downloadSpeed: 0,
                progress: 0.12,
                errorMessage: "Tracker unreachable"
            )
        )
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Run the MinchUI test suite**

Run: `swift test --package-path Packages/MinchUI`
Expected: every test passes. The existing `TransferRowFormattingTests` still apply to the static helpers (untouched).

- [ ] **Step 4: Build the package**

Run: `swift build --package-path Packages/MinchUI`
Expected: build succeeds with no warnings.

- [ ] **Step 5: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift
git commit -m "feat(MinchUI): rewrite MinchTransferRow body — ring, name AS, 4-icon cluster, expanded file list"
```

---

## Task 9: Phase-aware motion (active pulse + error shake)

Polish — the ring's dot pulses while `.active`, and shakes once on `.error` appearance.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift`

- [ ] **Step 1: Add motion state to `MinchTransferProgressRing`**

Open `Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift` and replace the existing `body` and add state:

```swift
@State private var pulseOpacity: Double = 1.0
@State private var shakeOffset: CGFloat = 0

public var body: some View {
    ZStack {
        Circle()
            .stroke(Color.minchHairline, lineWidth: Self.strokeWidth)
            .frame(width: Self.diameter, height: Self.diameter)

        if shouldShowFill {
            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(ringTint, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: Self.diameter, height: Self.diameter)
        }

        MinchStatusGlyph(phase)
            .opacity(phase == .active ? pulseOpacity : 1.0)
            .offset(x: shakeOffset)
    }
    .frame(width: 28, height: 28)
    .accessibilityHidden(true)
    .onAppear { applyMotionForCurrentPhase() }
    .onChange(of: phase) { _, _ in applyMotionForCurrentPhase() }
}

private func applyMotionForCurrentPhase() {
    pulseOpacity = 1.0
    shakeOffset = 0
    switch phase {
    case .active:
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.7
        }
    case .error:
        withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
            shakeOffset = 2
        }
    default:
        break
    }
}
```

- [ ] **Step 2: Run the ring smoke tests (must still pass)**

Run: `swift test --package-path Packages/MinchUI --filter MinchTransferProgressRingTests`
Expected: PASS.

- [ ] **Step 3: Build the package**

Run: `swift build --package-path Packages/MinchUI`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferProgressRing.swift
git commit -m "feat(MinchUI): phase-aware pulse and shake motion on transfer progress ring"
```

---

## Task 10: Migrate `LibraryView.swift` call site

Wire `MinchTransferRow` to populate the new `Content` fields and pass real action callbacks. Remove the now-redundant trash button outside the row.

**Files:**
- Modify: `App/Minch/LibraryView.swift` — only the `TransferDisclosure` view (lines 795–900).

- [ ] **Step 1: Inspect the current state**

Read `App/Minch/LibraryView.swift` lines 795-900. Identify:
- The `MinchTransferRow` call (lines 812-824).
- The standalone trash `Button` (lines 840-850) — this is removed.
- The `confirmationDialog` for delete (lines 852-862) — kept; it now fires from `onDelete` instead of the standalone button.
- `model.copyDownloadLink(transferID:fileID:)` exists (verified). For a transfer-level "copy link" with no file, use the first downloaded file's ID, or skip if none.

- [ ] **Step 2: Replace the `HStack(spacing: 0) { MinchTransferRow(...) Button(systemName: "trash")... }` block**

In `App/Minch/LibraryView.swift`, find:

```swift
            HStack(spacing: 0) {
                MinchTransferRow(
                    content: .init(
                        name: row.name,
                        phase: MinchStatusPhase(transferStatusRaw: row.statusRaw),
                        sizeBytes: row.sizeBytes,
                        downloadSpeed: row.downloadSpeed,
                        progress: row.progress,
                        seeds: row.seeds,
                        peers: row.peers
                    ),
                    isExpanded: isExpanded,
                    onToggle: toggle
                )
                .contextMenu {
                    Button("Rename…") {
                        renameDraft = row.name
                        renaming = true
                    }
                    Button(editingTags ? "Hide tag editor" : "Edit tags…") {
                        editingTags.toggle()
                    }
                    Divider()
                    Button("Delete from TorBox", role: .destructive) {
                        confirmingDelete = true
                    }
                    .disabled(model.deletingTransferIDs.contains(row.id))
                }

                Button {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.minchDanger.opacity(0.8))
                        .padding(MinchSpacing.s)
                }
                .buttonStyle(.plain)
                .help("Delete from TorBox")
                .accessibilityLabel("Delete from TorBox")
                .disabled(model.deletingTransferIDs.contains(row.id))
            }
```

Replace with:

```swift
            MinchTransferRow(
                content: makeRowContent(),
                isExpanded: isExpanded,
                onToggle: toggle,
                onPlay: { file in handlePlay(file) },
                onReveal: { file in handleReveal(file) },
                onCopyLink: { handleCopyLink() },
                onDelete: { confirmingDelete = true }
            )
            .contextMenu {
                Button("Rename…") {
                    renameDraft = row.name
                    renaming = true
                }
                Button(editingTags ? "Hide tag editor" : "Edit tags…") {
                    editingTags.toggle()
                }
                Divider()
                Button("Delete from TorBox", role: .destructive) {
                    confirmingDelete = true
                }
                .disabled(model.deletingTransferIDs.contains(row.id))
            }
```

- [ ] **Step 3: Add helpers to `TransferDisclosure`**

Inside the `TransferDisclosure` struct, after the existing `@State` declarations and before `var body`, add:

```swift
    private func makeRowContent() -> MinchTransferRow.Content {
        let phase = MinchStatusPhase(transferStatusRaw: row.statusRaw)
        let etaSeconds: Int? = row.eta.map { Int($0.rounded()) }
        let sortedFiles = row.files.sorted(by: { $0.name < $1.name })
        let downloadedFiles = sortedFiles.filter { $0.isDownloaded }
        let mappedFiles: [MinchTransferRow.Content.File] = downloadedFiles.map { f in
            let kind = MediaKind.detect(name: f.name, mime: f.mime)
            return MinchTransferRow.Content.File(
                id: f.id,
                name: f.name,
                sizeBytes: f.sizeBytes,
                isPlayable: kind != .other && f.localPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
            )
        }
        let hasPlayableMedia = mappedFiles.contains(where: { $0.isPlayable })
        return MinchTransferRow.Content(
            id: row.id,
            name: row.name,
            phase: phase,
            sizeBytes: row.sizeBytes,
            downloadSpeed: row.downloadSpeed,
            progress: row.progress,
            seeds: row.seeds,
            peers: row.peers,
            etaSeconds: etaSeconds,
            queuePosition: nil,
            errorMessage: row.errorMessage,
            addedAt: row.addedAt,
            hasPlayableMedia: hasPlayableMedia,
            files: mappedFiles
        )
    }

    private func handlePlay(_ file: MinchTransferRow.Content.File?) {
        // Find the underlying stored file by id; if nil arg, pick first playable.
        let stored: StoredTransferFile? = {
            if let f = file {
                return row.files.first(where: { $0.id == f.id })
            }
            return row.files.first(where: {
                $0.isDownloaded
                && $0.localPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
                && MediaKind.detect(name: $0.name, mime: $0.mime) != .other
            })
        }()
        guard let stored, let path = stored.localPath else { return }
        let kind = MediaKind.detect(name: stored.name, mime: stored.mime)
        onPlay(PlaybackTarget(
            id: stored.id,
            file: stored,
            url: URL(fileURLWithPath: path),
            title: stored.name,
            kind: kind
        ))
    }

    private func handleReveal(_ file: MinchTransferRow.Content.File?) {
        let path: String? = {
            if let f = file {
                return row.files.first(where: { $0.id == f.id })?.localPath
            }
            return row.files.first(where: { $0.isDownloaded })?.localPath
        }()
        guard let path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func handleCopyLink() {
        // Transfer-level copy link → first downloaded file. AppModel exposes
        // copyDownloadLink(transferID:fileID:).
        guard let fileID = row.files.first(where: { $0.isDownloaded })?.id else { return }
        Task { await model.copyDownloadLink(transferID: row.id, fileID: fileID) }
    }
```

- [ ] **Step 4: Build the app to confirm integration compiles**

Run: `./scripts/build-app.sh`
Expected: build succeeds. If `NSWorkspace` isn't already imported in `LibraryView.swift`, add `import AppKit` to the top.

- [ ] **Step 5: Re-run MinchUI tests to confirm no regression**

Run: `swift test --package-path Packages/MinchUI`
Expected: all tests pass.

- [ ] **Step 6: Manual smoke test (recorded, not blocking)**

Launch the app: `open Build/Products/Release/Minch.app` (or whatever `build-app.sh` produced).

Manually confirm:
- Active transfers show a cyan progress ring with pulsing dot.
- Done transfers show a green full ring; Play icon is live iff there's playable media.
- Paused transfers show a yellow ring + percent.
- Error transfers show a red ring + the error message in red.
- Tapping the row body toggles expansion (no longer requires clicking the chevron specifically).
- The 4 icons sit always-visible to the right; dimmed ones don't respond to click.
- Clicking the trash icon brings up the existing confirmation dialog.

If any of these fail, fix before committing.

- [ ] **Step 7: Commit**

```bash
git add App/Minch/LibraryView.swift
git commit -m "feat(LibraryView): migrate to redesigned MinchTransferRow with in-row actions"
```

---

## Self-Review

After completing all tasks, run this self-review:

**1. Spec coverage**

Walk the spec section by section and confirm a task implements each:
- Architecture: 64pt row + three regions → Task 8.
- `MinchTransferProgressRing` (24pt ZStack, phase tint, ring fill) → Task 5.
- Phase behavior (active pulse, error shake) → Task 9.
- `Content` extension (id, etaSeconds, queuePosition, errorMessage, addedAt, hasPlayableMedia, files) → Task 6.
- 4 action callbacks → Task 7.
- Action gating (per-phase table) → Task 2.
- Meta line (adaptive per phase) → Task 3 + Task 8.
- Name treatment (separator dimming) → Task 4 + Task 8.
- Layout container (Rectangle + onTapGesture replaces outer Button) → Task 8.
- Expanded state (per-file list) → Task 8.
- Data flow (LibraryView populates new fields) → Task 10.
- Error handling (clamping, omission of zero ETA/speed, empty files) → Tasks 1, 8.
- Testing (nameAttributedString, meta line, ETA, gating, ring smoke) → Tasks 1-5.

**2. Placeholder scan**

Grep this plan for `TBD`, `TODO`, `…`, `XXX`, `fill in`, "appropriate", "similar to":

```bash
grep -nE "TBD|TODO|XXX|\bfill in\b|appropriate|similar to" docs/superpowers/plans/2026-05-27-transfer-card-redesign.md
```

Expected: no matches.

**3. Type consistency**

- `ActionEnablement` properties: `play`, `reveal`, `copyLink`, `delete` (Task 2). Referenced as `enablement.play`, `enablement.reveal`, `enablement.copyLink`, `enablement.delete` in Task 8. ✓
- `Content.File` properties: `id`, `name`, `sizeBytes`, `isPlayable` (Task 6). Referenced in Task 8 (`file.isPlayable`, `file.name`, `file.sizeBytes`) and Task 10 (mapping from `StoredTransferFile`). ✓
- `MinchTransferProgressRing(phase:, progress:)` — Task 5 declares; Task 8 calls. ✓
- `MinchTransferRow.etaText`, `actionEnablement`, `metaPlainText`, `relativeAddedShort`, `nameAttributedString`, `dimmedSeparatorIndices` — all consumed by name in Task 8 and tested in Tasks 1-4. ✓
- Callback signatures match across Tasks 7, 8, 10: `onPlay`/`onReveal` take `Content.File?`; `onCopyLink`/`onDelete` take no args. ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-27-transfer-card-redesign.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
