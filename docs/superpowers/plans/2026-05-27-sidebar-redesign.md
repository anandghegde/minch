# Sidebar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign the LibraryView sidebar to PRD §14.2 — leading gradient bar on the selected row, account chip without quota, gear cog + Add in a sidebar footer, with Sign-out moved into AccountView and Settings reached via the footer cog.

**Architecture:** Two new presentation components and one extended component in the MinchUI package (`MinchAccountChip`, `MinchSidebarFooter`, `MinchSidebarRow.isSelected`). The app target rewrites `LibrarySidebar`, deletes the private `AccountChip`, trims `LibrarySection` (no `.settings` case), extends `CommandPalette` with an `initialAction` entry parameter, and adds a Sign-out button to `AccountView`. No `AppModel` / `SettingsView` / `TorBoxClient` changes (forbidden this cycle).

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / macOS 15+ / Swift Testing (`@Suite` / `@Test`). Existing tokens from `MinchUI.Theme` and motion from `MinchMotion.snap`.

**Spec:** `docs/superpowers/specs/2026-05-27-sidebar-redesign-design.md`

**Forbidden files (do not touch):**
- `App/Minch/AppModel.swift`
- `App/Minch/SettingsView.swift`
- `Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift`

**Standing rules:**
- Never use `git commit --no-verify`. Never `git push` unless explicitly asked. Never amend; always new commits.
- Surgical edits only — do not refactor adjacent code while touching files.
- Run `swift build` from the repo root before each commit. `swift test --package-path Packages/MinchUI` for MinchUI tests.

---

## File Structure

**Create (MinchUI package):**
- `Packages/MinchUI/Sources/MinchUI/MinchAccountChip.swift` — Account pill (avatar, plan, email, status dot)
- `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift` — Bottom row with gear cog + Add button
- `Packages/MinchUI/Tests/MinchUITests/MinchAccountChipTests.swift` — Status dot + initial derivation
- `Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift` — Closure firing
- `Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift` — Selected-state factoring helpers

**Modify (MinchUI package):**
- `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift` — Add `isSelected: Bool` parameter; leading bar + icon tint

**Modify (app target):**
- `App/Minch/LibrarySection.swift` — Remove `.settings`; remove `.system` group; rename `.smart` title to "Smart Collections"
- `App/Minch/CommandPalette.swift` — Add `initialAction: Action?` parameter
- `App/Minch/AccountView.swift` — Add `signOut` closure and a Sign-out button
- `App/Minch/LibraryView.swift` — Rewrite `LibrarySidebar` (lines 161–232); delete private `AccountChip` (lines 234–283); rewire `LibrarySidebar(...)` call site (lines 26–39); rewire `AccountView` invocation (line 76); remove `.settings: return []` arm from `filteredRows` (line 93–94)

**Note: no `App/MinchTests/` target exists.** App-target enum and palette behavior are verified by `swift build` (compile-driven for the enum cleanup) and the manual verification checklist at the end. Do not add a test target — out of scope.

---

## Task 1: Extend `MinchSidebarRow` with selected-state

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`
- Create: `Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift`

The current row tints the icon `.minchCurrent` on every render and has no concept of selection. The redesign drives icon tint from selection and adds a leading gradient bar when selected. Because SwiftUI test infrastructure for views in this repo asserts on factored static helpers (see `TransferRowFormattingTests`), we expose two static helpers — `iconColor(isSelected:)` and `barOpacity(isSelected:)` — that the test can call directly.

- [ ] **Step 1: Write the failing tests**

Replace the contents of `Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift` with:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter MinchSidebarRowSelectionTests`

Expected: FAIL — `iconColor`, `barOpacity`, and `Color.minchSidebarIconUnselected` do not exist.

- [ ] **Step 3: Add the unselected-icon color token**

In `Packages/MinchUI/Sources/MinchUI/Theme.swift`, inside `public extension Color { ... }`, append after `static let minchSelection`:

```swift
    static let minchSidebarIconUnselected = Color.white.opacity(0.55)
```

(A concrete `Color` value rather than `.secondary` so the equality test is meaningful. `.secondary` is a `ShapeStyle`, not a `Color`, and cannot be compared with `==`.)

- [ ] **Step 4: Replace `MinchSidebarRow` body and add helpers**

Open `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift` and replace the entire file with:

```swift
import SwiftUI

/// A row in the main-window sidebar: SF Symbol, label, optional count badge.
///
/// When `isSelected` is true the row paints a leading 3pt Bolt→Current gradient
/// bar and tints the icon `.minchCurrent`. When false the icon uses the muted
/// sidebar icon color. The macOS list style still owns the row highlight; this
/// view layers the brand affordance on top.
public struct MinchSidebarRow: View {
    private let systemImage: String
    private let title: String
    private let count: Int?
    private let isSelected: Bool

    public init(
        systemImage: String,
        title: String,
        count: Int? = nil,
        isSelected: Bool = false
    ) {
        self.systemImage = systemImage
        self.title = title
        self.count = count
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: systemImage)
                .font(.minchBody)
                .foregroundStyle(Self.iconColor(isSelected: isSelected))
                .frame(width: 18)

            Text(title)
                .font(.minchBody)
                .foregroundStyle(.primary)

            Spacer(minLength: MinchSpacing.s)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.minchMetadata)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.minchSurfaceSunken)
                    )
            }
        }
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(LinearGradient(
                    colors: [.minchBolt, .minchCurrent],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 3)
                .padding(.vertical, 2)
                .opacity(Self.barOpacity(isSelected: isSelected))
                .animation(MinchMotion.snap, value: isSelected)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let count, count > 0 else { return title }
        return "\(title), \(count)"
    }

    // MARK: - Test-facing helpers

    static func iconColor(isSelected: Bool) -> Color {
        isSelected ? .minchCurrent : .minchSidebarIconUnselected
    }

    static func barOpacity(isSelected: Bool) -> Double {
        isSelected ? 1 : 0
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        MinchSidebarRow(systemImage: "bolt.fill", title: "Active", count: 3, isSelected: true)
        MinchSidebarRow(systemImage: "tray.full", title: "Downloaded", count: 27, isSelected: false)
        MinchSidebarRow(systemImage: "trash", title: "Trash", isSelected: false)
    }
    .padding()
    .frame(width: 220)
    .background(Color.minchSurfaceSidebar)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter MinchSidebarRowSelectionTests`

Expected: PASS — all four tests green.

- [ ] **Step 6: Build the workspace to confirm callers still compile**

Run: `swift build`

Expected: `Build complete!` — `LibrarySidebar` constructs `MinchSidebarRow` without `isSelected`, which still works thanks to the default `false`.

- [ ] **Step 7: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift \
        Packages/MinchUI/Sources/MinchUI/Theme.swift \
        Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift
git commit -m "feat(MinchUI): add isSelected to MinchSidebarRow with leading gradient bar"
```

---

## Task 2: Add `MinchAccountChip` component

**Files:**
- Create: `Packages/MinchUI/Sources/MinchUI/MinchAccountChip.swift`
- Create: `Packages/MinchUI/Tests/MinchUITests/MinchAccountChipTests.swift`

A reusable account pill: gradient avatar (initial), plan name, email, 6pt status dot. The chip takes its data as plain values, not a `UserAccount` instance, so it stays free of `MinchAPI` and is unit-testable without app-target imports.

- [ ] **Step 1: Write the failing tests**

Create `Packages/MinchUI/Tests/MinchUITests/MinchAccountChipTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter MinchAccountChipTests`

Expected: FAIL — `MinchAccountChip` does not exist.

- [ ] **Step 3: Create `MinchAccountChip.swift`**

Create `Packages/MinchUI/Sources/MinchUI/MinchAccountChip.swift`:

```swift
import SwiftUI

