# Sidebar Redesign — Design Spec

**Date:** 2026-05-27
**Status:** Design approved; ready for plan
**Sub-project of:** Minch macOS UI/UX rebuild
**Builds on:** Design Foundations v2 (2026-05-26), Transfer Card Redesign (2026-05-27)

## Goal

Realign the LibraryView sidebar to PRD §14.2 and Design Foundations v2: replace the current accent-on-every-row pattern with a single tinted active row, drop the in-sidebar Refresh and Sign-out controls, move Settings to a bottom cog and Add to a bottom button, and reshape the top-of-sidebar account block into a quota-free pill that surfaces plan + email + subscription status.

## Scope

**In scope (visual + IA realignment):**
- Active row indicator (leading gradient bar + tinted icon)
- Account chip rework (drop quota, surface plan/email/status)
- Sidebar footer (gear cog + Add button), removing Refresh and Sign-out from the sidebar
- `LibrarySection` enum cleanup (remove `.settings`, rename `.smart` group)
- `CommandPalette` extension to support an "Add mode" entry parameter
- `AccountView` extension to host the relocated Sign-out button
- Sidebar column width enforcement (220pt ideal)

**Explicitly NOT in scope (deferred):**
- LibraryView main-pane redesign (hero header, empty states, inspector)
- Selection model overhaul
- SettingsView changes (file is forbidden this cycle)
- Tags and Trash sidebar sections (PRD-mentioned but not yet wired)
- AccountView visual overhaul beyond the Sign-out button addition

## Constraints

**Forbidden files (user WIP, do not touch):**
- `App/Minch/AppModel.swift`
- `App/Minch/SettingsView.swift`
- `Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift`

**Carryover from session standing rules:**
- Surgical Changes — touch only what this redesign requires; do not refactor adjacent code
- No destructive git ops without explicit user approval; no `--no-verify`; no amends — always new commits
- Never push to remote unless explicitly asked

## Architecture

Three new presentation components in the MinchUI package, one extended component, and a rewritten `LibrarySidebar` in the app target. Wiring stays local to `LibraryView` — no `AppModel` changes. The data model change (`LibrarySection`) is a small enum edit that propagates through existing call sites without API breakage outside the removed `.settings` case.

```
MinchUI (package)
├── MinchSidebarRow.swift      (extend: add isSelected)
├── MinchAccountChip.swift     (new)
└── MinchSidebarFooter.swift   (new)

App/Minch (app target)
├── LibraryView.swift          (rewrite LibrarySidebar; delete private AccountChip; wire new closures)
├── LibrarySection.swift       (remove .settings; rename group title)
├── CommandPalette.swift       (extend: optional initialAction)
└── AccountView.swift          (add Sign-out button + signOut closure)
```

## Component Specs

### 1. `MinchSidebarRow` (extended)

**File:** `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`

**New parameter:** `isSelected: Bool` (defaulted to `false` for backward compatibility on any non-sidebar usage).

**Visual behavior:**

| State | Leading bar | Icon tint |
|---|---|---|
| Unselected | not rendered | `.secondary` |
| Selected | 3pt wide, full row height minus 4pt top/bottom inset, vertical gradient `Color.minchBolt` → `Color.minchCurrent` | `Color.minchCurrent` |

**Animation:** `.snappy(duration: 0.18)` on both the bar's opacity and the icon foreground transition. Per-row opacity is fine; `matchedGeometryEffect` is optional and only worth it if the cross-row transition reads cleaner during dev review.

**Unchanged:** icon width 18pt, `MinchSpacing.s` gap, vertical padding 2pt, count badge styling (capsule, `.minchSurfaceSunken`, `.minchMetadata`, monospaced digit).

### 2. `MinchAccountChip` (new)

**File:** `Packages/MinchUI/Sources/MinchUI/MinchAccountChip.swift`

**Public API:**

```swift
public struct MinchAccountChip: View {
    public init(
        name: String,
        email: String?,
        planName: String,
        isSubscribed: Bool,
        action: @escaping () -> Void
    )
}
```

**Layout:** Pill container, full sidebar width minus 16pt outer inset, `MinchSpacing.s` internal padding.

