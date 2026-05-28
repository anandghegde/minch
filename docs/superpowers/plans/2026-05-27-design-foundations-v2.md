# Design Foundations v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v2 design foundations for `MinchUI` — a 6-step opaque surface ramp, refined typography weights, motion and elevation tokens, and a shared `MinchHoverable` view modifier — and migrate every callsite of removed tokens.

**Architecture:** All foundations live in two files: `Theme.swift` (tokens) and the new `MinchHoverable.swift` (the only shared elevation modifier). `MinchButtonStyle.secondary` is the first consumer of `MinchHoverable`, proving the modifier end-to-end. Every other change in this plan is a token rename or a one-line visual swap explicitly enumerated in the spec — no new abstractions, no scope creep into row/sidebar/toolbar redesigns (those are downstream sub-projects).

**Tech Stack:** Swift 6.0, SwiftUI, swift-testing (the codebase uses `import Testing` with `@Suite`/`@Test`/`#expect`, **not** XCTest). Swift Package Manager workspace; `MinchUI` is a local package under `Packages/MinchUI`.

**Spec:** `docs/superpowers/specs/2026-05-26-design-foundations-v2-design.md`

**Conventions used throughout this plan:**
- `cd Packages/MinchUI && swift build` is the package-level build gate.
- `cd Packages/MinchUI && swift test` runs the swift-testing suite.
- The app target is built via Xcode (`Minch.xcodeproj`). The plan calls out when an Xcode build is also required.
- Don't touch `App/Minch/AppModel.swift`, `App/Minch/SettingsView.swift`, or `Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift` — those have unrelated uncommitted work-in-progress changes belonging to the user.

---

## File Structure

### Created

| File | Responsibility |
|---|---|
| `Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift` | The single shared resting/hover elevation view modifier. Owns background, border, shadow, and hover animation. |

### Modified

| File | Responsibility |
|---|---|
| `Packages/MinchUI/Sources/MinchUI/Theme.swift` | Surface ramp (6 tokens), typography (weight bumps + new `minchMetadata`), `MinchMotion` enum, `MinchElevation` struct. |
| `Packages/MinchUI/Sources/MinchUI/MinchButton.swift` | Replace inline spring with `MinchMotion.snap`; `.secondary` adopts `.minchHoverable()`. |
| `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift` | Resting card background `minchSurfaceSunken` → `minchSurfaceCard`. |
| `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift` | Count-badge font `minchCaption` → `minchMetadata`. |
| `Packages/MinchUI/Tests/MinchUITests/ThemeTests.swift` | Update surface assertions; add `minchMetadata`, `MinchMotion`, `MinchElevation` assertions. |
| `App/Minch/ContentView.swift` | Splash gradient uses surface tokens. |
| `App/Minch/OnboardingView.swift` | Same gradient swap as `ContentView`. |
| `App/Minch/LibraryView.swift` | Content gradient endpoint + sidebar background. |
| `App/Minch/AccountView.swift` | `minchSurfaceElevated` → `minchSurfaceCard` (line 50). |
| `App/Minch/CommandPalette.swift` | `minchSurfaceElevated` → `minchSurfaceOverlay` (line 48). |

### Not touched

`MinchKit`, `MinchAPI`, `MinchPersistence`, `MinchDownloads`, `MinchTesting`, `MenuBarView.swift`, `SettingsView.swift`, `MinchStatusGlyph.swift`, `MinchWordmark.swift`.

---

## Task 1: Extend `Theme.swift` with v2 tokens (TDD)

We expand `Theme.swift` with the 6-step surface ramp, two new typography refinements, and two new value types (`MinchMotion`, `MinchElevation`). We drive the work test-first using swift-testing: update `ThemeTests` to reference the new tokens, watch it fail to compile, then add the tokens.

**Files:**
- Modify: `Packages/MinchUI/Tests/MinchUITests/ThemeTests.swift`
- Modify: `Packages/MinchUI/Sources/MinchUI/Theme.swift`

