# Minch

> Premium torrent streaming for Mac.

A native macOS client for [TorBox](https://torbox.app). Free, keyboard-first, privacy-respecting.

See [`docs/PRD.md`](docs/PRD.md) for the full product spec.

## Status

**Sprint 5** — Design system v1 + sidebar IA + Active/Downloaded sections. The main window is a `NavigationSplitView`: account chip and Library sidebar (Active, Downloaded) with live counts, content area filters by selection with per-section empty states. `MinchUI` now ships `MinchSidebarRow`, `MinchTransferRow`, `MinchStatusGlyph`, and surface tokens.

## Requirements

- macOS 15+ (Sequoia)
- Xcode 16+ / Swift 6+
- Apple Silicon recommended (Intel supported)

## Layout

```
Minch/
├── App/Minch/                # @main executable target
├── Packages/
│   ├── MinchKit/             # Sendable domain models
│   ├── MinchAPI/             # TorBox client (actor)
│   ├── MinchPersistence/     # SwiftData mirror
│   ├── MinchUI/              # Design system + components
│   ├── MinchDownloads/       # URLSession background downloads + notifications
│   └── MinchTesting/         # Shared fixtures
└── docs/
    └── PRD.md                # Full product requirements
```

Each package is independently buildable and testable:

```bash
swift build                          # Build the app
swift test                           # Test all reachable targets
cd Packages/MinchKit && swift test   # Test one package in isolation
swift run Minch                      # Launch the app
```

## Sprints

| Sprint | Goal | Status |
|---|---|---|
| 1 | Workspace + packages + minimal app | ✓ done |
| 2 | Keychain, onboarding, `TorBoxClient.me()` | ✓ done |
| 3 | SwiftData sync engine + list view | ✓ done |
| 4 | Background downloads + completion notifications | ✓ done |
| 5 | Design system v1 + sidebar IA + Active/Downloaded | **▷ now** |
| … | see [PRD §13](docs/PRD.md) | |

## License

TBD (will be MIT or Apache-2.0 by 1.0). Minch is fully free.
