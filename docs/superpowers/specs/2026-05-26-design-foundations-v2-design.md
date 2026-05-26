# Design Foundations v2 — Spec

**Date:** 2026-05-26
**Package:** `MinchUI`
**Status:** Ready for implementation planning
**Parent initiative:** Minch macOS UI/UX redesign (first of ~7 sub-projects)

---

## 1. Purpose

Refresh Minch's design tokens to support the broader redesign downstream
(global Add flow, row redesign, sidebar refinement, etc). This spec ships
*foundations only* — tokens and one shared view modifier. Visible
surfaces (rows, sidebar, toolbar, modals) are redesigned in their own
sub-projects against the v2 foundations.

## 2. Direction (locked answers)

| Decision | Choice |
|---|---|
| Translucency | Stay opaque; add depth via layering |
| Accent deployment | Solid accent everywhere, Bolt→Current gradient only for primary actions |
| Typography ambition | Refine weights, keep scale |
| Motion structure | 2 named curves (`.snap`, `.smooth`) |
| Hover/elevation | 2 states (resting + hover), one shared modifier |
| Surface ramp | 6-step opaque ramp (window → overlay) |
| Migration | Hard replace, migrate every callsite in this spec |
| Code structure | Expand existing `Theme.swift` + add one file (`MinchHoverable.swift`) |

## 3. Scope

### In scope

- Refine `Packages/MinchUI/Sources/MinchUI/Theme.swift`: surface tokens,
  typography weights, motion tokens, elevation tokens.
- Add `Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift` — shared
  hover view modifier.
- Update `MinchButtonStyle` to consume motion tokens and adopt
  `MinchHoverable` on the `.secondary` variant.
- Rename pass across every callsite of removed/renamed surface tokens in
  `Packages/MinchUI` and `App/Minch`. No visual logic changes in those
  files beyond the documented exceptions in §6.

### Explicitly out of scope (downstream sub-projects own these)

- Global toolbar / Add button.
- `MinchTransferRow` visual redesign (taller cards, hover actions,
  progress shimmer).
- `LibrarySidebar` width/typography/active-indicator rework.
- New `SearchBar` / `ContentHeader` / empty-state visuals.
- Settings redesign, mini activity player.

## 4. Surface ramp

Replace the 4 surface tokens with 6 opaque-white tokens forming a z-stack.
`minchSurfaceSunken`, `minchHairline`, `minchSelection` are unchanged.

```
minchSurfaceWindow     = Color(white: 0.05)   // window bg, splash, onboarding
minchSurfaceSidebar    = Color(white: 0.06)   // sidebar column
minchSurfacePrimary    = Color(white: 0.08)   // main content area
minchSurfaceCard       = Color(white: 0.10)   // resting cards / rows
minchSurfaceCardHover  = Color(white: 0.13)   // hover state for cards
minchSurfaceOverlay    = Color(white: 0.14)   // modal/sheet/popover bg

minchSurfaceSunken     = Color.white.opacity(0.04)  // unchanged — inset fields
minchHairline          = Color.white.opacity(0.06)  // unchanged — borders/dividers
minchSelection         = Color.minchBolt.opacity(0.18)  // unchanged
```

**Removed:** `minchSurfaceElevated`. Migration map for its callsites is in §6.

## 5. Typography, motion, elevation tokens

### Typography — refine weights, keep scale

```swift
public extension Font {
    static let minchDisplay   = Font.system(size: 28, weight: .bold)        // was .semibold
    static let minchTitle     = Font.system(size: 20, weight: .bold)        // was .semibold
    static let minchHeadline  = Font.system(size: 15, weight: .semibold)    // unchanged
    static let minchBody      = Font.system(size: 13, weight: .regular)     // unchanged
    static let minchMetadata  = Font.system(size: 11, weight: .medium)      // NEW
    static let minchCallout   = Font.system(size: 12, weight: .regular)     // unchanged
    static let minchCaption   = Font.system(size: 11, weight: .regular)     // unchanged
    static let minchMono      = Font.system(size: 12, weight: .regular, design: .monospaced) // unchanged
}
```

`minchMetadata` is the only new token. macOS auto-selects SF Pro Display
for ≥20pt sizes and SF Pro Text below, so the brief's "Display for
headings, Text for metadata" requirement is satisfied implicitly.

### Motion — 2 named curves

```swift
public enum MinchMotion {
    public static let snap: Animation   = .snappy(duration: 0.20, extraBounce: 0)
    public static let smooth: Animation = .smooth(duration: 0.30, extraBounce: 0)
}
```

- `MinchMotion.snap` — interactive state changes (hover, press,
  selection highlight, button color).
- `MinchMotion.smooth` — layout/presentation (sheet appearance, sidebar
  collapse, row insertion/removal).

`extraBounce: 0` enforces the no-bouncy rule. Reduce-Motion handling
stays at the component level via `@Environment(\.accessibilityReduceMotion)`.

### Elevation — declarative struct with 2 states

```swift
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

A struct (not just colors) so the modifier applies all six fields in
one go.

## 6. `MinchHoverable` view modifier

New file: `Packages/MinchUI/Sources/MinchUI/MinchHoverable.swift`.

```swift
import SwiftUI

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

**Boundary contract:** the modifier owns background fill, border,
shadow, and the hover animation. The consumer owns padding, content
layout, and any non-elevation visuals. Documented in the doc-comment.

**Adoption in this spec:** wired into `MinchButton`'s `.secondary` variant
only — proves the modifier works end-to-end without disturbing the
`.primary` variant's reserved Bolt→Current gradient. Rows, sidebar items,
and hover-action chips adopt it in their own redesign sub-projects.

## 7. File-by-file changes