| Element | Spec |
|---|---|
| Avatar | 28pt circle, Bolt→Current linear gradient (top-leading → bottom-trailing), centered initial letter (uppercased first char of `name`, fallback `"?"` if empty), white text, `.minchBody` bold |
| Plan name | `.minchBody`, primary foreground, single line |
| Email | `.minchMetadata`, `.secondary` foreground, single line, tail truncation |
| Status dot | 6pt circle, top-trailing of avatar, 1pt sidebar-surface stroke (reads as notification dot) |
| Status dot color | Green when `isSubscribed == true`; amber otherwise |

**Interaction:** Whole pill is the hit target. Hover: subtle `.minchSurfaceHover` background fill. Press: dim per existing `MinchButton` convention. Tap fires `action`.

### 3. `MinchSidebarFooter` (new)

**File:** `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift`

**Public API:**

```swift
public struct MinchSidebarFooter: View {
    public init(
        onOpenSettings: @escaping () -> Void,
        onAdd: @escaping () -> Void
    )
}
```

**Layout:** Horizontal row, `MinchSpacing.s` internal padding, height matches one sidebar row.

```
[ ⚙ cog ]                                            [ ⚡+ Add ]
```

Both buttons are 28pt square icon-only `MinchButton` variants with `.secondary` resting tint and `.minchCurrent` hover tint. Cog uses `gearshape`. Add uses `bolt.badge.plus` (fall back to `plus.circle.fill` if the symbol isn't available in the macOS 15 baseline — pick at implementation time, no runtime version branching).

**Separator:** 1pt `.minchSurfaceSunken` hairline above the footer with 8pt horizontal inset.

### 4. `LibrarySidebar` (rewritten in `LibraryView.swift`)

**New signature:**

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
}
```

**Removed parameters:** `isRefreshing`, `refresh`, `signOut`.
**Added parameters:** `openSettings`, `addMagnet`.

**Body structure (top to bottom):**

```
VStack(spacing: 0) {
    MinchAccountChip(...)
        .padding(.top, 16)
        .padding(.horizontal, 8)

    Spacer().frame(height: 12)

    List(selection: $selection) {
        Section("Library") {
            MinchSidebarRow(systemImage: "bolt.fill",   title: "Active",     count: activeCount,    isSelected: selection == .active)
                .tag(LibrarySection.active)
            MinchSidebarRow(systemImage: "tray.full",   title: "Downloaded", count: downloadedCount, isSelected: selection == .downloaded)
                .tag(LibrarySection.downloaded)
        }
        Section("Smart Collections") {
            MinchSidebarRow(systemImage: "film",        title: "Videos",     count: videoCount,     isSelected: selection == .videos)
                .tag(LibrarySection.videos)
            MinchSidebarRow(systemImage: "music.note",  title: "Audio",      count: audioCount,     isSelected: selection == .audio)
                .tag(LibrarySection.audio)
            MinchSidebarRow(systemImage: "clock",       title: "Recent",     count: recentCount,    isSelected: selection == .recent)
                .tag(LibrarySection.recent)
        }
    }
    .listStyle(.sidebar)

    MinchSidebarFooter(onOpenSettings: openSettings, onAdd: addMagnet)
}
.background(Color.minchSurfaceSidebar)
.navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
```

**Deletion:** The private `AccountChip` struct in `LibraryView.swift` is removed; `MinchAccountChip` replaces it.

### 5. `LibrarySection` enum edit

**File:** `App/Minch/LibrarySection.swift`

**Diff:**
- Remove `case settings`
- Remove the `case .settings:` arm from `id`, `title`, `systemImage`, and `group`
- Remove `case system` from the nested `Group` enum
- Remove the `case .system:` arm from `Group.title`
- Change `case .smart: "Smart"` → `case .smart: "Smart Collections"`

**Resulting surface:**
```swift
enum LibrarySection: Hashable, Identifiable, CaseIterable {
    case active, downloaded, videos, audio, recent
    // id, title, systemImage as before, minus .settings
    var group: Group {
        switch self {
        case .active, .downloaded: .library
        case .videos, .audio, .recent: .smart
        }
    }
    enum Group: String, CaseIterable {
        case library, smart
        var title: String {
            switch self {
            case .library: "Library"
            case .smart: "Smart Collections"
            }
        }
    }
}
```

### 6. `CommandPalette` extension

**File:** `App/Minch/CommandPalette.swift`

**Addition:**

```swift
public struct CommandPalette: View {
    let initialAction: Action?       // NEW — defaults to nil
    let onAction: (Action) -> Void
    let onDismiss: () -> Void

