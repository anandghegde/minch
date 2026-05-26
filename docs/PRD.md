# Minch — Product Requirements Document

**Version:** 0.1 (Foundational PRD)
**Date:** 2026-05-25
**Owner:** Product / Design / Engineering Lead
**Status:** Pre-implementation, ready for prototyping
**Platform:** macOS 15+ (Sequoia), universal binary, Apple Silicon optimized
**Codename:** Minch

---

## 0. Naming, Tagline, and Brand Direction

**Product name:** Minch
**Working tagline:** *"Your downloads, at the speed of light."*
**Alternates:** *"A calm, fast home for your cloud torrents." · "Premium torrent streaming for Mac."*

The name "Minch" sits between *minch* (short, sharp, kinetic) and *winch* (to pull). It evokes pulling content down through a fast cable — current, motion, lightning. It is not a torrent word. It is not a pirate word. It is a *utility* word.

**Brand pillars:**
- **Current** — energy, throughput, motion
- **Calm** — never anxious, never chaotic
- **Precision** — every pixel is intentional
- **Privacy** — the user's library is their business

**Icon concept (single direction, not committee):**
A monochrome lightning bolt whose lower half dissolves into a downward-flowing waveform — one continuous stroke, sculpted with subtle depth (Apple-style "tahoe" gradient on dark, with a soft inner highlight). Renders as a glyph in the menu bar (16pt, template image, two states: idle/active) and as a 1024pt app icon (concentric depth, slight rim light, sits naturally next to Things, Linear, Raycast).

