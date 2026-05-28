# Remove sidebar; merge Settings + API key into Account sheet

**Date:** 2026-05-28
**Status:** Draft

## Problem

`LibraryView` ships with a `NavigationSplitView` whose left column carries:

1. A `MinchAccountChip` (opens the Account sheet).
2. A two-section `List` of `LibrarySection` rows (Active/Downloaded + Smart Collections Videos/Audio/Recent).
3. A `MinchSidebarFooter` with a Settings gear and an Add (+) button.

The sidebar's only job is filter selection plus three discoverability shortcuts (account, settings, add). All three already have shortcuts elsewhere:

- Account button can sit in the main header.
- Add is keyboard-driven (`⌘N`) and the magnet bar is always visible in the main pane.
- Settings is four TorBox preference toggles — power-user surface, doesn't earn a top-level destination.

Filtering is a single horizontal axis (one selection at a time). A vertical sidebar is heavy for that.

## Goals

- Single-column layout. No `NavigationSplitView`.
- Filters expressed as a pill bar above the search field.
- Account button in the main header opens the existing Account sheet.
- Account sheet absorbs `SettingsView` (renamed "Preferences" section) and gains a "TorBox API key" control inside its Session section.
- Sign-out flow unchanged.
- No regressions in keyboard shortcuts (`⌘N`, `⌘R`, `⌘K`) or external magnet ingestion.

## Non-goals

- Reworking the transfer list, add-magnet bar, search behavior, or playback.
- Adding multi-account support.
- Changing the set of exposed TorBox preferences.
- Refactoring `MinchUI` beyond removing now-unused views.

## UX

### Main window (replaces `NavigationSplitView`)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Library  4                                              [⚡ user]   │
├─────────────────────────────────────────────────────────────────────┤
│  [● Active 4]  [Downloaded 12]  [Videos 3]  [Audio 1]  [Recent 7]   │
├─────────────────────────────────────────────────────────────────────┤
│  🔍  Search transfers, files, tags…                                  │
├─────────────────────────────────────────────────────────────────────┤
│  🔗  Paste a magnet or download link…           [📄] [🌐] [⚙] [Add]  │
├─────────────────────────────────────────────────────────────────────┤
│  …banners + transfer list…                                           │
└─────────────────────────────────────────────────────────────────────┘
```

- **Header:** title becomes the currently selected filter's name (`selection.title`). The count badge keeps showing the filtered row count. The account button sits at the trailing edge, opens the Account sheet.
- **Filter pills:** horizontal row, scrollable if the window is narrow. Each pill = `title + count`. Selected pill uses `Color.minchBolt` background; unselected uses `Color.minchSurfaceSunken` with `Color.minchHairline` stroke. No icons — keeps the bar dense and consistent with the rest of the toolbar styling.
- **Search bar, add-magnet bar, banners, list:** unchanged.

### Account sheet (extends existing `AccountView`)

Sections, in order:

1. **Plan** — existing.
2. **Usage** — existing.
3. **Preferences** — lifted from `SettingsView`. Same 4 keys (`seed_torrents`, `allow_zipped`, `download_speed_in_tab`, `show_tracker_in_torrent`), same controls, same Save button + dirty tracking via `hasSettingsChanges`. Rendered inline (not behind a disclosure).
4. **Subscriptions** — existing.
5. **Session** — existing Sign out button, plus a new **TorBox API key** subsection:
   - Default state: masked key (`••••…last4`), and a `Replace…` button.
   - `Replace…` swaps the row into edit mode: `SecureField` + `Save`/`Cancel` buttons.
   - `Save` runs the new `AppModel.replaceAPIKey(_:)` path. On success: collapses back to masked state, shows `infoBanner = "API key updated."`. On failure: keeps edit mode open, shows `friendlyMessage` in red below the field.
   - Local SwiftData is **not** wiped on replace. The next sync reconciles automatically. This matches "regenerated key for same account" — the common case. Switching accounts is still done via Sign out → Sign in.
   - No "Show plaintext" toggle. Reduces surface area; users who need the key can copy it from torbox.app.

### Settings → Preferences naming

The "Settings" string disappears from the UI. Inside the Account sheet, the section header reads "Preferences".

## Architecture

### Files

| File | Change |
|---|---|
| `App/Minch/LibraryView.swift` | Remove `NavigationSplitView` + `LibrarySidebar`. Add `FilterBar` and `AccountButton` views. Drop `.settings` branching from `LibraryContent`. |
| `App/Minch/LibrarySection.swift` | Remove `.settings` case and `isVisibleInSidebar` property (no longer used). Keep `Group` enum for the filter bar's logical ordering. |
| `App/Minch/SettingsView.swift` | Delete file. Body migrates into a private `PreferencesSection` view inside `AccountView.swift`. |
| `App/Minch/AccountView.swift` | Add `PreferencesSection` + `APIKeySection` private views. Wire into existing `ScrollView`. |
| `App/Minch/AppModel.swift` | Add `replaceAPIKey(_ newKey: String) async throws`. Refactor `validate(key:persistOnSuccess:)` to split "validate + activate client" so both `connect()` and `replaceAPIKey(_:)` share it without duplicating sync-engine wiring. |
| `Packages/MinchUI/...` | Audit `MinchAccountChip`, `MinchSidebarRow`, `MinchSidebarFooter`. `MinchSidebarRow` and `MinchSidebarFooter` get deleted. `MinchAccountChip` is reused as the header account button if its sizing accommodates a header (≤ 32 pt tall); otherwise the header uses a smaller `Button` showing plan name + `bolt.fill` (when subscribed) and `MinchAccountChip` is deleted. |

### `replaceAPIKey` semantics

```swift
@MainActor
func replaceAPIKey(_ newKey: String) async throws {
    let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw APIError.validation("Enter a key.") }
    let provider = StaticAPIKeyProvider(trimmed)
    let candidate = clientFactory(provider)
    _ = try await candidate.me()                       // validates
    try await secretStore.write(trimmed, for: SecretKey.torboxAPIKey)
    stopPolling()
    self.client = candidate
    self.syncEngine = SyncEngine(container: container) { [candidate] in
        async let torrents = candidate.listTransfers()
        async let webdls = candidate.listWebDownloads()
        return try await torrents + webdls
    }
    startPolling()
    infoBanner = "API key updated."
}
```

Notes:
- Reuses `secretStore`, `clientFactory`, and `container` — no new dependencies.
- Does **not** touch `state` (still `.signedIn(account)`). The user account doesn't change.
- Does **not** clear SwiftData. Background poll reconciles within 15 s; user can press `⌘R` to force.
- Errors propagate; the Account sheet renders them via `friendlyMessage(for:)`.

### Filter bar binding

`FilterBar` takes `@Binding selection: LibrarySection` and a `counts: [LibrarySection: Int]` map computed in `LibraryView` from the existing `rows` query. Sections in display order:

```swift
[.active, .downloaded, .videos, .audio, .recent]
```

Group titles ("Library", "Smart Collections") are dropped — the pill bar is too narrow for headers. A subtle vertical hairline divider separates `[.downloaded]` from `[.videos]` to preserve the existing grouping intuition.

### Keyboard + URL scheme behavior

- `⌘N` (focus magnet): unchanged.
- `⌘R` (refresh): unchanged.
- `⌘K` (command palette): unchanged — palette already opens the add-magnet flow via `initialAction = .addMagnet`.
- `minch://addmagnet?url=…` ingestion: unchanged.
- Command palette's `case .openTransfer` already maps `done` → `.downloaded` else `.active`. No changes needed.