- [ ] **Step 1: Rewrite `ThemeTests.swift` to assert the v2 token surface**

Open `Packages/MinchUI/Tests/MinchUITests/ThemeTests.swift` and replace the entire file contents with:

```swift
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

    @Test func motionTokensExist() {
        _ = MinchMotion.snap
        _ = MinchMotion.smooth
    }

    @Test func elevationTokensExist() {
        _ = MinchElevation.resting
        _ = MinchElevation.hover
    }
}
```

Notes:
- `Color.minchSurfaceElevated` is intentionally removed from assertions — its existence is what we're eliminating.
- `Font.minchMetadata`, `MinchMotion.*`, `MinchElevation.*` are the new symbols.

- [ ] **Step 2: Run the test suite to verify it fails to compile**

Run:

```bash
cd Packages/MinchUI && swift build --target MinchUITests
```

Expected: **FAIL.** Compiler errors of the form "type 'Color' has no member 'minchSurfaceWindow'" (and similar for the other new tokens). This proves the tests are referencing symbols we haven't added yet.

- [ ] **Step 3: Replace surface tokens in `Theme.swift`**

Open `Packages/MinchUI/Sources/MinchUI/Theme.swift`. Locate the surface-token block (currently lines 24–30):

```swift
    // Surface tokens (PRD §8). Tuned for the near-black translucent palette.
    static let minchSurfacePrimary = Color(white: 0.07)
    static let minchSurfaceElevated = Color(white: 0.10)
    static let minchSurfaceSunken = Color.white.opacity(0.04)
    static let minchHairline = Color.white.opacity(0.06)
    static let minchSelection = Color.minchBolt.opacity(0.18)
```

Replace that block (the comment line plus the five `static let` lines) with:

```swift
    // Surface ramp (v2 — opaque z-stack from window to overlay).
    static let minchSurfaceWindow     = Color(white: 0.05)
    static let minchSurfaceSidebar    = Color(white: 0.06)
    static let minchSurfacePrimary    = Color(white: 0.08)
    static let minchSurfaceCard       = Color(white: 0.10)
    static let minchSurfaceCardHover  = Color(white: 0.13)
    static let minchSurfaceOverlay    = Color(white: 0.14)

    static let minchSurfaceSunken     = Color.white.opacity(0.04)
    static let minchHairline          = Color.white.opacity(0.06)
    static let minchSelection         = Color.minchBolt.opacity(0.18)
```

Key changes vs. before: `minchSurfaceElevated` is gone; `minchSurfacePrimary` shifts from `0.07` to `0.08`; the four new ramp tokens land between window and overlay; `minchSurfaceSunken`/`minchHairline`/`minchSelection` are unchanged.

- [ ] **Step 4: Bump Display/Title weights and add `minchMetadata`**

Still in `Theme.swift`, locate the Font extension block (currently lines 41–48):

```swift
public extension Font {
    static let minchDisplay = Font.system(size: 28, weight: .semibold)
    static let minchTitle = Font.system(size: 20, weight: .semibold)
    static let minchHeadline = Font.system(size: 15, weight: .semibold)
    static let minchBody = Font.system(size: 13, weight: .regular)
    static let minchCallout = Font.system(size: 12, weight: .regular)
    static let minchCaption = Font.system(size: 11, weight: .regular)
    static let minchMono = Font.system(size: 12, weight: .regular, design: .monospaced)
}
```

Replace it with:

```swift
public extension Font {
    static let minchDisplay   = Font.system(size: 28, weight: .bold)
    static let minchTitle     = Font.system(size: 20, weight: .bold)
    static let minchHeadline  = Font.system(size: 15, weight: .semibold)
    static let minchBody      = Font.system(size: 13, weight: .regular)
    static let minchMetadata  = Font.system(size: 11, weight: .medium)
    static let minchCallout   = Font.system(size: 12, weight: .regular)
    static let minchCaption   = Font.system(size: 11, weight: .regular)
    static let minchMono      = Font.system(size: 12, weight: .regular, design: .monospaced)
}
```