**Brand colors (see §11 for full system):**
- Signature accent: `Bolt Blue` (#3D7BFF) → `Current Cyan` (#5BE2F7) linear, used sparingly
- Surface palette is near-black with translucent layers (NSVisualEffect `.hudWindow`, `.sidebar`, `.headerView`)

---

## 1. Executive Summary

Minch is a native macOS client for [TorBox](https://torbox.app), the cloud debrid / torrent service. It is the missing first-class Mac app for a service that today is consumed primarily through a web dashboard.

Minch does four things, beautifully:

1. **Add** — magnet links, `.torrent` files, URLs, watchfolders, share sheet, command-line, Services menu
2. **Wait calmly** — show queue, progress, ETA, errors with grace; never demand attention
3. **Stream or download** — direct AVKit playback from TorBox's CDN, or background downloads to a local library
4. **Find again** — Spotlight-grade local search across the user's TorBox account and downloaded library

Minch is **not** a BitTorrent client. It owns no swarm, no port, no peer logic. All swarm work happens in TorBox's cloud. Minch's job is to make that cloud feel like part of macOS — like Finder, like Mail, like Music — rather than a browser tab.

The target user is a macOS power user who already pays for TorBox and currently switches between the web dashboard, Infuse/IINA, and Finder. Minch collapses those workflows into one keyboard-first app that respects their time, taste, and machine.

**Success looks like:** the user opens Minch once with `⌘Space → minch`, presses `⌘N`, pastes a magnet, hits `↩︎` — and the app vanishes back into the menu bar, never to be opened again until something interesting completes.

---

## 2. Product Philosophy

### 2.1 Tenets

1. **Native or nothing.** SwiftUI-first, AppKit where needed. No Electron. No web views. No cross-platform compromises.
2. **Calm over chatty.** Notifications fire on transitions, not on tick events. The dock badge counts only what the user must act on.
3. **Keyboard is the primary input.** Every action reachable in ≤2 keystrokes via the command palette.
4. **The menu bar is the app.** The window is a privileged accessory, not the entry point.
5. **Local-first cache, cloud-first source of truth.** Optimistic UI on every mutation; SQLite/SwiftData mirror of the user's TorBox state, hydrated in background.
6. **Never lie about state.** Pending, syncing, and error states are visually distinct. No fake spinners. No phantom progress.
7. **Surface tradeoffs; hide configuration.** Two-pane preferences. No nested tabs. No advanced/expert split.
8. **Privacy is the default.** No analytics out of the box. No crash reporter without opt-in. Keychain for credentials. No phoning home.
9. **Free, forever.** Minch ships fully free — no paid tier, no in-app purchase, no MAS-paid path, no upsell modals, no banners. The subscription belongs to TorBox; Minch sells itself with craft.
10. **Beauty is a feature.** If a screen isn't beautiful at 1×, 2×, and on an XDR display, it ships rebuilt.

### 2.2 Anti-patterns we will not adopt

- Tabbed window chrome with seven nested panes
- "Help us improve" toasts
- Coachmarks, tooltips on every button, onboarding carousels >3 steps
- Modal alerts for recoverable errors
- Dock badge integers for ambient state ("3 torrents seeding")
- Forced light mode
- Custom title bars that break window snapping or fullscreen
- Sound effects (one optional, tasteful "completion" chime, off by default)

---

## 3. Detailed Feature Requirements

### 3.1 Authentication

**The only credential Minch knows is a TorBox API key.** No OAuth, no email/password, no Minch-side account. The user pastes their TorBox key once and never thinks about it again.

- **Single onboarding screen** prompts for TorBox API key (deep link to `torbox.app/settings/api` with a `Get my key` button that opens the URL via `NSWorkspace`).
- Key is validated against `GET /v1/api/user/me` before being persisted.
- Sent on every request as `Authorization: Bearer <key>`.
- Stored exclusively in Keychain (`kSecClassGenericPassword`, accessGroup-scoped, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- Never written to disk, `UserDefaults`, logs, or unencrypted IPC.
- Optional **biometric reauth** (Touch ID/Apple Watch via `LAContext`) for revealing the key in Preferences.
- "Sign out" wipes the Keychain entry; the local library mirror is preserved (the user can re-auth and resume without re-syncing from scratch).
- Multi-account scaffolding from day one (data model supports it), but UI gates a second account behind a hidden preference until 1.1.

### 3.2 Torrent / Download Lifecycle (the spine)

A `Transfer` in Minch is the unified model — it is one of:
- `torrent` (added via magnet or `.torrent`)
- `usenet` (NZB) — phase 2
- `webdl` (TorBox direct link / HTTP source) — phase 1

**Per transfer the user can:**
- Add (paste, drop, share-sheet, open-with, watchfolder, CLI, Services)
- Inspect (file tree, sizes, hash, trackers, peers seen by TorBox)
- Select files to download/stream (granular file-level inclusion)
- Stream (AVKit, range-request from TorBox CDN, see §3.6)
- Download (URLSession background, see §3.5)
- Pause / resume / re-queue / delete (with optional cloud removal)
- Tag, favorite, hide
- Share (file link or magnet, via share sheet)
- Reveal in Finder (post-download)
- "Send to" (IINA, Infuse, VLC, Plex, custom — see §3.7)

### 3.3 Library

The Library is the user's permanent home. It contains:
- **Recents** — sectioned by Today / Yesterday / This Week / Earlier
- **Active** — anything in motion (downloading, seeding-in-cloud, streaming)
- **Downloaded** — local files Minch has stewarded
- **Cloud** — everything on the TorBox account, regardless of local state
- **Smart Collections** — auto-grouping by inferred media kind: Movies, TV, Music, Audiobooks, Software, Other (powered by filename parsing — see §3.10)
- **Tags** — user-defined, color-coded
- **Trash** — soft-deleted items, recoverable for 7 days

### 3.4 Search

- Global, instant, fuzzy. ⌘F focuses the toolbar search; `/` from anywhere opens command-palette search mode.
- Searches across: transfer names, file names, hashes, tags, tracker names, file paths, dates.
- Powered by SQLite FTS5 on the local mirror. ≤16ms response on a 10k-row library.
- Modifiers (Raycast-style): `kind:movie`, `tag:fave`, `size:>5gb`, `added:7d`, `status:downloading`, `ext:mkv`.
- Recent searches surfaced as chips below the search field.

### 3.5 Background Downloads

- `URLSession` with `URLSessionConfiguration.background(withIdentifier:)` so downloads survive app quit and reboot.
- Concurrent download limit configurable (default 4, max 16).
- Per-transfer bandwidth limits (download-only — Minch never seeds locally).
- Global "quiet hours" schedule (e.g., pause downloads 9am–6pm weekdays).
- Resumes from `resumeData` after sleep/wake, network change, captive-portal blip.
- Integrity verification: SHA-256 of completed file optionally checked against TorBox's reported hash; mismatch surfaces a non-modal banner offering "Re-download" or "Keep anyway."
- Files land in user-chosen library root (default `~/Movies/Minch`), with a configurable folder template: `{kind}/{title}/{file}` or `{kind}/{title} ({year})/{file}` for media.

### 3.6 Streaming

- Per-file "Play" action invokes AVKit (`AVPlayerView`) in a borderless, chromeless window.
- For supported codecs: native playback via `AVPlayer` with byte-range streaming over HTTPS from TorBox CDN.
- For unsupported (e.g. MKV/HEVC10 in obscure containers): "Open in IINA" / "Open in Infuse" buttons in the player overlay; the streaming URL is handed off via URL scheme.
- PiP (Picture in Picture) supported via `AVPictureInPictureController`.
- Subtitle sidecar auto-detection: if `.srt`/`.ass` files are siblings in the same transfer, they appear in a Subtitles menu and are loaded as `AVMediaSelectionGroup`.
- AirPlay 2 supported (free with `AVPlayerView`).
- Now Playing integration via `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` (media keys, Touch Bar/CarPlay-irrelevant on Mac but the Now Playing widget in Control Center works).

### 3.7 Hand-off / "Send to"

User-configurable list of external apps. Defaults shipped:
- IINA (`iina://weblink?url=...`)
- Infuse (`infuse://x-callback-url/play?url=...`)
- VLC (`vlc://...`)
- Reveal in Finder
- Copy stream URL
- Copy magnet link
- Share… (NSSharingServicePicker)

Custom entries: name, URL scheme template, optional icon path. Stored in `~/Library/Application Support/Minch/handoffs.json` so power users can version-control them.

### 3.8 Watch Folders

- User selects N folders. Minch watches via `DispatchSourceFileSystemObject` / `FSEventStream`.
- Any `.torrent` or `.magnet` (one-per-line text) dropped in is auto-submitted to TorBox.
- Optional auto-move-after-submit to a `.processed` subfolder.
- Optional auto-download-and-import to library.

### 3.9 Automation Surface

- **URL scheme:** `minch://add?magnet=…`, `minch://open?hash=…`, `minch://stream?file=…`
- **Services menu:** "Add to Minch" appears for any text selection that contains a magnet/URL.
- **Share Extension:** system share sheet target so Safari, Mail, etc. can send to Minch.
- **AppleScript / JXA dictionary:** scripting bridge for `add`, `list`, `pause`, `delete`.
- **Shortcuts.app integration:** App Intents for Add Magnet, Pause All, Get Active Downloads, Get Recent Completions. (See §25.)
- **CLI:** `minch` binary in `~/Library/Application Support/Minch/bin/` (user adds to PATH from preferences). Subcommands: `add`, `ls`, `rm`, `play`, `open`.

### 3.10 Filename Intelligence

A small local parser (not LLM) recognizes patterns and infers:
- `kind` (movie / tv / music / book / software / other)
- `title`, `year`, `season`, `episode`, `quality` (1080p, 4K, HDR), `codec`, `release group`
- Pure regex + rules table; no network calls; ships in-bundle.
- Used for: Smart Collections, folder templates, library grouping, optional metadata lookup (phase 2, opt-in TMDB integration).

---

## 4. UX Requirements

### 4.1 Information Architecture

```
Minch
├── Menu Bar Extra (always present)
│   ├── Status glyph (idle / active / error)
│   ├── Active transfers (compact list, ≤5)
│   ├── Quick add (paste magnet)
│   ├── Open Minch (⌘O)
│   ├── Pause All / Resume All
│   └── Quit / Preferences (⌘,)
├── Main Window (single-window app, restorable)
│   ├── Sidebar
│   │   ├── Recents
│   │   ├── Active
│   │   ├── Downloaded
│   │   ├── Cloud
│   │   ├── ── Smart Collections ──
│   │   │   ├── Movies
│   │   │   ├── TV
│   │   │   ├── Music
│   │   │   ├── Software
│   │   │   └── Other
│   │   ├── ── Tags ──
│   │   │   └── (user-defined)
│   │   └── Trash
│   ├── Content Pane (list/grid toggle)
│   └── Inspector (collapsible, ⌘⌥I)
├── Command Palette (⌘K, floating panel)
├── Player Window (AVKit, separate window per stream)
└── Preferences (modal-less, sheet-based, ⌘,)
    ├── General
    ├── Account
    ├── Downloads
    ├── Library
    ├── Streaming
    ├── Watch Folders
    ├── Hand-offs
    ├── Notifications
    ├── Shortcuts
    └── About
```

### 4.2 Window Behavior

- Single primary window. Closing it does NOT quit the app — Minch is menu-bar-resident.
- `LSUIElement = false` by default (dock icon visible), but a preference toggle allows true menu-bar-only mode (`LSUIElement = true`, no dock icon, no Cmd-Tab presence).
- Window state restoration via `NSWindowRestoration`.
- Honors macOS window tabbing, full-screen, Stage Manager, Mission Control.
- Minimum size: 960×600. Default: 1180×740. Sidebar collapsible to icons-only.
- Toolbar uses `NSToolbar` (via SwiftUI `.toolbar`) so it integrates with macOS toolbar customization.

### 4.3 Loading, Empty, Error States

- **Loading:** skeleton rows with `.redacted(reason: .placeholder)` and a 200ms shimmer; never spinner-only.
- **Empty:** large SF Symbol, one-line title, one-line subtitle, one primary action. No marketing.
- **Errors:** non-modal `NSAlert` is forbidden for transient errors. Use an inline banner at the top of the content pane (`.symbolEffect(.bounce)` on entrance, dismissible, auto-fades after 8s on success or 20s on warning). Modal alerts reserved for destructive confirmations and unrecoverable auth failures.

### 4.4 Drag & Drop

- Drop `.torrent` files → add to TorBox
- Drop magnet text → add to TorBox
- Drop URLs → resolved (magnet/torrent/webdl)
- Drop files from Minch → standard NSItemProvider, works in Finder, Mail, AirDrop, etc.
- Drop a transfer onto an external app icon in the dock → "send to" via URL scheme
- Drop onto the menu bar icon → adds to TorBox (uses `NSStatusItem`'s drag-receiving)

### 4.5 Animations & Motion (see §18 for full philosophy)

- Spring-based (`.spring(response: 0.42, dampingFraction: 0.86)`) for all UI transitions.
- `.matchedGeometryEffect` for list → detail navigation.
- Progress bars use a custom `Shape` that animates with `withAnimation` rather than gauge ticks.
- The menu bar glyph subtly *pulses* when downloads are active — a 2-second sine, never aggressive.

### 4.6 Accessibility (see §24)

- All interactive elements `.accessibilityLabel`'d.
- Full VoiceOver rotor coverage.
- Reduces motion respected (`UIAccessibility.isReduceMotionEnabled` analog: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`).
- Increase Contrast respected — accent colors swap to higher-contrast variants.
- Dynamic Type via `.dynamicTypeSize`.
- Full keyboard reachability — every clickable element has a focusable/tabbable equivalent.

---

## 5. Technical Architecture

### 5.1 Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Swift 6 (strict concurrency) | First-class async/await, sendability |
| UI | SwiftUI (macOS 15 target) | Compose, Inspector, Table, NavigationSplitView all stable here |
| Bridges | AppKit where SwiftUI is insufficient (NSToolbar customization, NSStatusItem with custom view, NSWindow restoration, NSSharingServicePicker, NSSavePanel for fine control) | Pragmatic, not ideological |
| Media | AVKit + AVFoundation | Native, AirPlay/PiP/Now Playing for free |
| Networking | URLSession + Swift Concurrency wrappers | No third-party HTTP lib |
| Persistence | SwiftData (primary) with raw SQLite via GRDB for FTS5 search index | SwiftData for typed models, GRDB for full-text |
| Background tasks | URLSession background config + BGTaskScheduler equivalent (`NSBackgroundActivityScheduler`) | macOS-native |
| Keychain | `Security.framework` directly, thin wrapper | Avoid abandoned wrappers |
| Logging | `os.Logger` (unified logging) | Privacy-aware, free, viewable in Console.app |
| Crash reporting | None by default. Opt-in PLCrashReporter → user-controlled local file, never auto-uploaded | Privacy stance |
| Build | Xcode 16+, SwiftPM workspace | Standard |
| CI | GitHub Actions on macOS-15 runners | Pragmatic |
| Distribution | Direct download (DMG, notarized, Sparkle) + Mac App Store later as **free** app | Indie default; see §11.6 |

### 5.2 Suggested Modular Project Structure

```
Minch/
├── Minch.xcworkspace
├── App/
│   └── Minch (app target)
│       ├── MinchApp.swift          # @main
│       ├── AppDelegate.swift       # NSStatusItem, URL scheme handling
│       ├── Resources/              # Assets, Localizable, Info.plist
│       └── DI/                     # Composition root
├── Packages/                       # Local Swift packages, one per bounded context
│   ├── MinchKit/                   # Shared types: Transfer, File, Tag, IDs
│   ├── MinchAPI/                   # TorBox API client (URLSession-based)
│   ├── MinchPersistence/           # SwiftData models + GRDB FTS5 index
│   ├── MinchDownloads/             # URLSession background download manager
│   ├── MinchStream/                # AVKit-based player, URL signing, PiP
│   ├── MinchSearch/                # FTS5 index + ranking
│   ├── MinchAutomation/            # AppleScript, URL scheme, Services, App Intents
│   ├── MinchUI/                    # Design system: colors, type, components
│   ├── MinchFeatures/              # Feature modules: Library, Inspector, Onboarding…
│   └── MinchTesting/               # Test doubles, fixtures, in-memory stores
└── Tools/
    └── minch-cli/                  # SPM executable target
```

Why this shape:
- **Apps stay small** — `App/` only wires composition.
- **Features are independent** — `MinchFeatures/Library` can be previewed in Xcode previews with `MinchTesting` fixtures, no network.
- **`MinchAPI` is testable** — protocol-fronted, `URLProtocol` stub-friendly.
- **`MinchKit` has no dependencies** — pure value types, sendable.

### 5.3 State Management Architecture

The app is built on **the Observation framework** (Swift 5.9+, `@Observable`), not the older `ObservableObject`. State flows top-down through environment-injected stores; mutations flow bottom-up via async methods on those stores.

```
            ┌─────────────────────────┐
            │   AppEnvironment (DI)   │
            └────────────┬────────────┘
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
  ┌────▼─────┐    ┌──────▼──────┐    ┌─────▼─────┐
  │ Account  │    │   Library   │    │ Downloads │
  │  Store   │    │    Store    │    │   Store   │
  └────┬─────┘    └──────┬──────┘    └─────┬─────┘
       │                 │                 │
       └────────────┬────┴─────────────────┘
                    │
              ┌─────▼──────┐
              │ TorBoxAPI  │
              │  (actor)   │
              └─────┬──────┘
                    │
              ┌─────▼──────┐
              │ Persistence│
              │  (actor)   │
              └────────────┘
```

- **Stores are `@Observable` reference types**, each an `actor` only when they own external IO; UI-facing stores are MainActor-isolated classes that delegate to actors.
- **No singletons.** Composition root constructs everything, injects via `.environment(\.account, accountStore)`.
- **One-way data flow.** Views read, intents call methods.
- **Cancellation is explicit.** Every long-running task is wrapped in a `Task` whose handle is stored on the store and cancelled on view disappear or store deinit.
- **Strict concurrency on.** `-strict-concurrency=complete`. Every model `Sendable`. We pay the upfront cost to avoid Swift 6 cliff later.

### 5.4 Networking Architecture

`MinchAPI` is a single `actor TorBoxClient` exposing typed async methods.

```swift
public actor TorBoxClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.torbox.app/v1/api")!
    private var keyProvider: () async -> String?

    public func addMagnet(_ magnet: String, options: AddOptions) async throws -> Transfer
    public func listTorrents(bypass cache: Bool = false) async throws -> [Transfer]
    public func requestDownloadURL(for fileID: File.ID) async throws -> URL
    public func deleteTorrent(_ id: Transfer.ID, removeCloud: Bool) async throws
    // …
}
```

Design notes:
- **Endpoint enum** maps to URLRequest construction; testable in isolation.
- **Retry policy:** exponential backoff (250ms base, factor 2, jitter ±20%, max 5 attempts) only for idempotent reads. Mutations never auto-retry.
- **Rate limiting:** token bucket (60 req/min default, configurable) prevents accidental hammering during sync storms.
- **Request signing:** API key injected as `Authorization: Bearer ...` header, pulled fresh from Keychain per request (cached in actor for 60s).
- **Logging:** every request emits an `os_signpost` so Instruments can trace; bodies are NOT logged by default (privacy).
- **Mock layer:** `URLProtocol` subclass `MinchMockProtocol` for tests and SwiftUI previews.

### 5.5 Persistence Models (SwiftData)

```swift
@Model final class Transfer {
    @Attribute(.unique) var id: String         // TorBox ID
    var hash: String?                          // info hash
    var name: String
    var kind: TransferKind                     // torrent | webdl | usenet
    var addedAt: Date
    var sizeBytes: Int64
    var status: TransferStatus                 // queued | downloading | seeding | error | done
    var progress: Double                       // 0…1
    var downloadSpeed: Int64                   // bytes/sec
    var uploadSpeed: Int64
    var eta: TimeInterval?
    var trackers: [String]
    var availability: Double?
    var error: String?
    @Relationship(deleteRule: .cascade) var files: [TransferFile]
    @Relationship var tags: [Tag]
    var isFavorite: Bool
    var isHidden: Bool
    var lastSyncedAt: Date
}

@Model final class TransferFile {
    @Attribute(.unique) var id: String
    var name: String
    var pathInTransfer: String
    var sizeBytes: Int64
    var mime: String?
    var isDownloaded: Bool
    var localURL: URL?
    var playedAt: Date?
    var playbackPositionSec: Double?
    var transfer: Transfer?
}

@Model final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String
    var sortOrder: Int
}

@Model final class HandoffApp {
    var name: String
    var urlSchemeTemplate: String              // "iina://weblink?url={url}"
    var iconBookmarkData: Data?
}
```

A separate **GRDB-backed SQLite database** holds the FTS5 search index, rebuilt incrementally from SwiftData change notifications. Two stores rather than one because SwiftData's current full-text story is anemic; GRDB's FTS5 is battle-tested.

### 5.6 Concurrency Model

- **MainActor** for all UI-touching code.
- **Stores** are MainActor classes; heavy work is offloaded to `Task.detached(priority:)` only when measurable.
- **API client** is a single actor (serializes Keychain reads, dedupes in-flight requests by URL+method).
- **Persistence actor** wraps SwiftData `ModelContext` access; SwiftData contexts are not Sendable, so the actor owns one.
- **Download manager** is a class conforming to `URLSessionDownloadDelegate`; delegate callbacks hop to MainActor for store updates.
- **Cancellation** is propagated via structured `Task` handles; nothing is "fire and forget" except `os_log`.

---

## 6. TorBox API Integration Architecture

> Note: TorBox's API surface evolves; the integration layer must be versioned and isolated so an API change is a single-file PR. Treat the wire format as untrusted — decode into internal types via dedicated DTOs.

### 6.1 Endpoint coverage (phase 1)

- `POST /torrents/createtorrent` — add magnet or `.torrent` upload (multipart)
- `GET /torrents/mylist` — paginated list
- `GET /torrents/torrentinfo` — single torrent detail
- `GET /torrents/requestdl` — request a download URL for a file
- `POST /torrents/controltorrent` — pause/resume/reannounce/delete
- `GET /user/me` — auth validation, plan info
- `GET /webdl/createwebdownload` and webdl variants (phase 1.1)
- `GET /usenet/*` (phase 2)

### 6.2 Sync engine

A long-poll-style **`SyncCoordinator`** runs whenever the main window is visible OR a download is active:
- Pulls `mylist` every 5s while any transfer is in motion
- Backs off to 30s when idle but visible
- Backs off to 5min when window hidden
- Uses ETag / If-Modified-Since where TorBox supports it (and falls back to a hash of the response otherwise) to skip diffing on no-change
- Diffs against local SwiftData state and emits a structured changeset; the UI animates only the rows that actually changed

### 6.3 Mutation pattern

Optimistic, then reconciled:
1. View calls `library.pause(transfer)`
2. Store flips local `status` to `.pausing`, schedules timeout
3. API mutation fires
4. Success → status reconciles; failure → revert + inline banner

### 6.4 Error taxonomy

| Bucket | Examples | UX |
|---|---|---|
| `auth` | 401, expired key | Modal: re-enter key |
| `transient` | network, 5xx | Inline banner, auto-retry idempotent reads |
| `validation` | bad magnet, oversize file | Toast at action site, do not write to log |
| `quota` | plan limits hit | Inline banner with link to TorBox plan page |
| `unknown` | unmapped | Inline banner with "Copy diagnostics" → puts redacted JSON on clipboard |

---

## 7. Native macOS Integration Opportunities

| Integration | API | Use |
|---|---|---|
| Menu bar | `NSStatusItem` + SwiftUI `MenuBarExtra` | Always-on presence, see §20 |
| Notifications | `UNUserNotificationCenter` | Completions, errors |
| Quick Look | `QLPreviewPanel` + `QLPreviewItem` | Preview files in library (⌘Y / spacebar) |
| Share | `NSSharingServicePicker` | Share streams, magnets |
| Services | `NSServicesMenuRequestor` | "Add to Minch" on any selected text |
| Spotlight | `CSSearchableIndex` | Index local library so files appear in Spotlight |
| Continuity | Handoff (`NSUserActivity`) | Picks up "Now Playing" on another device (longer term) |
| AirPlay | `AVRoutePickerView` | Mirror to TVs/HomePods |
| PiP | `AVPictureInPictureController` | Float player when leaving the window |
| Now Playing | `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | Media keys, Control Center, Lock Screen |
| Touch ID | `LAContext` | Optional reveal-key biometric gate |
| FileProvider | `FileProviderExtension` | Phase 2: TorBox cloud appears as a Finder location |
| Shortcuts | App Intents (`AppIntent`, `WidgetKit` providers) | See §25 |
| Universal Clipboard | Implicit via NSPasteboard | Paste a magnet copied from iPhone Safari |
| Stage Manager / Spaces | Stock SwiftUI window behavior | No custom NSWindow subclass needed |
| Dock menu | `NSApplicationDelegate.applicationDockMenu(_:)` | Quick actions when right-clicking dock icon |
| Services menu | `NSApp.servicesProvider` | "Add to Minch" |
| Sparkle | Sparkle 2 | Auto-update for direct distribution |
| Login items | `SMAppService` | Launch at login (preference) |

---

## 8. Design System

### 8.1 Color

A near-monochrome surface palette with a single saturated accent.

```
Surface tokens
  surface.canvas        — window background, near-black w/ NSVisualEffect (.hudWindow in dark, .windowBackground in light)
  surface.elevated      — cards/rows on top of canvas
  surface.sunken        — list rows in selected sidebar
  surface.scrim         — modal overlay
Text tokens
  text.primary          — primary labels
  text.secondary        — captions, metadata
  text.tertiary         — disabled, separators
  text.inverse          — on accent
Accent tokens
  accent.bolt           — primary CTA, focus rings
  accent.current        — secondary highlight, progress bars
  accent.success        — completion check, downloaded state
  accent.warning        — quota, slow transfers
  accent.danger         — destructive actions, errors
```

Use `Color("AccentColor")` from the asset catalog so the macOS system accent color preference is honored — accent.bolt is the *default*, not a hard-coded override.

Both light and dark themes ship at v1. Dark is the default and gets the most love.

### 8.2 Typography

- **SF Pro** everywhere via `Font.system(...)`.
- Type scale (8 sizes, no orphans):
  - `display` — 28pt semibold (player chrome, empty-state titles)
  - `title` — 20pt semibold
  - `headline` — 15pt semibold
  - `body` — 13pt regular (default Mac)
  - `callout` — 12pt regular
  - `caption` — 11pt regular
  - `footnote` — 10pt regular
  - `mono` — SF Mono 12pt (hashes, sizes, ETAs)
- Tracking: default. We do not tighten or loosen system fonts.
- Numbers: `.monospacedDigit()` on every progress, speed, ETA, size label so they don't dance.

### 8.3 Spacing

8pt baseline grid. Tokens: `xs=4, s=8, m=12, l=16, xl=24, 2xl=32`. Layout uses `Spacer()` and explicit `padding(.x)` — never magic numbers.

### 8.4 Iconography

- **SF Symbols 6** everywhere. Multi-color variants for status, mono for chrome.
- Custom symbols only when no SF equivalent fits, drawn at 100/200/300 weights, shipped in the asset catalog as symbol images.
- Per-status glyphs:
  - `.bolt.fill` (accent) — active
  - `.checkmark.seal.fill` (success) — completed
  - `.pause.circle.fill` (secondary) — paused
  - `.exclamationmark.triangle.fill` (warning) — error
  - `.cloud.fill` (secondary) — cloud-only
  - `.arrow.down.circle.fill` (accent) — downloading
  - `.play.circle.fill` (accent) — streaming

### 8.5 Component Library

Defined in `MinchUI`:

- `MinchButton` (variants: primary, secondary, ghost, destructive; sizes: regular, small)
- `MinchTextField` (with leading SF Symbol, optional clear button)
- `MinchSegmentedControl`
- `MinchSidebarRow`
- `MinchTransferRow` (the workhorse: name, status glyph, progress bar, ETA, actions)
- `MinchProgressBar` (custom Shape, supports indeterminate/determinate/segmented)
- `MinchBanner` (info/warning/error, dismissible)
- `MinchEmptyState` (icon + title + subtitle + CTA)
- `MinchInspectorSection`
- `MinchKeyboardChip` (renders `⌘K` etc. with platform-correct glyphs)
- `MinchCommandPaletteRow`
- `MinchPlayerOverlay`

Every component has Xcode previews for all states (default/hover/pressed/disabled, light/dark, regular/RTL, accessibility XXL) — enforced by a tiny lint script in CI.

### 8.6 Layout patterns

- **NavigationSplitView** for the main window (sidebar / content / detail).
- **Inspector** is the `.inspector(isPresented:)` modifier (macOS 14+).
- **Toolbar** lives in `.toolbar { ToolbarItemGroup }`; customizable via `.customizationBehavior`.
- **Sheets** for transient flows (Add Transfer, Edit Tag); never modal NSAlerts except destructive confirmation.
- **Popovers** for compact contextual menus from toolbar items.

---

## 9. Animation Philosophy

> Motion is a language. We speak it sparingly.

### 9.1 Principles

1. **Motion explains causation.** A row moves to its new section when sorted; it does not appear.
2. **Spring, not curve.** Almost every animation is a spring; ease-out only for opacity fades.
3. **Sub-300ms.** If you can't notice it, it doesn't feel slow. If it lingers, it feels heavy.
4. **No looping animations** except: menu bar pulse, intentional shimmer on skeleton load, AVKit playback.
5. **Reduce Motion is sacred.** When set, springs become 0.1s opacity fades; shimmer becomes static; the menu bar glyph stops pulsing.
6. **`.matchedGeometryEffect`** is the default mechanism for cross-screen continuity (list row → detail, transfer → player).
7. **Custom symbol effects** (`.symbolEffect(.bounce, value:)`, `.pulse`, `.variableColor`) replace one-off custom animations wherever they apply.

### 9.2 Specific animations

- **Add transfer:** new row slides in from top with a 0.42/0.86 spring, glyph does a `.bounce`.
- **Complete transfer:** row briefly tints with `accent.success` for 600ms, glyph does a `.bounce.up`, row optionally moves to Downloaded section.
- **Sidebar selection:** the highlight bar `.matchedGeometryEffect`s between items.
- **Toolbar search focus:** width expands with a 0.35/0.8 spring as keyboard shortcut fires.
- **Player open:** `.matchedGeometryEffect` from the row's poster → the player window's first frame (where possible via window-level snapshot).
- **Menu bar pulse:** custom 2s `Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)` on a symbol's tint, active only while downloads progress.

---

## 10. Performance Goals

| Metric | Target |
|---|---|
| Cold launch to first interactive frame | <600ms on M1, <900ms on Intel |
| Idle RAM (window open, 1k transfers) | <180MB |
| Idle RAM (menu bar only) | <50MB |
| Idle CPU (no active transfers) | <0.5% on M-series |
| Sync round-trip (1k items) | <250ms end-to-end |
| Search (10k items, single term) | <16ms p95 |
| Scroll FPS on 10k row list | 120fps locked on ProMotion |
| Player startup (cache hit) | <800ms to first frame |
| Player startup (cold range request) | <2.5s to first frame |
| Background download throughput | Saturates user's link (>950Mbps on gigabit) |
| Binary size | <30MB universal |

We measure these in `MinchTesting/Performance/` with `XCTMetric`. CI flags >10% regressions.

---

## 11. Security Model

### 11.1 Credentials

- API key stored in Keychain only, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Key is never written to logs, defaults, files, or copied to clipboard without explicit user action and immediate (60s) clipboard expiration via `NSPasteboard.expirationDate` analog.
- Optional `LAContext` gate to reveal in preferences.

### 11.2 Sandbox & Entitlements

The app **is sandboxed** from day one. Entitlements:
- `com.apple.security.app-sandbox` ✓
- `com.apple.security.network.client` ✓
- `com.apple.security.files.user-selected.read-write` ✓
- `com.apple.security.files.downloads-folder.read-write` ✓
- `com.apple.security.files.bookmarks.app-scope` ✓ (for watch folders)
- `com.apple.security.application-groups` ✓ (for sharing state with Share Extension)
- No accessibility, no full disk, no Apple Events outside the Services menu.
- Hardened Runtime + Notarization on every release.

### 11.3 Network

- TLS 1.3 required. ATS enforced (no exceptions).
- Certificate pinning to TorBox's leaf cert with two-key fallback, with kill-switch in preferences (so if TorBox rotates unexpectedly, users can disable pinning rather than be locked out).

### 11.4 Local Data

- SQLite databases live in the app's sandbox container.
- Library files (downloaded media) live wherever the user chose; we hold them via security-scoped bookmarks.
- "Erase all Minch data" preference: wipes Keychain entry, app support directory, caches, prompts user about library files separately.

### 11.5 Telemetry

- None by default.
- Opt-in, anonymous usage stats sent to a self-hosted endpoint (post-1.0). The data shape and the endpoint are documented in `docs/PRIVACY.md` and the opt-in screen.
- Crash reports never auto-uploaded.
- Because Minch is free (§11.6), there is no commercial pressure to instrument; if a metric isn't load-bearing for a specific bugfix or perf investigation, it doesn't ship.

### 11.6 Pricing & Distribution Stance

- **Minch is fully free.** No paid tier, no IAP, no MAS-paid build, no license keys.
- Primary distribution: notarized DMG with Sparkle 2 updates.
- Secondary (post-1.0): Mac App Store as a free app, identical feature set.
- An optional "Buy me a coffee" / GitHub Sponsors link may live in Preferences > About. It is never modal, never a banner, never gates functionality.
- License: OSS license (MIT or Apache-2.0) or source-available — to be confirmed before tagging 1.0. Either is consistent with the free stance.
- Resolves §26 open question #3.

---

## 12. Future Roadmap

| Phase | Focus | Notable additions |
|---|---|---|
| **0.1 — Bones** | Auth + add + list + sync + simple download | One window, no menu bar yet, hard-coded design tokens |
| **0.2 — Skin** | Full design system, menu bar extra, sidebar IA, animations | Production-ready aesthetics |
| **0.3 — Stream** | AVKit player, PiP, Now Playing, hand-offs to IINA/Infuse | Streaming as a first-class verb |
| **0.4 — Power** | Command palette, watch folders, Services, URL scheme, CLI | Keyboard-first workflows |
| **0.5 — Library** | Smart Collections, tags, search modifiers, FTS5 index | Becomes the user's media home |
| **0.6 — Polish** | Onboarding, empty states, error UX, accessibility, perf budget | Ready for beta |
| **1.0 — Launch** | Sparkle updates, notarization, marketing site, docs | Direct download |
| **1.1** | Multi-account, Shortcuts.app App Intents, Spotlight indexer | |
| **1.2** | Usenet support, web download, smarter quota awareness | |
| **1.3** | FileProvider extension (TorBox-as-Finder-location) | |
| **1.4** | TMDB enrichment for media library (opt-in), poster art | |
| **2.0** | iPad/iPhone companion (universal app); Handoff between Mac and iPad player | |
| **2.x** | Local LLM filename rewriter, semantic library search, AppKit-free SwiftUI-only on next macOS | |

---

## 13. Suggested Engineering Milestones

Three-week sprints, indie-team scale (1–3 engineers + 1 designer):

| Sprint | Goal | Definition of done |
|---|---|---|
| 1 | Workspace scaffold, SwiftPM packages, CI green | `swift test` runs, empty app launches with placeholder window |
| 2 | `MinchAPI` shell + `TorBoxClient.me()` + Keychain wrapper | Onboarding screen works against real API |
| 3 | SwiftData models + sync engine MVP + list view | First end-to-end: add magnet, see it appear |
| 4 | URLSession background downloads + completion notifications | Download a file, get a notification, find file in Finder |
| 5 | Design system v1 + sidebar IA + Active/Downloaded sections | App is recognizably Minch |
| 6 | Menu bar extra + quick add + status glyph | Use the app from the menu bar all day |
| 7 | AVKit player + hand-offs + Now Playing | Stream a movie comfortably |
| 8 | Command palette + keyboard shortcuts pass | Power-user workflows feel right |
| 9 | Search (FTS5) + Smart Collections + tags | Library scales |
| 10 | Watch folders + Services + URL scheme + CLI | Automation surface complete |
| 11 | Accessibility audit + Reduce Motion + VoiceOver | Ships an AX-clean build |
| 12 | Performance pass + binary size + memory | Hits §10 targets |
| 13 | Onboarding + empty states + error UX | Beta-ready |
| 14 | Sparkle + notarization + marketing site + docs | 1.0 candidate |
| 15 | Bug bash, App Store screenshots, dry-run launch | 1.0 |

---

## 14. Screen-by-Screen Breakdowns

> Note: each screen below describes intent, layout, and behavior — not pixel positions. The detail is enough for a designer to mock and an engineer to implement without further clarification.

### 14.1 Onboarding (1 screen, 3 states)

**Purpose:** get a working API key in under 30 seconds.

**Layout:** centered card, 480pt wide, on a translucent canvas.
- Top: animated Minch glyph (subtle bolt → wave morph, 1.2s on launch, otherwise static).
- Title: "Welcome to Minch."
- Subtitle: "Sign in with your TorBox API key."
- Field: `MinchTextField` with `key.horizontal` SF Symbol, secure entry toggle.
- Helper link: "Don't have one yet? Get your key →" (opens TorBox settings via `NSWorkspace`).
- Primary button: "Continue" (disabled until field has ≥10 chars).

**States:**
1. **Empty** — field empty, primary button disabled.
2. **Validating** — button shows `ProgressView`, field becomes read-only, animated underline.
3. **Error** — inline `MinchBanner` below the field with the specific error from `/user/me`.

After success, fade to a 3-pane preview of Minch features (Library / Stream / Menu Bar), each a single line with an SF Symbol. "Get Started" → main window. Skippable with `Esc`.

### 14.2 Main Window

**Default layout:** `NavigationSplitView` with sidebar (220pt), content, optional inspector (320pt).

**Sidebar:**
- Top: account chip (avatar dot + plan name + remaining quota progress).
- Sections (rendered as `Section` headers): Library, Smart Collections, Tags, Trash.
- Bottom: settings cog (`⌘,`) and "Add" button (`⌘N`).

**Content (when "Active" selected):**
- Toolbar: search field (center), view toggle (list/grid), filter pill, "Add" button.
- List of `MinchTransferRow`s, grouped by status (Downloading, Queued, Paused, Errored).
- Each row: 64pt tall; left poster/file-icon, center stack (name + meta line), right inline progress bar + ETA + action menu (`...`).

**Inspector (when a row selected):**
- File tree (NSOutlineView-ish, but pure SwiftUI), with per-file Download/Stream actions.
- Metadata block: hash, size, added date, trackers, availability.
- Actions: pause/resume, delete (with cloud option), share, copy magnet, send-to.

### 14.3 Player Window

**Purpose:** the most beautiful AVKit window on macOS.

**Layout:** borderless `NSWindow` with `.titleHidden` and `.fullSizeContentView`; AVPlayerView fills.
- Overlay HUD appears on mouse-move, auto-hides after 2s.
- HUD elements: play/pause, scrubber with hover-thumbnail preview, time, subtitle menu, audio menu, PiP, AirPlay route picker, "Open in…" button.
- Top-left "traffic lights" appear only on hover.
- Pinch-to-zoom: native (AVPlayerView handles).
- ⌥-arrow keys: ±10s; ⌘arrow keys: ±60s; space toggles play.

### 14.4 Command Palette

**Trigger:** `⌘K` (global within app), `⌘⇧K` (global with Accessibility-API-free hotkey via `NSEvent.addGlobalMonitorForEvents` — see §21).

**Layout:** floating `NSPanel`, 640pt wide, top-third of screen, vibrant blur background, rounded 16pt corners, single drop shadow.

**Behavior:**
- Single text field with subtle placeholder ("Search transfers, run commands…").
- Below: scoped results split into sections: Actions / Transfers / Files / Tags / Help.
- Up/Down navigates; `↩︎` invokes; `⌘1…9` jumps; `Esc` dismisses.
- Modifiers (Raycast-style): typing `>` filters to actions only; typing `?` shows help; typing `tag:` filters tags.
- Fuzzy matched, ranked by recency + usage.
- See §21 for full UX.

### 14.5 Preferences

**Layout:** sheet attached to main window, not a separate window (modern macOS pattern). Two-pane: list on left (icon + label), detail on right.

No tabs-in-tabs. Each pane is 480pt wide minimum, scrollable when needed.

Panes:
- **General** — appearance (system/dark/light), launch at login, menu-bar-only mode
- **Account** — plan info, API key reveal (biometric-gated), sign out
- **Downloads** — library root folder, folder template, concurrent limit, integrity verification, quiet hours
- **Library** — view defaults, smart collections enable/disable, tag manager
- **Streaming** — default player (Minch/IINA/Infuse/VLC), subtitle language preferences, default audio language
- **Watch Folders** — list + add/remove + per-folder options
- **Hand-offs** — list + add/remove + URL scheme editor
- **Notifications** — per-event toggles (completion, error, quota, etc.), sound on/off
- **Shortcuts** — full keyboard shortcut editor (record-a-key style, conflict detection)
- **About** — version, acknowledgements (auto-generated from SPM), open-source licenses

---

## 15. Onboarding UX (deeper)

### 15.1 The 30-second target

The hard goal: **from first launch to a working library view in under 30 seconds for a returning TorBox user.** New users (who don't yet have a key) take longer because of the round-trip to torbox.app.

### 15.2 Flow

1. **Launch** → Welcome card (see §14.1).
2. **Get key** → if the user clicks "Get your key →", we open the URL and immediately *listen* on the system pasteboard for a 32–64 char hex/base64 token. When detected (and validated), we pre-fill the field and animate the value in. (User must still confirm with `↩︎`.)
3. **Validate** → call `/user/me`. Cache plan info. Set Keychain.
4. **Sync first** → spinner replaced with skeleton library; sync engine fires immediately and animates rows in as they arrive.
5. **First-run tour** → a *single* contextual popover anchored to the menu bar icon: "Minch lives up here. ⌘K opens the command palette." One popover. No carousel. Dismissed forever after click or `Esc`.

### 15.3 Re-onboarding

- If the API key is rejected later, the entire app dims and a sheet appears with the same onboarding card, pre-filled with the old (masked) key. The library is *not* wiped; it just becomes read-only until a fresh key validates.

---

## 16. Menu Bar UX (deeper)

### 16.1 Glyph

- 16pt template image (`.template`), bolt → wave morph.
- Three visual states:
  - **Idle** — static glyph at default tint
  - **Active** — glyph pulses (1.5s sine) when downloads in progress; tint shifts subtly toward accent
  - **Error** — glyph wears a tiny red badge dot (top-right, 4pt) when any transfer is errored

### 16.2 Click behavior

- **Left click:** opens the `MenuBarExtra` popover (SwiftUI).
- **Right click / control-click:** native `NSMenu` with: Open Minch, Add Magnet from Clipboard, Pause All, Resume All, Quit.
- **Drag-on:** dropping a `.torrent`, magnet, or URL onto the icon submits it.

### 16.3 Popover layout (380pt wide)

```
┌────────────────────────────────────────┐
│  Minch                          ⌘O  ⌘, │
├────────────────────────────────────────┤
│  ◯ Active (3)                          │
│  ┌────────────────────────────────┐    │
│  │ The.Bear.S03 …  ▓▓▓▓▓░░░ 62% │ ×  │
│  │ Sintel.4K.HDR   ▓▓▓▓▓▓▓░ 84% │ ×  │
│  │ Big.Buck.Bunny  ▓▓░░░░░░ 12% │ ×  │
│  └────────────────────────────────┘    │
│  ↻ Sync: 4s ago    ⏸ Pause all         │
├────────────────────────────────────────┤
│  + Add magnet from clipboard  ⌘V       │
│  ⌘K Open command palette               │
└────────────────────────────────────────┘
```

- Each row is interactive: hover reveals action buttons; click opens detail in main window; drag drags the file out (Finder-style).
- Rows update in place every 2s while popover is open; freeze when closed.

### 16.4 Performance

- Popover content is its own lightweight scene with its own MainActor view tree. Heavy library data is *not* loaded — only the `Active` slice via a dedicated `@Observable ActiveTransfersStore`.

---

## 17. Command Palette UX (deeper)

### 17.1 Trigger

- In-app: `⌘K`
- Global (anywhere on macOS): user-configurable hotkey, default unset. When set, uses `HotKey`-style Carbon-free `NSEvent` global monitor (limited to keys that don't require Accessibility permission) or, if the user explicitly grants Accessibility, full Raycast-grade trigger.

### 17.2 Layout

- 640pt × auto, centered horizontally, ~28% from top.
- `NSPanel` (`canBecomeKey = true`, `level = .floating`), `NSVisualEffect` background, 16pt corner radius, drop shadow at depth 5.
- Closes on `Esc`, click-outside, focus loss.

### 17.3 Modes

| Prefix | Mode |
|---|---|
| (none) | Mixed search — actions, transfers, files |
| `>` | Actions only |
| `?` | Help / shortcuts cheatsheet |
| `/` | Library search (FTS5) |
| `tag:foo` | Filter to tag |
| `kind:movie` | Filter to kind |
| `>add ` | Inline add (magnet/URL paste expected) |

### 17.4 Action surface (the verbs)

- Add magnet from clipboard
- Add `.torrent`…
- Open Active
- Open Downloaded
- Pause all
- Resume all
- Show downloads folder
- Show library folder
- Toggle menu-bar-only mode
- Open preferences
- Sign out
- Quit Minch
- Per-transfer (when a transfer is selected): pause, resume, delete (cloud), delete (local), stream, send to IINA, send to Infuse, copy magnet, reveal in Finder, copy stream URL, copy hash

### 17.5 Ranking

- Recency-weighted fuzzy match (Sublime-style scoring).
- "Frecency" cache stored in SwiftData; the verbs you use most surface first.

---

## 18. Streaming UX (deeper)

### 18.1 Pre-play

- From any file row, hover reveals a "▷ Play" affordance.
- Click → if the file is locally downloaded, play from disk; otherwise request a streaming URL from `/torrents/requestdl` and feed to `AVPlayer`.
- For unknown codecs we know AVKit can't play (MKV containers, some HEVC10 profiles), we *don't* attempt — we immediately offer "Open in IINA" / "Open in Infuse" without an embarrassing 5-second timeout.

### 18.2 During playback

- Borderless window, AVPlayerView in `.fullScreenControls` mode.
- Persistent playback position per file (`playbackPositionSec` on `TransferFile`), restored on next play.
- Subtitles auto-detected from sidecar files; selectable mid-stream.
- Keyboard:
  - `Space` — play/pause
  - `←` / `→` — ±10s
  - `⌥←` / `⌥→` — ±30s
  - `⌘←` / `⌘→` — previous/next file in transfer
  - `F` — fullscreen
  - `M` — mute
  - `S` — cycle subtitle tracks
  - `A` — cycle audio tracks
  - `Esc` — exit fullscreen
- Picture-in-picture: ⌘⇧P or HUD button.
- AirPlay: HUD button (system picker).

### 18.3 After playback

- Mark watched if ≥90% completed.
- Show a small completion HUD ("Next up: …") if the file is part of a series (detected by §3.10 parser).

---

## 19. Finder / Quick Look Integration (deeper)

### 19.1 Quick Look

- Spacebar (or ⌘Y) on any selected file in Minch's library view opens system Quick Look via `QLPreviewPanel`.
- Implement `QLPreviewItem` on `TransferFile` (returns local URL when available, or a temp local stub for streaming-only items).
- Custom QL plugin (`QLPreviewExtension`) for `.torrent` files registered systemwide so Finder Quick Look shows the magnet, file tree, and tracker list.

### 19.2 Finder

- "Reveal in Finder" on any downloaded file/transfer.
- Drag from Minch row to Finder uses `NSItemProvider` with a local file URL (or a TorBox-served URL if not yet downloaded — Finder treats this as a "promised file" and downloads on drop).
- (Phase 2) `FileProviderExtension` so the user's TorBox cloud appears under Locations in Finder.

### 19.3 Services menu

- `Add to Minch` available wherever text is selected, scoped to selections matching magnet or `.torrent` URL patterns.
- `Open in Minch` for `.torrent` files (via `NSAppleEventManager` / document-types in Info.plist).

---

## 20. Accessibility Support (deeper)

### 20.1 VoiceOver

- Every interactive element has an `.accessibilityLabel`, `.accessibilityHint`, and `.accessibilityValue` where meaningful (e.g., progress bars expose `"62 percent, 4 minutes remaining"`).
- The Library list exposes a single "Transfers" rotor item with row count; each row is announced as "name, status, progress, ETA, actions available."
- The Player window exposes a "Playback" rotor with scrubber, play/pause, subtitle, audio controls.
- The Command Palette is announced on open: "Command palette, 1 of N results" with each arrow key navigation updating the announcement.

### 20.2 Keyboard

- Tab order matches visual order.
- Every action reachable from keyboard. No mouse-only paths.
- Focus rings are 2pt accent.bolt, visible at all times (we do not hide them under any condition).

### 20.3 Visual

- Respects:
  - System dark/light mode
  - System accent color
  - Increase Contrast
  - Reduce Transparency (translucent surfaces → opaque)
  - Reduce Motion (springs → fades, shimmer disabled)
  - Differentiate Without Color (status glyphs always paired with shape/icon, never color-only)
- Dynamic Type via `.dynamicTypeSize(...DynamicTypeSize.xxLarge)` clamp; layouts re-flow with stack containers rather than fixed frames.

### 20.4 Voice Control

- Every primary action has a recognizable label ("Add", "Pause", "Stream") so Voice Control "Click Add" works without "Show numbers".

### 20.5 Audit

- A monthly accessibility pass on the build: VoiceOver walkthrough, Voice Control, Full Keyboard Access, Increase Contrast. Bug tracker tag: `a11y`.

---

## 21. Plugin / Automation APIs (deeper)

### 21.1 App Intents (Shortcuts.app)

Ship with these intents:
- `AddMagnetIntent(magnet: String) → Transfer`
- `AddTorrentFileIntent(file: File) → Transfer`
- `PauseAllIntent() → Void`
- `ResumeAllIntent() → Void`
- `GetActiveTransfersIntent() → [Transfer]`
- `GetRecentCompletionsIntent(limit: Int) → [Transfer]`
- `OpenInMinchIntent(transfer: Transfer) → Void`

Entities (`@AppEntity`):
- `MinchTransferEntity` (queryable, identifiable, suggested-by-recency)
- `MinchFileEntity`

This unlocks Spotlight typing "Pause all Minch downloads" and the user being able to chain Minch into multi-step Shortcuts.

### 21.2 URL scheme

- `minch://add?magnet={url-encoded magnet}`
- `minch://add?torrent={url-encoded https URL to .torrent file}`
- `minch://open?hash={info hash}`
- `minch://stream?file={file-id}`
- `minch://search?q={query}`

### 21.3 AppleScript

Trim, predictable dictionary:
```
tell application "Minch"
    add magnet "magnet:?xt=urn:btih:..." with tags {"movies", "kids"}
    set t to first transfer whose name contains "Sintel"
    pause t
    delete t with cloud removal
    play file 1 of t
end tell
```
Implemented via `NSScriptCommand` subclasses; dictionary defined in `Minch.sdef`.

### 21.4 CLI

A `minch` binary (SPM executable target) talking to the running app via XPC (preferred — bidirectional, structured) with a fallback to URL scheme for offline operations.

```
$ minch add 'magnet:?xt=...'
$ minch ls --status active --json
$ minch play <hash>:<file-index>
$ minch pause --all
```

JSON output mode on every command for scripting.

### 21.5 Plugin model (post-1.0)

A constrained "Action" plugin system:
- Plugins are sandboxed app extensions (`.appex`) discovered via system plugin registry.
- They expose `MinchAction` types: take a `Transfer` (or file), return a list of follow-up actions and/or URL handoffs.
- Use case: a third-party `MinchPlex` action that POSTs completed transfers to a Plex library refresh endpoint.
- Strict permission model: each plugin declares (and the user grants) what data it sees.

We do NOT ship arbitrary code execution as a plugin model. Plugins are extensions, not scripts.

---

## 22. Notifications

### 22.1 Categories

- `download.completed` — actionable (Show, Reveal, Play)
- `download.failed` — actionable (Retry, Show)
- `quota.warning` — informational (Open Plan)
- `streaming.ready` — informational (Play Now) — fires when a streaming-only request becomes playable
- `import.completed` — informational (Show)

### 22.2 Rules

- Notifications are **per-event transitions**, never tick-rate updates.
- Grouped via `UNNotificationCategoryOptions.allowAnnouncement` and a stable `threadIdentifier` per transfer so macOS Notification Center stacks them sanely.
- User can mute per-category in Preferences > Notifications, or fully via macOS System Settings.
- Sound: default tasteful chime for completion only, off by default. Failures are silent (visual only) — we don't startle.

### 22.3 Dock badge

- Counts only **unresolved errors** and **completions since last window-open** — i.e., things requiring attention.
- Goes to 0 the moment the window opens.

---

## 23. Caching & Offline Behavior

### 23.1 Cache layers

| Layer | Backing | TTL | Purpose |
|---|---|---|---|
| L0 In-memory store (Observation) | RAM | Process lifetime | UI |
| L1 SwiftData mirror | App container | Forever, until invalidated by sync | Source of truth offline |
| L2 GRDB FTS5 | App container | Rebuilt from L1 on schema change | Search |
| L3 HTTP response cache | URLCache (custom config, 256MB) | Per-Cache-Control or 5min default | Avoid re-fetching unchanged endpoints |
| L4 Poster/thumbnail cache | Files in `~/Library/Caches/com.minch.app/posters/` | 30 days LRU, 500MB cap | Library posters (post-TMDB integration) |
| L5 Streaming media cache | Files in same dir, segregated | 7 days LRU, 4GB cap (configurable) | Smoother re-watching |

### 23.2 Offline mode

- App detects offline via `NWPathMonitor`.
- Library view is fully usable offline (everything reads from L1).
- Add actions are queued in a local "outbox" SwiftData table and replayed when connectivity returns.
- A subtle `MinchBanner` ("Working offline — 2 actions queued") sits at the top of the content pane.
- Player works for local files only; streaming requests show an inline error.

---

## 24. Internationalization & Localization

- All strings via `String(localized:)` and a `Localizable.xcstrings` catalog.
- Date/number formatting via `Date.FormatStyle`, `ByteCountFormatStyle`, `Duration.UnitsFormatStyle`.
- RTL-aware layouts (every `.leading`/`.trailing` not `.left`/`.right`).
- Ship with `en` at 1.0; commit to translating to `de`, `es`, `fr`, `ja`, `zh-Hans` for 1.1.
- No machine translation; community PRs via a localization README.

---

## 25. Anti-Goals (worth restating)

- **Not a BitTorrent client.** We never talk to peers. We never open a listening port. We never seed.
- **Not a media center.** We hand off to IINA/Infuse/Plex; we don't try to be them.
- **Not a download manager for arbitrary URLs.** TorBox is the only backend. (WebDL endpoints in scope; arbitrary curl-like fetching is not.)
- **Not multi-platform.** macOS only at v1. iOS/iPad later, as a separate app sharing `MinchKit`.
- **Not configurable to a fault.** Preferences fit on one screen. No `about:config`.

---

## 26. Open Questions for Founder Review

1. **TorBox plan limits:** what's the worst-case API rate, and do we need to ship with stricter token-bucket defaults?
2. **Multi-account at v1?** Spec includes scaffolding; UI gating is a one-line decision.
3. ~~**Pricing model for Minch itself:** one-time, subscription, donation-ware, free? Affects update channel, Sparkle vs MAS, telemetry stance.~~ **RESOLVED 2026-05-25: fully free.** See §11.6.
4. **TMDB integration:** opt-in metadata enrichment uses a free TMDB key; do we ship our own throttled proxy or require user to BYO key?
5. **Code signing identity & DUNS:** do we have an Apple Developer account ready, and is the entity name "Minch" trademark-cleared in the relevant jurisdictions?
6. **Notarization cadence:** every push to `main`, or only on release tags?

---

## 27. Appendix A — Naming, Symbol, Sound (sketches)

### Wordmark

`MINCH` set in SF Pro Display, semibold, tracking +20, with the `I` reduced in stroke weight and crossed by a 4°-rotated bolt accent in `Bolt Blue`. Used at small sizes the bolt becomes a dot.

### App icon (1024×1024)

- Black-to-deep-blue radial gradient background
- Centered bolt glyph filled with a vertical Bolt Blue → Current Cyan linear gradient
- Bottom 30% of the bolt dissolves into three downward wave strokes, decreasing in opacity
- Subtle inner shadow on the bolt, rim highlight along the top edge
- No text in the icon

### Sound

- One sound only: `completion.aiff`, ≤300ms, two-note ascending soft "ting" at -16 LUFS. Off by default. Played via `NSSound` (not via NotificationCenter's default sound).

---

## 28. Appendix B — Sample User Flows

### Flow A — "I just copied a magnet from a forum"

1. User has Minch's menu bar icon visible. They copied a magnet 5s ago.
2. They press `⌃⌥Space` (their globally-bound Minch hotkey).
3. Command palette opens; placeholder reads `"Search transfers, run commands…"`.
4. They type `add` → top result: "Add magnet from clipboard". `↩︎`.
5. A toast slides in from the top-right of the screen: "Added: The.Big.Lebowski.1998.1080p". The palette closes.
6. The menu bar glyph begins its pulse.
7. 4 minutes later, a system notification: "The Big Lebowski downloaded. ▷ Play · Reveal".

Total interactions: 1 hotkey + 3 letters + Return. No window.

### Flow B — "I want to watch this on the TV"

1. User opens Minch (`⌘Space → minch → ↩︎`).
2. Library → Downloaded → first row.
3. `Space` → Quick Look preview (poster + metadata).
4. `⌘↩︎` → opens player.
5. HUD AirPlay button → picks Living Room. Playback hands off.

### Flow C — "Bulk import a folder of .torrent files"

1. User drags a folder from Finder onto Minch's dock icon (or menu bar icon).
2. Confirmation sheet: "Add 17 torrents to TorBox? · Tag: ___ · Auto-download: [✓]"
3. `↩︎` → 17 rows fly in, queued.
4. Watch folder behavior optionally configured: future drops happen automatically.

---

## 29. Appendix C — Sample Data Shapes (JSON, internal types)

> Wire format from TorBox is *not* the type we ship in `MinchKit`. Below is the internal `Transfer` shape (sketch).

```jsonc
{
  "id": "tb_01HXAB...",
  "hash": "5e8a...",
  "name": "The.Bear.S03.1080p.WEB-DL.x265-GROUP",
  "kind": "torrent",
  "addedAt": "2026-05-25T13:11:04Z",
  "sizeBytes": 23847234234,
  "status": "downloading",
  "progress": 0.62,
  "downloadSpeed": 24234234,
  "uploadSpeed": 0,
  "eta": 240,
  "availability": 1.0,
  "tags": ["tv", "favorites"],
  "files": [
    {
      "id": "tb_file_...",
      "name": "S03E01.mkv",
      "pathInTransfer": "The.Bear.S03/S03E01.mkv",
      "sizeBytes": 2342342342,
      "mime": "video/x-matroska",
      "isDownloaded": false,
      "playbackPositionSec": 412.3
    }
  ],
  "lastSyncedAt": "2026-05-25T13:14:22Z"
}
```

---

## 30. Definition of "Done" for 1.0

- All §3 features implemented, no `TODO` in production paths.
- §10 performance targets met on M1, M2, M3, M4 + 2018 Mac mini Intel reference.
- AX audit clean (VoiceOver, Voice Control, Full Keyboard Access, Reduce Motion, Increase Contrast).
- Sandboxed, hardened-runtime, notarized, Sparkle-updated DMG.
- All copy localized to `en`; localization infrastructure in place.
- `docs/PRD.md` (this doc), `docs/PRIVACY.md`, `docs/SCRIPTING.md`, `docs/CLI.md` shipped.
- 80%+ unit test coverage on `MinchKit`, `MinchAPI`, `MinchPersistence`, `MinchSearch`.
- Snapshot tests on the design system (light/dark, regular/XXL Dynamic Type).
- A six-person private beta has used the app daily for two weeks without a P0.

---

*End of PRD.*