## Data flow

No new persistent state. `selection` stays a local `@State` on `LibraryView`. Counts are derived from `@Query` rows — same as today. The Account sheet keeps using `AppModel.settings` / `loadSettings` / `saveSettings` for the preferences section; nothing in `AppModel`'s settings story changes.

## Error handling

- **Replace API key — validation fails:** `replaceAPIKey` throws; Account sheet shows red `friendlyMessage`. Old key remains active.
- **Replace API key — Keychain write fails:** Same surface; old key remains. (Same behavior as `connect()` today.)
- **Preferences — load fails:** Existing `SettingsView` retry UX moves into `PreferencesSection` verbatim.
- **Preferences — save fails:** Existing inline error treatment preserved.
- **Filter bar:** no error paths.

## Testing

Manual:

1. Launch app. Sidebar is gone. Filter pills selectable and reflect counts.
2. Tap each pill → list updates; header title + count match.
3. Search + add-magnet + banners still appear inside the main pane.
4. `⌘N` focuses magnet field. `⌘R` refreshes. `⌘K` opens palette.
5. Header account button → Account sheet opens.
6. Account sheet → Preferences section toggles save successfully; Save button disables when no diff.
7. Account sheet → Session → Replace API key → enter a valid key → success banner; transfers remain visible.
8. Account sheet → Session → Replace API key → enter garbage → red error inline; old key still works (Save in Preferences still posts successfully).
9. Sign out from Account sheet → returns to sign-in screen.
10. External magnet via `minch://addmagnet?url=…` still ingests.

No automated UI tests added — existing test coverage for `AppModel` flows continues to apply; `replaceAPIKey` can get a unit test that fakes `clientFactory` and `secretStore`.

## Migration / compatibility

- No persisted state schema changes.
- Existing users land in the same sign-in or signed-in state; the only visible change is layout.
- `MinchUI` views removed (if any) are internal — no external consumers.

## Open follow-ups (out of scope)

- Window minimum width may need tightening since the sidebar's 200 pt floor is gone.
- The `bolt.fill` "Cached" indicator on the magnet bar overlaps visually with the bolt motif on the header account button — revisit if it feels noisy in practice.