Changes: `minchDisplay` and `minchTitle` weight `.semibold` → `.bold`; `minchMetadata` is newly added.

- [ ] **Step 5: Append `MinchMotion` and `MinchElevation` to `Theme.swift`**

At the **end** of `Theme.swift` (after the closing `}` of the Font extension), append:

```swift

public enum MinchMotion {
    public static let snap: Animation   = .snappy(duration: 0.20, extraBounce: 0)
    public static let smooth: Animation = .smooth(duration: 0.30, extraBounce: 0)
}

public struct MinchElevation: Sendable {
    public let background: Color
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowY: CGFloat
}

public extension MinchElevation {
    static let resting = MinchElevation(
        background: .minchSurfaceCard,
        borderColor: .minchHairline,
        borderWidth: 1,
        shadowColor: .clear,
        shadowRadius: 0,
        shadowY: 0
    )

    static let hover = MinchElevation(
        background: .minchSurfaceCardHover,
        borderColor: Color.white.opacity(0.10),
        borderWidth: 1,
        shadowColor: Color.black.opacity(0.18),
        shadowRadius: 6,
        shadowY: 1
    )
}
```

- [ ] **Step 6: Build the package**

Run:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.** The only source-side `minchSurfaceElevated` reference inside the MinchUI package was `Theme.swift:27`, which we removed in Step 3. The remaining `minchSurfaceElevated` references in `App/Minch/*` are in the app target, not the package, so they don't gate this build. (Task 6 cleans those up before the app target is built.)

If unrelated errors appear: fix them strictly per spec; do not add new design behavior.

- [ ] **Step 7: Run tests**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS.** All five `@Test` functions in `ThemeTests` should now succeed: spacing, radius, surface ramp, typography, motion, elevation.

- [ ] **Step 8: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/Theme.swift \
        Packages/MinchUI/Tests/MinchUITests/ThemeTests.swift
git commit -m "feat(MinchUI): extend Theme with v2 tokens

Replace the 4 surface tokens with a 6-step opaque ramp
(window/sidebar/primary/card/cardHover/overlay). Bump
Display/Title to .bold and add minchMetadata. Add MinchMotion
enum (.snap, .smooth) and MinchElevation struct with .resting
and .hover. Tests cover token existence."
```

---

## Task 2: Add the `MinchHoverable` view modifier

Create the single shared elevation modifier. It owns background fill, border, shadow, and the hover animation; consumers own padding and layout. We verify the modifier compiles and runs in a Preview-style call site; behavior is asserted by Task 3 wiring it into `MinchButton.secondary`.

**Files:**
- Create: `Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift`

- [ ] **Step 1: Create the file with the modifier and `View` extension**

Write the new file `Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift` with exactly these contents:

```swift
import SwiftUI

/// Applies the v2 resting/hover elevation treatment.
///
/// Owns: background fill, border, shadow, hover animation.
/// Consumers own: padding, content layout, foreground/text styling, and
/// anything else that isn't part of the elevation surface. Don't paint your
/// own background or border on top of this modifier — they'll either layer
/// awkwardly or hide the hover transition.
public struct MinchHoverableModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false

    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = MinchRadius.m) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let elevation: MinchElevation = isHovered ? .hover : .resting
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background(shape.fill(elevation.background))
            .overlay(shape.strokeBorder(elevation.borderColor, lineWidth: elevation.borderWidth))
            .shadow(color: elevation.shadowColor, radius: elevation.shadowRadius, y: elevation.shadowY)
            .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