    public init(
        initialAction: Action? = nil,
        onAction: @escaping (Action) -> Void,
        onDismiss: @escaping () -> Void
    ) { ... }

    public var body: some View {
        // existing body + .onAppear hook:
        .onAppear {
            if let initialAction, case .addMagnet = initialAction {
                // pre-select the Add Magnet row / focus its input field
            }
        }
    }
}
```

**Behavior:**
- `initialAction: .addMagnet` → palette opens with Add-Magnet pre-selected and the magnet input focused
- `initialAction: nil` (default) → existing behavior preserved
- Existing call sites that don't pass `initialAction` compile and behave unchanged

### 7. `AccountView` Sign-out button

**File:** `App/Minch/AccountView.swift`

**Addition:**
- New stored property: `let signOut: () -> Void`
- New section (or appended to `subscriptionsSection` — pick whichever lands cleaner during implementation) containing a destructive-styled `Button("Sign out", role: .destructive) { signOut() }`
- Parent (`LibraryView`) passes the same sign-out handler it currently routes to the sidebar
- If the codebase already has a confirmation alert pattern for sign-out, reuse it; otherwise invoke directly (match whatever the current sidebar path does — do not introduce a new confirmation flow this cycle)

### 8. `LibraryView` call-site wiring

**File:** `App/Minch/LibraryView.swift`

**State addition:**
```swift
@State private var commandPaletteInitialAction: CommandPalette.Action? = nil
```

**Closure wiring on `LibrarySidebar`:**
- `openAccount: { showingAccount = true }` (existing binding)
- `openSettings: { showingSettings = true }` (existing settings sheet binding)
- `addMagnet: { commandPaletteInitialAction = .addMagnet; showingCommandPalette = true }`

**Palette presentation:** When constructing `CommandPalette`, pass `initialAction: commandPaletteInitialAction`. On dismiss, reset `commandPaletteInitialAction = nil` so subsequent ⌘K opens land on default mode.

**AccountView presentation:** Pass `signOut: { /* existing sign-out handler */ }`.

**Removed wiring:** drop refresh/sign-out bindings from the sidebar invocation. Keyboard shortcuts (⌘,, ⌘N, ⌘K, ⌘R) remain bound where they already are — only sidebar widgetry changes.

## Visual Tokens

All colors and spacing reference existing Design Foundations v2 tokens. No new tokens introduced.

| Token | Use |
|---|---|
| `Color.minchSurfaceSidebar` | Sidebar background |
| `Color.minchSurfaceSunken` | Footer separator, count badge background |
| `Color.minchSurfaceHover` | Account chip hover state |
| `Color.minchBolt` | Avatar gradient start, active bar gradient start |
| `Color.minchCurrent` | Avatar gradient end, active bar gradient end, selected icon, hover icon tint |
| `MinchSpacing.s` | Internal padding for chip and footer |
| `MinchSpacing.xs` | Account chip text vstack spacing |
| `.minchBody` | Plan name, avatar initial |
| `.minchMetadata` | Email, count badge |

## Status Dot Logic

```swift
let isActive = (account.isSubscribed == true)
let dotColor: Color = isActive ? .green : .orange
```

`plan` is informational only; `isSubscribed` is the source of truth for the dot color. PRD §14.2 calls for a quota slot, but `UserAccount` has no quota field — quota is explicitly out of scope for this cycle and revisited if/when TorBox surfaces the data.

## Keyboard Shortcuts

Unchanged. The sidebar redesign is purely visual + IA — shortcut handling continues to live where it does today.

| Shortcut | Action |
|---|---|
| ⌘, | Open Settings sheet (now also triggered by footer cog) |
| ⌘N | Open Command Palette in Add mode (now also triggered by footer Add button) |
| ⌘K | Open Command Palette in default mode |
| ⌘R | Refresh (now the only way; sidebar Refresh button is gone) |

## Testing

**MinchUI package tests (`Packages/MinchUI/Tests/MinchUITests/`):**

- **`MinchSidebarRowTests.swift`** — Extend existing or create:
  - `isSelected: false` → icon resolves to `.secondary`, leading bar absent
  - `isSelected: true` → icon resolves to `.minchCurrent`, bar present with Bolt→Current gradient
  - Count badge hidden when `nil` or `0`; visible with monospaced digit when `> 0`
  - Match whatever inspection pattern existing MinchUI tests use

- **`MinchAccountChipTests.swift`** (new):
  - Status dot green when `isSubscribed == true`
  - Status dot amber when `isSubscribed == false`
  - Status dot amber when `isSubscribed == nil` (defensive default)
  - Email truncates with `lineLimit(1)` applied
  - Avatar initial = uppercased first character of `name`; fallback `"?"` when empty
  - `action` closure fires when chip tapped

- **`MinchSidebarFooterTests.swift`** (new):
  - Both buttons render
  - `onOpenSettings` fires on cog tap
  - `onAdd` fires on Add tap
  - Both buttons render with `.secondary` resting tint

**App target tests (`App/MinchTests/`):**

- **`LibrarySectionTests.swift`** (new or extend):
  - `LibrarySection.allCases == [.active, .downloaded, .videos, .audio, .recent]`
  - `Group.allCases == [.library, .smart]`
  - `Group.smart.title == "Smart Collections"`
  - Group mapping: active/downloaded → `.library`; videos/audio/recent → `.smart`

- **`CommandPaletteTests.swift`** (new if scaffolding exists; otherwise documented for manual check):
  - `initialAction: .addMagnet` → palette opens in Add mode on first appear
  - `initialAction: nil` → palette opens in default mode
  - Dismiss + reopen with `nil` → does not retain previous Add-mode state

**Manual verification (in plan, not automated):**
- Selecting a sidebar row animates leading bar in with snap
- ⌘N opens palette in Add mode; ⌘K opens default mode
- ⌘, and footer cog both open Settings sheet
- Account chip opens AccountView sheet
- AccountView Sign-out button works
- Sidebar resizes within 200–280pt; defaults to 220pt
- No refresh button in sidebar; ⌘R still triggers refresh

**Not tested:**
- Visual fidelity of gradient bar or status dot (no snapshot harness in repo)
- SettingsView contents (forbidden)
- `AppModel.signOut` (forbidden) — only the AccountView button wiring

## Acceptance Criteria

1. Sidebar renders a 3pt Bolt→Current gradient bar on the selected row only; selected icon is tinted `.minchCurrent`; unselected icons use `.secondary`.
2. Account chip shows avatar (gradient + initial), plan name, email (truncated), and a 6pt status dot (green/amber per `isSubscribed`). No quota element.
3. Sidebar footer contains a gear cog (left) and Add button (right). No Refresh, no Sign-out in the sidebar.
4. Add button opens the command palette in Add mode with magnet input focused.
5. `LibrarySection` no longer has a `.settings` case. `Group` no longer has `.system`. `.smart` renders as "Smart Collections".
6. Sidebar column snaps to 220pt ideal width, resizes within 200–280pt.
7. AccountView has a working Sign-out button.
8. All listed unit tests pass; manual verification checklist passes.
9. No changes to `AppModel.swift`, `SettingsView.swift`, or `TorBoxClient.swift`.

## Open Questions Resolved During Brainstorming

- **Quota in account chip:** Dropped. `UserAccount` has no quota field. Revisit only if TorBox surfaces it.
- **Active indicator style:** Leading 3pt gradient bar + tinted icon. Confirmed over alternatives (full-row fill, trailing dot).
- **Add button behavior:** Opens command palette in Add mode (requires palette extension, in scope).
- **Refresh button:** Dropped entirely from sidebar; ⌘R remains the only refresh trigger.
- **Sign-out location:** Moved to AccountView (requires adding the button, in scope).
- **Settings location:** Removed from sidebar list; lives in footer cog. `LibrarySection.settings` case deleted.
- **Icon tint:** `.secondary` for unselected, `.minchCurrent` for selected.
- **Group label:** "Smart Collections" (PRD-aligned).
- **Sidebar width:** 200–280pt range, 220pt ideal.