/// Top-of-sidebar account pill. Renders a gradient avatar with a status dot,
/// the plan name on top, and the email below. Hover dims toward
/// `minchSurfaceCardHover`; tap fires `action`.
///
/// Quota intentionally absent — `UserAccount` does not surface remaining quota
/// from the TorBox API, and PRD §14.2's quota slot is deferred until it does.
public struct MinchAccountChip: View {
    private let name: String
    private let email: String?
    private let planName: String
    private let isSubscribed: Bool
    private let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        email: String?,
        planName: String,
        isSubscribed: Bool,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.email = email
        self.planName = planName
        self.isSubscribed = isSubscribed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: MinchSpacing.s) {
                avatar
                VStack(alignment: .leading, spacing: MinchSpacing.xs) {
                    Text(planName)
                        .font(.minchBody)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let email, !email.isEmpty {
                        Text(email)
                            .font(.minchMetadata)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(MinchSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                    .fill(isHovered ? Color.minchSurfaceCardHover : Color.clear)
            )
            .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var avatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.minchBolt, .minchCurrent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 28, height: 28)
            .overlay(
                Text(Self.initial(name: name))
                    .font(.minchBody.bold())
                    .foregroundStyle(.white)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Self.statusDotColor(isSubscribed: isSubscribed))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.minchSurfaceSidebar, lineWidth: 1)
                    )
                    .offset(x: 1, y: -1)
            }
    }

    private var accessibilityLabel: String {
        let status = isSubscribed ? "active" : "inactive"
        if let email, !email.isEmpty {
            return "\(planName) plan, \(status), signed in as \(email)"
        }
        return "\(planName) plan, \(status)"
    }

    // MARK: - Test-facing helpers

    static func statusDotColor(isSubscribed: Bool) -> Color {
        isSubscribed ? .minchSuccess : .minchWarning
    }

    static func initial(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

#Preview {
    VStack(spacing: 12) {
        MinchAccountChip(
            name: "anand@example.com",
            email: "anand@example.com",
            planName: "Pro",
            isSubscribed: true,
            action: {}
        )
        MinchAccountChip(
            name: "free@example.com",
            email: "free@example.com",
            planName: "Free",
            isSubscribed: false,
            action: {}
        )
    }
    .padding()
    .frame(width: 220)
    .background(Color.minchSurfaceSidebar)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter MinchAccountChipTests`

Expected: PASS — all five tests green.

- [ ] **Step 5: Build the workspace**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchAccountChip.swift \
        Packages/MinchUI/Tests/MinchUITests/MinchAccountChipTests.swift
git commit -m "feat(MinchUI): add MinchAccountChip with avatar, plan, email, status dot"
```

---

## Task 3: Add `MinchSidebarFooter` component

**Files:**
- Create: `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift`
- Create: `Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift`

Bottom row of the sidebar with a gear cog (left) and an Add button (right). Both are icon-only buttons with the muted sidebar icon tint resting and `.minchCurrent` on hover. Testing focuses on the bits we can assert without rendering: hover-color helpers and that the closures stored on the view are invoked when sent.

- [ ] **Step 1: Write the failing tests**

Create `Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/MinchUI --filter MinchSidebarFooterTests`

Expected: FAIL — `MinchSidebarFooter` does not exist.

- [ ] **Step 3: Create `MinchSidebarFooter.swift`**

Create `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift`:

```swift
import SwiftUI

/// Pinned bottom row of the main-window sidebar.
///
/// Left: gear cog (opens Settings, ⌘,). Right: Add button (opens command
/// palette in Add mode, ⌘N). Resting icons use the muted sidebar tint;
/// hover lifts them to `.minchCurrent`.
public struct MinchSidebarFooter: View {
    public let onOpenSettings: () -> Void
    public let onAdd: () -> Void

    public init(
        onOpenSettings: @escaping () -> Void,
        onAdd: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.minchSurfaceSunken)
                .padding(.horizontal, MinchSpacing.s)

            HStack(spacing: MinchSpacing.s) {
                FooterIconButton(
                    systemImage: "gearshape",
                    accessibilityLabel: "Settings",
                    action: onOpenSettings
                )
                Spacer()
                FooterIconButton(
                    systemImage: "bolt.badge.plus",
                    accessibilityLabel: "Add transfer",
                    action: onAdd
                )
            }
            .padding(MinchSpacing.s)
        }
    }

    // MARK: - Test-facing helpers

    static func iconColor(isHovered: Bool) -> Color {
        isHovered ? .minchCurrent : .minchSidebarIconUnselected
    }
}

private struct FooterIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.minchBody)
                .foregroundStyle(MinchSidebarFooter.iconColor(isHovered: isHovered))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    MinchSidebarFooter(onOpenSettings: {}, onAdd: {})
        .frame(width: 220)
        .background(Color.minchSurfaceSidebar)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/MinchUI --filter MinchSidebarFooterTests`

Expected: PASS — all four tests green.

- [ ] **Step 5: Build the workspace**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift \
        Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift
git commit -m "feat(MinchUI): add MinchSidebarFooter with gear cog + Add buttons"
```

---

## Task 4: Trim `LibrarySection` enum

**Files:**
- Modify: `App/Minch/LibrarySection.swift`

Remove the `.settings` case (Settings now reached via the footer cog, not a sidebar row), drop the `.system` group, and rename the `.smart` group title to "Smart Collections" per PRD §14.2.

- [ ] **Step 1: Replace `LibrarySection.swift`**

Open `App/Minch/LibrarySection.swift` and replace the entire file with:

```swift
import Foundation

/// Top-level sidebar selection (PRD §3.2). Sprint 5 shipped Active/Downloaded;
/// Sprint 9 adds Smart Collections (videos, audio, recent). Settings is no
/// longer a selectable row — it lives on the sidebar footer.
enum LibrarySection: Hashable, Identifiable, CaseIterable {
    case active
    case downloaded
    case videos
    case audio
    case recent

    var id: String {
        switch self {
        case .active: "active"
        case .downloaded: "downloaded"
        case .videos: "videos"
        case .audio: "audio"
        case .recent: "recent"
        }
    }

    var title: String {
        switch self {
        case .active: "Active"
        case .downloaded: "Downloaded"
        case .videos: "Videos"
        case .audio: "Audio"
        case .recent: "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "bolt.fill"
        case .downloaded: "tray.full"
        case .videos: "film"
        case .audio: "music.note"
        case .recent: "clock"
        }
    }

    var group: Group {
        switch self {
        case .active, .downloaded: .library
        case .videos, .audio, .recent: .smart
        }
    }

    enum Group: String, CaseIterable {
        case library
        case smart

        var title: String {
            switch self {
            case .library: "Library"
            case .smart: "Smart Collections"
            }
        }
    }
}
```

- [ ] **Step 2: Build the workspace to surface stale callers**

Run: `swift build`

Expected: BUILD FAIL — `LibraryView.swift` still references `case .settings:` inside `filteredRows` (line 93–94) and inside `LibrarySidebar.count(for:)`. Note the exact error lines for Step 3.

- [ ] **Step 3: Remove the `.settings` arm from `filteredRows`**

Open `App/Minch/LibraryView.swift`. In `filteredRows` (search for `private var filteredRows`), delete these two lines:

```swift
        case .settings:
            return []
```

Leave the rest of the switch intact. The switch becomes exhaustive again because all remaining cases are handled.

- [ ] **Step 4: Build to confirm `LibrarySidebar.count(for:)` is the only remaining failure**

Run: `swift build`

Expected: BUILD FAIL — `LibrarySidebar.count(for:)` still has `case .settings: 0`. This file is rewritten wholesale in Task 7, so this transient failure is expected and will be resolved there.

- [ ] **Step 5: Temporarily delete the `.settings: 0` arm to restore the build**

Open `App/Minch/LibraryView.swift`. In `LibrarySidebar.count(for:)` (around line 222), delete this line:

```swift
        case .settings: 0
```

- [ ] **Step 6: Build to confirm green**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
git add App/Minch/LibrarySection.swift App/Minch/LibraryView.swift
git commit -m "refactor(App/Minch): drop .settings case; rename group to Smart Collections"
```

---

## Task 5: Extend `CommandPalette` with `initialAction` parameter

**Files:**
- Modify: `App/Minch/CommandPalette.swift`

Adds an optional `initialAction: Action?` so a caller can open the palette pre-positioned on a given action. The sidebar's footer Add button will pass `.addMagnet`. Existing call sites continue to work because the parameter is defaulted to `nil`.

- [ ] **Step 1: Add the `initialAction` parameter and pre-select logic**

Open `App/Minch/CommandPalette.swift`. Find the property declarations near the top of the struct:

```swift
    let onAction: (Action) -> Void
    let onDismiss: () -> Void
```

Replace them with:

```swift
    let initialAction: Action?
    let onAction: (Action) -> Void
    let onDismiss: () -> Void

    init(
        initialAction: Action? = nil,
        onAction: @escaping (Action) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialAction = initialAction
        self.onAction = onAction
        self.onDismiss = onDismiss
    }
```

(The struct had no explicit `init` before — synthesis was used. Defining one now lets callers opt into `initialAction` without breaking the existing call sites.)

- [ ] **Step 2: Pre-position `selectedIndex` on appear**

In the same file, find the existing `.onAppear { selectedIndex = 0 }` (around line 55) and replace it with:

```swift
        .onAppear {
            if let initialAction, let index = results.firstIndex(where: { $0.action == initialAction }) {
                selectedIndex = index
            } else {
                selectedIndex = 0
            }
        }
```

- [ ] **Step 3: Build to confirm the palette compiles**

Run: `swift build`

Expected: `Build complete!` — `LibraryView`'s existing `CommandPalette(onAction:onDismiss:)` call still resolves because `initialAction` defaults to `nil`.

- [ ] **Step 4: Manually verify default behavior is unchanged**

(No automated test target for the app — verify by inspection.) Re-read the new `init` and `.onAppear`. Confirm: when `initialAction == nil`, `selectedIndex` is reset to `0` exactly as before. When `initialAction` is set but doesn't match any entry (e.g., palette filtered down), it falls back to `0` rather than crashing.

- [ ] **Step 5: Commit**

```bash
git add App/Minch/CommandPalette.swift
git commit -m "feat(App/Minch): add initialAction param to CommandPalette"
```

---

## Task 6: Add Sign-out button to `AccountView`

**Files:**
- Modify: `App/Minch/AccountView.swift`

Sign-out moves out of the sidebar into the AccountView sheet. The parent passes a `signOut` closure that maps to the existing `model.signOut()` invocation.

- [ ] **Step 1: Add the `signOut` closure and a Sign-out section**

Open `App/Minch/AccountView.swift`. After the existing `let onDismiss: () -> Void` line (around line 11), add:

```swift
    let signOut: () -> Void
```

Then in `body`'s inner `VStack`, add a new section after `subscriptionsSection` and before the `if let error` block. Replace the `VStack(alignment: .leading, spacing: MinchSpacing.xl) { ... }` content with:

```swift
                VStack(alignment: .leading, spacing: MinchSpacing.xl) {
                    planSection
                    usageSection
                    subscriptionsSection
                    signOutSection
                    if let error = model.accountLoadError {
                        Text(error)
                            .font(.minchCaption)
                            .foregroundStyle(Color.minchDanger)
                    }
                }
```

Then add this new section method anywhere among the existing section methods (e.g., immediately after `subscriptionsSection`):

```swift
    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Session")
                .font(.minchHeadline)
            Button("Sign out", role: .destructive) {
                signOut()
                onDismiss()
            }
            .buttonStyle(.minch(.destructive))
        }
    }
```

(`onDismiss()` is called after `signOut()` so the sheet closes immediately — matching the previous sidebar behavior where signing out tore down the LibraryView entirely.)

- [ ] **Step 2: Build to surface the parent call site**

Run: `swift build`

Expected: BUILD FAIL — `LibraryView` constructs `AccountView(model:account:onDismiss:)` without the new `signOut:` argument. Note the line (around 76) for Task 7.

- [ ] **Step 3: Temporarily pass a stub `signOut` so the build stays green for the next task**

Open `App/Minch/LibraryView.swift`. Find the `.sheet(isPresented: $showAccount)` block (around line 75–77) and update the `AccountView` invocation to:

```swift
        .sheet(isPresented: $showAccount) {
            AccountView(
                model: model,
                account: account,
                onDismiss: { showAccount = false },
                signOut: { Task { await model.signOut() } }
            )
        }
```

- [ ] **Step 4: Build to confirm green**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add App/Minch/AccountView.swift App/Minch/LibraryView.swift
git commit -m "feat(App/Minch): add Sign-out button to AccountView sheet"
```

---

## Task 7: Rewrite `LibrarySidebar` and call site

**Files:**
- Modify: `App/Minch/LibraryView.swift`

Replace the existing `LibrarySidebar` (lines 161–232) and delete the private `AccountChip` (lines 234–283). Rewire the call site at lines 26–39 to pass the new closure set and remove refresh/sign-out wiring. Add palette-mode state and wire the Add button.

- [ ] **Step 1: Add palette initial-action state**

Open `App/Minch/LibraryView.swift`. In the `@State` block at the top of `struct LibraryView` (around line 14–19), add:

```swift
    @State private var paletteInitialAction: CommandPalette.Action? = nil
```

- [ ] **Step 2: Rewrite `LibrarySidebar(...)` call site**

Find the existing `LibrarySidebar(...)` call (lines 26–39). Replace the whole block — and the `.navigationSplitViewColumnWidth` modifier directly underneath — with:

```swift
            LibrarySidebar(
                account: account,
                selection: $selection,
                activeCount: rows.lazy.filter { $0.statusRaw != "done" }.count,
                downloadedCount: rows.lazy.filter { $0.statusRaw == "done" }.count,
                videoCount: smartCount(.videos),
                audioCount: smartCount(.audio),
                recentCount: recentRows.count,
                openAccount: { showAccount = true },
                openSettings: { NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil) },
                addMagnet: {
                    paletteInitialAction = .addMagnet
                    paletteOpen = true
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
```

(`NSApp.sendAction(Selector(("showPreferencesWindow:"))...)` is the same selector AppKit uses for ⌘, in a SwiftUI app — it routes to the existing `Settings { ... }` scene without us touching `SettingsView.swift` or `AppModel.swift`.)

- [ ] **Step 3: Wire `paletteInitialAction` into the palette presentation**

Find the `.sheet(isPresented: $paletteOpen)` block (around line 69–74). Replace it with:

```swift
        .sheet(isPresented: $paletteOpen, onDismiss: { paletteInitialAction = nil }) {
            CommandPalette(
                initialAction: paletteInitialAction,
                onAction: handlePaletteAction,
                onDismiss: { paletteOpen = false }
            )
        }
```

- [ ] **Step 4: Replace `LibrarySidebar` and delete private `AccountChip`**

In the same file, delete everything from `private struct LibrarySidebar: View {` (line 161) through the closing brace of `private struct AccountChip: View { ... }` (line 283 — the line just before `// MARK: - Content`). Replace that whole region with:

```swift
private struct LibrarySidebar: View {
    let account: UserAccount
    @Binding var selection: LibrarySection
    let activeCount: Int
    let downloadedCount: Int
    let videoCount: Int
    let audioCount: Int
    let recentCount: Int
    let openAccount: () -> Void
    let openSettings: () -> Void
    let addMagnet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MinchAccountChip(
                name: account.email ?? "",
                email: account.email,
                planName: account.planName,
                isSubscribed: account.isSubscribed ?? false,
                action: openAccount
            )
            .padding(.top, MinchSpacing.l)
            .padding(.horizontal, MinchSpacing.s)

            Spacer().frame(height: MinchSpacing.m)

            List(selection: $selection) {
                ForEach(LibrarySection.Group.allCases, id: \.self) { group in
                    Section(group.title) {
                        ForEach(LibrarySection.allCases.filter { $0.group == group }) { section in
                            MinchSidebarRow(
                                systemImage: section.systemImage,
                                title: section.title,
                                count: count(for: section),
                                isSelected: selection == section
                            )
                            .tag(section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            MinchSidebarFooter(
                onOpenSettings: openSettings,
                onAdd: addMagnet
            )
        }
        .background(Color.minchSurfaceSidebar)
    }

    private func count(for section: LibrarySection) -> Int {
        switch section {
        case .active: activeCount
        case .downloaded: downloadedCount
        case .videos: videoCount
        case .audio: audioCount
        case .recent: recentCount
        }
    }
}
```

(The deleted private `AccountChip` struct is superseded by `MinchAccountChip`. `MinchUI` is already imported at the top of the file.)

- [ ] **Step 5: Build to confirm green**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 6: Smoke-test in a runnable build**

Run: `swift build` then open `App/Minch.xcodeproj` (or the workspace) and run the app. Verify:
1. Sidebar shows account chip at top with avatar + plan name + email + status dot
2. Two sections render: "Library" (Active, Downloaded) and "Smart Collections" (Videos, Audio, Recent)
3. Selecting a row shows a 3pt gradient bar on the leading edge and tints that row's icon
4. No Refresh or Sign-out button anywhere in the sidebar
5. Bottom row shows gear cog (left) and bolt+plus Add button (right) with a hairline divider above
6. Clicking the gear cog opens Settings (⌘, also works)
7. Clicking the Add button opens the command palette with the "Add magnet…" row pre-selected; pressing Return focuses the magnet input bar in the main pane
8. Clicking the account chip opens AccountView; the new "Sign out" button appears at the bottom and works

If any item fails, fix the offending step before committing.

- [ ] **Step 7: Commit**

```bash
git add App/Minch/LibraryView.swift
git commit -m "feat(App/Minch): rewrite LibrarySidebar to use MinchAccountChip + MinchSidebarFooter"
```

---

## Task 8: Final cleanup pass — confirm no dead refs

**Files:**
- (verification only)

A sweep to catch anything the previous tasks left behind. No code changes expected; if any are needed, treat them as bug fixes in their own commits.

- [ ] **Step 1: Search for any lingering `.settings` references**

Run: `grep -n "LibrarySection.settings\|case .settings" App/Minch/*.swift`

Expected: NO MATCHES. If anything matches, remove the dead reference and commit separately.

- [ ] **Step 2: Search for refresh/sign-out buttons in the sidebar source**

Run: `grep -n 'Button("Refresh"\|Button("Sign out"' App/Minch/LibraryView.swift`

Expected: NO MATCHES in `LibrarySidebar`. (Matches in `AccountView` or elsewhere are fine — only the sidebar should be clean.)

- [ ] **Step 3: Confirm full test suite still green**

Run: `swift test --package-path Packages/MinchUI`

Expected: ALL TESTS PASS — `MinchSidebarRowSelectionTests`, `MinchAccountChipTests`, `MinchSidebarFooterTests`, plus the pre-existing `MinchTransferRow*`, `StatusGlyph*`, `Theme*` suites.

- [ ] **Step 4: Final build check**

Run: `swift build`

Expected: `Build complete!`

- [ ] **Step 5: Verify forbidden files are untouched**

Run: `git diff --stat HEAD~7 HEAD -- App/Minch/AppModel.swift App/Minch/SettingsView.swift Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift`

Expected: NO OUTPUT — none of the forbidden files appear in the diff.

- [ ] **Step 6: No commit** — this task is verification only.