public extension View {
    /// Applies the shared resting/hover elevation treatment.
    /// Consumers must not paint their own background or border on top of this.
    func minchHoverable(cornerRadius: CGFloat = MinchRadius.m) -> some View {
        modifier(MinchHoverableModifier(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: Build the package**

Run:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.** The file references only tokens added in Task 1 (`MinchRadius.m`, `MinchElevation.resting/hover`, `MinchMotion.snap`).

- [ ] **Step 3: Run the test suite (regression gate)**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS** — all Task 1 tests continue to pass; nothing new broken.

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift
git commit -m "feat(MinchUI): add MinchHoverable view modifier

Single shared resting/hover elevation treatment. Owns background,
border, shadow, and hover animation; consumers own padding and
content. Honors reduce-motion."
```

---

## Task 3: Adopt motion token and `MinchHoverable` in `MinchButton`

Replace the inline spring animation with `MinchMotion.snap`, and switch `.secondary` from a flat opacity background to the shared hoverable treatment. `.primary`, `.ghost`, and `.destructive` retain their existing look — only the animation token reference changes.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchButton.swift`

- [ ] **Step 1: Rewrite `MinchButton.swift`**

Open `Packages/MinchUI/Sources/MinchUI/MinchButton.swift` and replace the entire file with:

```swift
import SwiftUI

public struct MinchButtonStyle: ButtonStyle {
    public enum Variant: Sendable { case primary, secondary, ghost, destructive }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let variant: Variant
    public init(_ variant: Variant = .primary) { self.variant = variant }

    public func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.minchHeadline)
            .padding(.horizontal, MinchSpacing.m)
            .padding(.vertical, MinchSpacing.s)
            .foregroundStyle(foreground)

        return Group {
            switch variant {
            case .secondary:
                // Hoverable owns background, border, shadow, and clipping shape.
                label.minchHoverable()
            case .primary, .ghost, .destructive:
                label
                    .background(background(pressed: configuration.isPressed))
                    .clipShape(RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous))
            }
        }
        .opacity(configuration.isPressed ? 0.85 : 1.0)
        .animation(reduceMotion ? nil : MinchMotion.snap, value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [.minchBolt, .minchCurrent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            // Unused — .secondary goes through the .minchHoverable() branch
            // in makeBody — but the switch needs an exhaustive case.
            Color.clear
        case .ghost:
            Color.clear
        case .destructive:
            Color.minchDanger.opacity(0.85)
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive: .white
        case .secondary, .ghost: .primary
        }
    }
}

public extension ButtonStyle where Self == MinchButtonStyle {
    static func minch(_ variant: MinchButtonStyle.Variant = .primary) -> MinchButtonStyle {
        MinchButtonStyle(variant)
    }
}
```

Key changes vs. before:
- The inline `.spring(response: 0.25, dampingFraction: 0.85)` is replaced with `MinchMotion.snap`.
- `makeBody` branches on `variant`: `.secondary` applies `.minchHoverable()` to the label (which owns the rounded-rect shape, fill, border, shadow). The other variants keep their existing background-then-clipShape chain.
- `foregroundStyle` moves up onto the label so both branches share it.
- `background(pressed:)`'s `.secondary` case is now a dead branch (the switch still needs it for exhaustiveness); the comment marks it explicitly.

- [ ] **Step 2: Build the package**

Run:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.**

- [ ] **Step 3: Run the test suite**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS.**

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchButton.swift
git commit -m "refactor(MinchUI): MinchButton adopts MinchMotion + MinchHoverable

Replace inline spring with MinchMotion.snap. .secondary variant
switches from a flat opacity background to the shared
.minchHoverable() treatment. Primary/ghost/destructive look
unchanged; animation now references the motion token."
```

---

## Task 4: Flip `MinchTransferRow` resting background to `minchSurfaceCard`

The only intentional visible change in this spec. Rows currently fill with `minchSurfaceSunken` (inset semantic); the row-redesign sub-project will rebuild this view in full, but for now we semantically correct the resting surface so the v2 ramp reads correctly.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`

- [ ] **Step 1: Update the row's resting background fill**

In `Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`, locate the `.background(...)` modifier on the outer `Button`:

```swift
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .fill(Color.minchSurfaceSunken)
        )
```

Replace `Color.minchSurfaceSunken` with `Color.minchSurfaceCard`:

```swift
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .fill(Color.minchSurfaceCard)
        )
```

Do **not** touch the `.overlay(...)` (still uses `Color.minchHairline`) or any other surface in this file. The `MinchTransferRow` Preview's outer `.background(Color.minchSurfacePrimary)` also stays — primary is the content-area surface that rows sit on, which is correct.

- [ ] **Step 2: Build the package**

Run:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.**

- [ ] **Step 3: Run the test suite**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS** — `TransferRowTests` exercise formatting helpers, not visuals, so this change is invisible to tests.

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift
git commit -m "refactor(MinchUI): MinchTransferRow rests on minchSurfaceCard

Rows are cards on a darker content surface, not insets. The
row-redesign sub-project will rebuild this view in full."
```

---

## Task 5: Promote `MinchSidebarRow` count badge to `minchMetadata`

Smallest-blast-radius validation that `minchMetadata` reads better than `minchCaption` for numeric metadata. The sidebar redesign sub-project will own broader sidebar typography work.

**Files:**
- Modify: `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`

- [ ] **Step 1: Update the count Text font**

In `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`, locate the count badge:

```swift
            if let count, count > 0 {
                Text("\(count)")
                    .font(.minchCaption)
                    .monospacedDigit()
```

Change `.font(.minchCaption)` to `.font(.minchMetadata)`:

```swift
            if let count, count > 0 {
                Text("\(count)")
                    .font(.minchMetadata)
                    .monospacedDigit()
```

Do **not** touch the row's main `Text(title).font(.minchBody)`, the `Image(systemName:).font(.minchBody)`, or the Preview's surface references — all unchanged in this spec.

- [ ] **Step 2: Build the package**

Run:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.**

- [ ] **Step 3: Run the test suite**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS.**

- [ ] **Step 4: Commit**

```bash
git add Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift
git commit -m "refactor(MinchUI): sidebar count badge uses minchMetadata

Promote count badge typography one step so numbers read more
authoritative. Sidebar redesign sub-project owns broader work."
```

---

## Task 6: Migrate `App/Minch` callsites off removed tokens

Five files in the app target reference the removed `minchSurfaceElevated` token or the hand-rolled splash gradient. Migrate all of them in one task so the app target builds cleanly at the end.

**Files:**
- Modify: `App/Minch/ContentView.swift`
- Modify: `App/Minch/OnboardingView.swift`
- Modify: `App/Minch/LibraryView.swift`
- Modify: `App/Minch/AccountView.swift`
- Modify: `App/Minch/CommandPalette.swift`

- [ ] **Step 1: Update `ContentView.swift` — splash gradient**

In `App/Minch/ContentView.swift`, locate the `SplashView` body:

```swift
private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.06), Color(white: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
```

Replace the `colors:` array with surface tokens:

```swift
private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfaceWindow, Color.minchSurfacePrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
```

- [ ] **Step 2: Update `OnboardingView.swift` — same gradient swap**

In `App/Minch/OnboardingView.swift`, locate the top `ZStack`'s gradient:

```swift
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.06), Color(white: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSaf…
```

Replace the `colors:` array the same way:

```swift
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfaceWindow, Color.minchSurfacePrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
```

Do **not** touch the API-key `SecureField` background (`Color.white.opacity(0.06)`) elsewhere in this file — it's an explicit one-off, not a token reference. Inset-field rework belongs to a future onboarding/forms sub-project.

- [ ] **Step 3: Update `LibraryView.swift` — content gradient endpoint**

In `App/Minch/LibraryView.swift`, locate the `LibraryContent` body (around line 296):

```swift
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfacePrimary, Color.minchSurfaceElevated],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
```

Change `Color.minchSurfaceElevated` to `Color.minchSurfaceCard`:

```swift
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfacePrimary, Color.minchSurfaceCard],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
```

- [ ] **Step 4: Update `LibraryView.swift` — sidebar background**

Still in `App/Minch/LibraryView.swift`, locate the `LibrarySidebar` struct's body. It begins with:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openAccount) {
                AccountChip(account: account)
            }
```

After the closing brace of that root `VStack` (i.e., before the next `.something` modifier on the VStack, or directly on the VStack itself if it has no modifiers), add `.background(Color.minchSurfaceSidebar)`. Concretely, the LibrarySidebar body root looks like:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // … existing children …
        }
        // any existing VStack modifiers go here
    }
```

Apply the background as the **last** modifier on that VStack so it sits beneath any existing modifiers but on top of the inherited window background:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // … existing children unchanged …
        }
        // … any existing modifiers unchanged …
        .background(Color.minchSurfaceSidebar)
    }
```

This is the only structural addition in `LibraryView.swift` — everything else is a token rename. If you're uncertain where existing modifiers end, search for the next `private struct ` in the file: the VStack and its modifiers are everything above that next struct boundary inside `LibrarySidebar.body`.

- [ ] **Step 5: Update `AccountView.swift` line 50**

In `App/Minch/AccountView.swift`, line 50 sits inside the account-sheet container modifier chain and currently reads:

```swift
        .background(Color.minchSurfaceElevated)
```

Replace it with:

```swift
        .background(Color.minchSurfaceCard)
```

Semantic: this is a card-like surface inside the account sheet. (The `subscriptionRow` ViewBuilder elsewhere in the file uses `Color.minchSurfaceSunken` — leave that alone.)

- [ ] **Step 6: Update `CommandPalette.swift` line 48**

In `App/Minch/CommandPalette.swift`, the palette's outermost VStack has:

```swift
        .frame(width: 560, height: 420)
        .background(Color.minchSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.l)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
```

Replace `Color.minchSurfaceElevated` with `Color.minchSurfaceOverlay` (palettes are overlays, not cards):

```swift
        .frame(width: 560, height: 420)
        .background(Color.minchSurfaceOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.l)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
```

- [ ] **Step 7: Confirm no stale `minchSurfaceElevated` references remain**

Run:

```bash
grep -rn "minchSurfaceElevated" Packages App
```

Expected: **no matches** (binary `.build/` files don't count; if grep shows them, rebuild later picks them up — they're not source).

If any source-file match remains, fix it before continuing using the same Card-vs-Overlay heuristic from the spec (card-like → `minchSurfaceCard`; modal/overlay-like → `minchSurfaceOverlay`).

- [ ] **Step 8: Build the package and the app target**

Run the package build:

```bash
cd Packages/MinchUI && swift build
```

Expected: **PASS.**

Then build the app target from Xcode:

```bash
cd /Users/ahegde/projects/minch && xcodebuild -project Minch.xcodeproj -scheme Minch -configuration Debug build
```

Expected: **PASS.** No unresolved symbol errors for `minchSurfaceElevated`.

If the `xcodebuild` invocation fails for environment reasons (missing simulators, signing), open `Minch.xcodeproj` in Xcode and `⌘B` instead — the only thing we need verified is that the app target compiles.

- [ ] **Step 9: Run tests one final time**

Run:

```bash
cd Packages/MinchUI && swift test
```

Expected: **PASS.**

- [ ] **Step 10: Commit**

```bash
git add App/Minch/ContentView.swift \
        App/Minch/OnboardingView.swift \
        App/Minch/LibraryView.swift \
        App/Minch/AccountView.swift \
        App/Minch/CommandPalette.swift
git commit -m "refactor(App): migrate callsites off minchSurfaceElevated

Splash and onboarding gradients reference surface tokens.
LibraryContent gradient endpoint moves from elevated → card.
LibrarySidebar gets an explicit minchSurfaceSidebar background.
AccountView's card surface → card; CommandPalette → overlay."
```

---

## Task 7: Manual visual verification

The success criteria in the spec list six visual checks that no automated test can prove. Run them once with the built app open.

**Files:**
- None modified — read-only verification.

- [ ] **Step 1: Launch the app**

In Xcode, open `Minch.xcodeproj`, select the `Minch` scheme, and `⌘R`. Or run the built binary directly if you prefer.

- [ ] **Step 2: Splash gradient — verify**

If the app boots into the splash (briefly visible during `validating`), confirm the gradient is dark and reads top→bottom as `minchSurfaceWindow → minchSurfacePrimary` (subtle vertical lightening, no banding). If signed in, sign out first to see it again on next launch.

Expected: clean opaque gradient, no white flash, wordmark + ProgressView centered.

- [ ] **Step 3: Onboarding gradient — verify**

Sign out (or use a fresh keychain) to land on `OnboardingView`. Same gradient as splash should be visible behind the content.

Expected: identical gradient to splash; API-key `SecureField` retains its existing one-off inset look.

- [ ] **Step 4: Sidebar reads as its own surface — verify**

Sign back in. The library window should show two visibly-distinct surfaces side-by-side: sidebar (slightly darker — `minchSurfaceSidebar` at 0.06) and main content area (gradient `minchSurfacePrimary → minchSurfaceCard`, 0.08 → 0.10).

Expected: a visible seam between the two columns. If the sidebar reads as a continuation of the window, the `.background(Color.minchSurfaceSidebar)` in Task 6 step 4 didn't apply — double-check it was added to the LibrarySidebar root VStack and not nested deeper.

- [ ] **Step 5: Transfer rows read as cards — verify**

In the active/downloaded sections, transfer rows should appear as cards slightly raised above the surrounding content surface (card 0.10 on primary 0.08, ~2% lighter). They should not look inset.

Expected: subtle but perceptible elevation. The row-redesign sub-project will dial this further; for now we just need it to read as a card, not a well.

- [ ] **Step 6: Secondary button hover — verify**

Find a `.minch(.secondary)` button (e.g., the "Retry" button on the `ErrorBanner` in `LibraryView`; trigger an error to surface it, or use a SwiftUI Preview). Hover the cursor over it.

Expected: smooth ~200ms transition from resting (card bg, hairline border, no shadow) to hover (cardHover bg ~0.13, slightly brighter border, subtle shadow). The animation should feel "snap" — not bouncy, not laggy.

Test reduce-motion: System Settings → Accessibility → Display → Reduce Motion → on. Hover again. The state change should be instant (no animation).

- [ ] **Step 7: Primary buttons retain Bolt→Current gradient — verify**

Find a `.minch()` (default `.primary`) button. Confirm it still shows the diagonal `minchBolt → minchCurrent` gradient with white text. No regression.

- [ ] **Step 8: If any check fails, fix and re-commit**

If any visual check fails:
1. Identify the file that owns the surface in question.
2. Verify it's using the right token per the spec's §6 table.
3. Re-commit only the corrected file with `git commit -m "fix(...): correct <surface> token"`.

Do **not** introduce visuals beyond what the spec calls out. The row-redesign, sidebar-refinement, and add-flow sub-projects are explicitly out of scope.

- [ ] **Step 9: Final smoke build/test**

```bash
cd Packages/MinchUI && swift build && swift test
```

Expected: clean build, all tests pass.

---

## Done

When all seven tasks are complete and all checkboxes are checked:

- `Theme.swift` exposes a 6-step surface ramp, bolder Display/Title weights, `minchMetadata`, `MinchMotion`, and `MinchElevation`.
- `MinchHoverable.swift` ships the single shared elevation modifier.
- `MinchButton.secondary` adopts it; `.primary`/`.ghost`/`.destructive` look unchanged.
- `MinchTransferRow` and `MinchSidebarRow` have their spec'd token swaps.
- Every callsite of the removed `minchSurfaceElevated` token in `App/Minch` is migrated.
- `swift build` and `swift test` pass; the six manual visual checks pass.

Next sub-project (do not start without explicit user confirmation): **Global Add flow** — toolbar Add button, Quick Add modal, ⌘N, clipboard detection.