### Modified — `MinchUI`

**`Theme.swift`**
- Replace 4 surface color tokens with the 6-step ramp (§4). Remove
  `minchSurfaceElevated`.
- Bump `minchDisplay`/`minchTitle` weight to `.bold`. Add `minchMetadata`.
- Add `MinchMotion` enum.
- Add `MinchElevation` struct with `.resting`/`.hover`.

**`MinchButton.swift`**
- Replace inline `.spring(response: 0.25, dampingFraction: 0.85)` with
  `MinchMotion.snap`.
- `.secondary` variant: drop `Color.secondary.opacity(0.15)` background;
  apply `.minchHoverable()` to the label instead.
- `.primary`, `.ghost`, `.destructive` look unchanged; animation now
  references the token.

**`MinchTransferRow.swift`**
- Resting background `minchSurfaceSunken` → `minchSurfaceCard`.
  *(Only intentional visual change in this spec — rows are cards on a
  darker content surface, which is the right semantic. Row-redesign
  sub-project rebuilds this view in full.)*

**`MinchSidebarRow.swift`**
- Count-badge font `.minchCaption` → `.minchMetadata` so counts read
  more authoritative. Smallest justifiable upgrade in this spec to
  validate the new typography token; sidebar redesign owns broader work.
- Preview-only token references still resolve (no rename in preview body).

**`MinchStatusGlyph.swift`**, **`MinchWordmark.swift`**
- No code changes. Listed for grep completeness.

### Modified — `App/Minch`

**`ContentView.swift`**
- `SplashView` gradient `[Color(white: 0.06), Color(white: 0.10)]` →
  `[Color.minchSurfaceWindow, Color.minchSurfacePrimary]`.

**`OnboardingView.swift`**
- Same gradient swap as `ContentView`.
- API-key `SecureField` background `Color.white.opacity(0.06)` stays —
  it's an explicit one-off, not a token reference. Inset-field rework
  belongs with an onboarding/forms sub-project.

**`LibraryView.swift`**
- `LibraryContent` background gradient
  `[minchSurfacePrimary, minchSurfaceElevated]` →
  `[minchSurfacePrimary, minchSurfaceCard]`.
- Add `.background(Color.minchSurfaceSidebar)` on `LibrarySidebar`'s root
  `VStack` so the sidebar reads as its own surface (currently inherits
  the window bg).
- Audit and fix any other `minchSurfaceElevated` references.

**`MenuBarView.swift`**, **`AccountView.swift`**, **`SettingsView.swift`**, **`CommandPalette.swift`**
- Confirmed callsites:
  - `AccountView.swift:50` — `.background(Color.minchSurfaceElevated)` → `.background(Color.minchSurfaceCard)` (it's a card-like surface inside the account sheet).
  - `CommandPalette.swift:48` — `.background(Color.minchSurfaceElevated)` → `.background(Color.minchSurfaceOverlay)` (palette is an overlay, not a card).
  - `MenuBarView.swift`, `SettingsView.swift` — no `minchSurfaceElevated` callsites found; included for completeness.

### Modified — `MinchUI` tests

**`Packages/MinchUI/Tests/MinchUITests/ThemeTests.swift`**
- Line 22 references `Color.minchSurfaceElevated`. Replace with references to the new tokens (`minchSurfaceWindow`, `minchSurfaceSidebar`, `minchSurfaceCard`, `minchSurfaceCardHover`, `minchSurfaceOverlay`) and add token-existence assertions for `Font.minchMetadata`, `MinchMotion.snap`, `MinchMotion.smooth`, `MinchElevation.resting`, `MinchElevation.hover`.

### Not touched

`MinchKit`, `MinchAPI`, `MinchPersistence`, `MinchDownloads`,
`MinchTesting` — none import `MinchUI`.

## 8. Success criteria

1. `swift build` succeeds.
2. `swift test` passes — no behavioral regressions.
3. `Theme.swift` exposes one `MinchMotion` enum with `.snap` and
   `.smooth`, and is the only place those values live.
4. `MinchButtonStyle` no longer inlines a spring.
5. `MinchHoverable` modifier is in place and `MinchButton`'s `.secondary`
   variant uses it.
6. Manual visual check passes:
   1. Splash gradient renders correctly.
   2. Onboarding gradient renders correctly.
   3. Library sidebar reads as its own surface, distinct from main
      content.
   4. Transfer rows read as cards (slightly elevated), not insets.
   5. Secondary buttons hover smoothly (subtle bg/border/shadow change
      animated with `.snap`).
   6. Primary buttons retain Bolt→Current gradient identity.

## 9. Risk

| Risk | Mitigation |
|---|---|
| `MinchTransferRow` background flip changes visible appearance before the row-redesign sub-project runs | Accepted — semantically correct, and the row redesign owns this surface next |
| Token rename misses a callsite | Grep gate during implementation; `swift build` will catch any unresolved `minchSurfaceElevated` |
| `.minchHoverable()` paints over a consumer that already has a background | Only adopted on `MinchButton.secondary` in this spec; doc-comment makes the contract explicit |

No public API breakage in any package — only token renames internal to
`MinchUI`, and downstream consumers compile against the new names.

## 10. Next sub-projects (for context, not scope here)

Order, smallest blast radius first / primary action soonest:

1. **Global Add flow** — toolbar Add button, Quick Add modal, ⌘N,
   clipboard detection.
2. **Torrent row redesign** — taller cards, hover actions, progress
   shimmer; consumes `MinchHoverable`.
3. **Sidebar refinement** — narrower, animated active indicator,
   refined typography.
4. **Toolbar status + Search + empty states.**
5. **Settings redesign.**
6. **Mini activity player.**
