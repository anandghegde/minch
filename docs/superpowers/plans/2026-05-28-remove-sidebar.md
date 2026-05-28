# Remove Sidebar + Merge Settings into Account — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Library `NavigationSplitView` + sidebar with a single-column layout, expose section filters as a pill bar, and absorb both the standalone `SettingsView` and a new "TorBox API key" rotation control into the existing `AccountView` sheet.

**Architecture:** `LibraryView` becomes a flat `VStack` (header → filter pills → search bar → magnet bar → list). `LibrarySection.settings` is removed. `SettingsView.swift` is deleted; its body migrates into a private `PreferencesSection` view inside `AccountView.swift`, alongside a new `APIKeySection` that drives a new `AppModel.replaceAPIKey(_:)` method. The unused `MinchSidebarRow` and `MinchSidebarFooter` packages are removed; `MinchAccountChip` is reused as the header account button.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing (`@Test`/`@Suite`), TorBox REST client (`MinchAPI.TorBoxClient`).

---

## File Map

**Delete:**
- `App/Minch/SettingsView.swift`
- `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`
- `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift`
- `Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift`
- `Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift`

**Modify:**
- `App/Minch/LibrarySection.swift` — drop `.settings` case + `isVisibleInSidebar`.
- `App/Minch/LibraryView.swift` — replace `NavigationSplitView` + `LibrarySidebar` with single-column layout + `FilterBar` + `HeaderAccountButton`. Drop `.settings` switch arms.
- `App/Minch/AccountView.swift` — add `APIKeySection`, `PreferencesSection`. Render after `usageSection`, before `subscriptionsSection`.
- `App/Minch/AppModel.swift` — extract `activate(client:account:persistKey:)` from `validate(key:persistOnSuccess:)`; add `replaceAPIKey(_:) async throws`; add `apiKeyMaskedSuffix` computed accessor; add `apiKeyChangeError`/`isReplacingAPIKey` state.

**No changes to:**
- `MinchAPI` package (existing client/`me()` is sufficient).
- Persistence layer (local SwiftData is intentionally kept on key rotation).
- `LibraryContent` body other than removing `.settings` branch.

---

## Task 1: Drop `.settings` from `LibrarySection`

**Files:**
- Modify: `App/Minch/LibrarySection.swift`

- [ ] **Step 1: Remove `.settings` case + `isVisibleInSidebar`**

Replace the entire file body:

```swift
import Foundation

/// Top-level filter selection in the Library window. Each case maps to a
/// pill in the filter bar (PRD §3.2 + 2026-05-28 sidebar-removal redesign).
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

- [ ] **Step 2: Build (expect failures in `LibraryView.swift` referencing `.settings`)**

Run: `swift build`
Expected: build fails with errors about `.settings` not being a member of `LibrarySection`. Those are addressed in Task 2 — leave broken.

- [ ] **Step 3: Do NOT commit yet**

This task's change does not stand alone — `LibraryView.swift` still references `.settings`. Commit happens after Task 2.

---

## Task 2: Add `AppModel.replaceAPIKey` (TDD)

**Files:**
- Modify: `App/Minch/AppModel.swift`
- Test: `App/Minch/AppModelTests.swift` *(new — see Step 1)*

> Note: this app target currently has no tests directory. The test file goes in `App/Minch/Tests/AppModelTests.swift` and is wired into the package as a separate test target. If you'd rather keep this in a sibling MinchAPI/MinchKit package, **don't** — `AppModel` lives in the executable target and isn't importable from packages.
>
> Pragmatic alternative used in this plan: write the tests in a new test target attached to the executable. Steps below cover the wiring.

- [ ] **Step 1: Add a test target to `Package.swift`**

Modify `Package.swift` — replace the `targets` array:

```swift
    targets: [
        .executableTarget(
            name: "Minch",
            dependencies: [
                .product(name: "MinchKit", package: "MinchKit"),
                .product(name: "MinchAPI", package: "MinchAPI"),
                .product(name: "MinchPersistence", package: "MinchPersistence"),
                .product(name: "MinchDownloads", package: "MinchDownloads"),
                .product(name: "MinchUI", package: "MinchUI"),
            ],
            path: "App/Minch",
            exclude: ["Info.plist", "AppIcon.icns"]
        ),
        .testTarget(
            name: "MinchTests",
            dependencies: ["Minch"],
            path: "App/MinchTests"
        ),
    ]
```

- [ ] **Step 2: Write the failing tests**

Create `App/MinchTests/AppModelReplaceAPIKeyTests.swift`:

```swift
import Foundation
import Testing
import MinchAPI
import MinchKit
@testable import Minch

@Suite("AppModel.replaceAPIKey")
@MainActor
struct AppModelReplaceAPIKeyTests {
    /// In-memory secret store so tests don't touch Keychain.
    final class StubSecretStore: SecretStore, @unchecked Sendable {
        var stored: [String: String] = [:]
        var writeCount = 0
        func read(_ key: String) async throws -> String? { stored[key] }
        func write(_ value: String, for key: String) async throws {
            stored[key] = value
            writeCount += 1
        }
        func delete(_ key: String) async throws { stored.removeValue(forKey: key) }
    }

    @Test
    func rejectsEmptyKey() async {
        let store = StubSecretStore()
        store.stored[SecretKey.torboxAPIKey] = "old-key"
        let model = AppModel(
            secretStore: store,
            clientFactory: { _ in TorBoxClient(keyProvider: StaticAPIKeyProvider("x")) }
        )
        await #expect(throws: APIError.self) {
            try await model.replaceAPIKey("   ")
        }
        // Old key is preserved.
        #expect(store.stored[SecretKey.torboxAPIKey] == "old-key")
    }

    @Test
    func failedValidationKeepsOldKey() async {
        let store = StubSecretStore()
        store.stored[SecretKey.torboxAPIKey] = "old-key"
        // clientFactory returns a client whose `me()` throws unauthorized.
        let model = AppModel(
            secretStore: store,
            clientFactory: { _ in
                TorBoxClient(
                    baseURL: URL(string: "http://127.0.0.1:1/never")!,
                    session: URLSession(configuration: .ephemeral),
                    keyProvider: StaticAPIKeyProvider("bad")
                )
            }
        )
        await #expect(throws: Error.self) {
            try await model.replaceAPIKey("new-but-broken")
        }
        #expect(store.stored[SecretKey.torboxAPIKey] == "old-key")
        #expect(store.writeCount == 0)
    }
}
```

- [ ] **Step 3: Run tests and verify they fail**

Run: `swift test --filter AppModelReplaceAPIKeyTests`
Expected: compile error "Value of type 'AppModel' has no member 'replaceAPIKey'".

- [ ] **Step 4: Refactor `validate` and add `replaceAPIKey`**

In `App/Minch/AppModel.swift`, replace the existing `validate(key:persistOnSuccess:)` method (line ~451) with:

```swift
    private func validate(key: String, persistOnSuccess: Bool) async throws {
        state = .validating
        let provider = StaticAPIKeyProvider(key)
        let candidate = clientFactory(provider)
        let account = try await candidate.me()
        if persistOnSuccess {
            try await secretStore.write(key, for: SecretKey.torboxAPIKey)
        }
        activate(client: candidate, signedInAs: account)
    }

    /// Wires up a freshly-validated client + sync engine and resumes polling.
    /// Shared by the initial sign-in path and `replaceAPIKey`.
    private func activate(client: TorBoxClient, signedInAs account: UserAccount) {
        self.client = client
        self.syncEngine = SyncEngine(container: container) { [client] in
            // Torrents and webdl share the SyncEngine's `[Transfer]` list and
            // its delete-absent reconciliation, so a fetch failure on either
            // surface MUST abort the merge — otherwise the failing surface's
            // rows get wiped from local storage.
            async let torrents = client.listTransfers()
            async let webdls = client.listWebDownloads()
            return try await torrents + webdls
        }
        state = .signedIn(account)
        startPolling()
        if !notificationsRequested {
            notificationsRequested = true
            Task { await notifier.requestAuthorizationIfNeeded() }
        }
        Task { await loadHosters() }
    }

    /// Validates a candidate key against `/user/me`, writes it to Keychain,
    /// swaps in the new client + sync engine, and keeps the existing local
    /// SwiftData rows. Throws on validation failure or empty input — the
    /// previous client and stored key are left untouched in that case.
    func replaceAPIKey(_ newKey: String) async throws {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.transport(URLError(.userAuthenticationRequired))
        }
        let provider = StaticAPIKeyProvider(trimmed)
        let candidate = clientFactory(provider)
        let account = try await candidate.me()  // may throw — propagated.
        try await secretStore.write(trimmed, for: SecretKey.torboxAPIKey)
        stopPolling()
        activate(client: candidate, signedInAs: account)
    }
```

> If `APIError.transport(URLError)` doesn't exist, look at the existing `friendlyMessage(for:)` switch in `AppModel.swift` to find the right unauthorized/validation case and use that. The point is: throw an `APIError`-shaped error that `friendlyMessage(for:)` can format.

- [ ] **Step 5: Run tests and verify they pass**

Run: `swift test --filter AppModelReplaceAPIKeyTests`
Expected: both tests pass. The "failedValidationKeepsOldKey" test relies on the bogus `127.0.0.1:1` URL throwing a transport error from `me()`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift App/Minch/AppModel.swift App/Minch/LibrarySection.swift App/MinchTests/AppModelReplaceAPIKeyTests.swift
git commit -m "feat(AppModel): add replaceAPIKey + drop LibrarySection.settings"
```

---

## Task 3: Build the filter pill bar

**Files:**
- Modify: `App/Minch/LibraryView.swift`

This task only adds the new view; it doesn't yet remove the sidebar. That happens in Task 4 so each task remains compilable.

- [ ] **Step 1: Add `FilterBar` private view at the bottom of `LibraryView.swift`**

Append to `LibraryView.swift` (after the existing private views):

```swift
// MARK: - Filter Bar

private struct FilterBar: View {
    @Binding var selection: LibrarySection
    let counts: [LibrarySection: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MinchSpacing.s) {
                ForEach(LibrarySection.allCases) { section in
                    FilterPill(
                        title: section.title,
                        count: counts[section] ?? 0,
                        isSelected: selection == section,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, MinchSpacing.xxl)
        }
        .padding(.vertical, MinchSpacing.s)
    }
}

private struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: MinchSpacing.xs) {
                Text(title)
                    .font(.minchCaption)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                if count > 0 {
                    Text("\(count)")
                        .font(.minchMetadata.monospacedDigit())
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
                }
            }
            .padding(.horizontal, MinchSpacing.m)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(background)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var background: Color {
        if isSelected { return .minchBolt }
        return isHovered ? .minchSurfaceCardHover : .minchSurfaceSunken
    }

    private var borderColor: Color {
        isSelected ? .clear : .minchHairline
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean (the new types are unused but compile).

- [ ] **Step 3: Don't commit yet**

Bundled with Task 4's commit.

---

## Task 4: Replace `NavigationSplitView` with single-column layout

**Files:**
- Modify: `App/Minch/LibraryView.swift`

- [ ] **Step 1: Replace the `body` of `LibraryView`**

In `App/Minch/LibraryView.swift`, replace the existing `var body: some View { … }` (lines ~25–87) with:

```swift
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfacePrimary, Color.minchSurfaceCard],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LibraryHeader(
                    title: selection.title,
                    count: filteredRows.count,
                    account: account,
                    openAccount: { showAccount = true }
                )

                FilterBar(
                    selection: $selection,
                    counts: [
                        .active: rows.lazy.filter { $0.statusRaw != "done" }.count,
                        .downloaded: rows.lazy.filter { $0.statusRaw == "done" }.count,
                        .videos: smartCount(.videos),
                        .audio: smartCount(.audio),
                        .recent: recentRows.count,
                    ]
                )

                LibraryContent(
                    model: model,
                    selection: selection,
                    rows: filteredRows,
                    searchQuery: $searchQuery,
                    paletteTarget: $paletteRequestedTarget,
                    focusMagnet: $focusMagnet
                )
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if rows.isEmpty { await model.refresh() }
        }
        .background(
            Button("") { paletteOpen = true }
                .keyboardShortcut("k", modifiers: [.command])
                .hidden()
        )
        .background(
            Button("") { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: [.command])
                .hidden()
        )
        .background(
            Button("") { focusMagnet = true }
                .keyboardShortcut("n", modifiers: [.command])
                .hidden()
        )
        .sheet(isPresented: $paletteOpen, onDismiss: { paletteInitialAction = nil }) {
            CommandPalette(
                initialAction: paletteInitialAction,
                onAction: handlePaletteAction,
                onDismiss: { paletteOpen = false }
            )
        }
        .sheet(isPresented: $showAccount) {
            AccountView(
                model: model,
                account: account,
                onDismiss: { showAccount = false },
                signOut: { Task { await model.signOut() } }
            )
        }
    }
```

- [ ] **Step 2: Delete the entire `LibrarySidebar` private struct**

In `App/Minch/LibraryView.swift`, remove the block from `// MARK: - Sidebar` through the end of `private struct LibrarySidebar { … }` (lines ~167–231).

- [ ] **Step 3: Drop the `.settings` arms in `LibraryView` and `LibraryContent`**

In `filteredRows` (lines ~89–104), remove:

```swift
        case .settings:
            base = []
```

In `count(for:)` if such a function still references `.settings`, remove that arm.

In `handlePaletteAction(_:)`, find and remove anything that sets `selection = .settings`. Existing palette has no settings command so this likely needs no change — confirm by grepping `\.settings` in the file after your edits.

In `LibraryContent.body` (lines ~243–end), remove the `if selection == .settings { SettingsView(...) } else { … }` branch and unwrap the body so the header/search/magnet/list always render. The block to replace is roughly:

```swift
            VStack(spacing: 0) {
                if selection == .settings {
                    SettingsView(model: model)
                } else {
                    ContentHeader(title: selection.title, count: rows.count)

                    SearchBar(query: $searchQuery)
                    // … rest unchanged
                }
            }
```

becomes:

```swift
            VStack(spacing: 0) {
                SearchBar(query: $searchQuery)
                // … rest unchanged (no ContentHeader — moved to LibraryHeader at top)
            }
```

> Note: the title/count is now in `LibraryHeader` above the FilterBar, so `ContentHeader` is no longer needed. Delete the `ContentHeader` private struct (lines ~400–418).

- [ ] **Step 4: Add the `LibraryHeader` private view**

Append to `App/Minch/LibraryView.swift`:

```swift
// MARK: - Library Header

private struct LibraryHeader: View {
    let title: String
    let count: Int
    let account: UserAccount
    let openAccount: () -> Void

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Text(title)
                .font(.minchTitle)
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.minchCallout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            MinchAccountChip(
                name: account.email ?? "",
                email: account.email,
                planName: account.planName,
                isSubscribed: account.isSubscribed ?? false,
                action: openAccount
            )
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, MinchSpacing.xxl)
        .padding(.top, MinchSpacing.l)
        .padding(.bottom, MinchSpacing.s)
    }
}
```

- [ ] **Step 5: Remove the `MinchAccountChip` import from any sidebar-only context**

`MinchAccountChip` is still imported via `MinchUI`. No import changes needed — `LibraryView.swift` already has `import MinchUI`.

- [ ] **Step 6: Build**

Run: `swift build`
Expected: builds clean. If you see "Cannot find type 'SettingsView'", confirm Step 3 removed all references.

- [ ] **Step 7: Run the app and smoke-test manually**

Run: `swift run Minch` (or open in Xcode and run).
Verify:
- Sidebar is gone.
- Filter pills appear above the search bar; clicking each filter narrows the list correctly.
- Account chip in top-right opens the Account sheet.
- `⌘N` focuses the magnet field.
- `⌘K` opens the command palette.
- `⌘R` triggers refresh.
- The "Settings" surface is no longer accessible (will be re-added inside Account sheet in Task 5).

If verification fails on the UI, fix before committing.

- [ ] **Step 8: Commit**

```bash
git add App/Minch/LibraryView.swift
git commit -m "feat(Library): replace sidebar with filter pill bar + header account button"
```

---

## Task 5: Move Settings into Account sheet as `PreferencesSection`

**Files:**
- Modify: `App/Minch/AccountView.swift`
- Delete: `App/Minch/SettingsView.swift`

- [ ] **Step 1: Add `PreferencesSection` to `AccountView.swift`**

Append at the bottom of `AccountView.swift` (still inside the file, but after the closing brace of `struct AccountView`):

```swift
// MARK: - Preferences (TorBox server-side)

private struct PreferencesSection: View {
    @Bindable var model: AppModel

    /// Keys we expose, in display order. Matches the previous SettingsView allowlist.
    private static let allowedKeys: [String] = [
        "seed_torrents",
        "allow_zipped",
        "download_speed_in_tab",
        "show_tracker_in_torrent"
    ]

    private static let tooltips: [String: String] = [
        "seed_torrents": "Whether your finished torrents keep seeding back to the swarm.",
        "allow_zipped": "Let TorBox bundle multi-file downloads into a single .zip when requested.",
        "download_speed_in_tab": "Show current download speed in the browser tab / window title.",
        "show_tracker_in_torrent": "Display tracker URLs alongside torrent details."
    ]

    /// TorBox `seed_torrents` is a tri-state int (1=Auto, 2=Always, 3=Never).
    private static let seedTorrentsOptions: [(value: Int, label: String)] = [
        (1, "Auto"),
        (2, "Always"),
        (3, "Never")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            HStack(spacing: MinchSpacing.s) {
                Text("Preferences")
                    .font(.minchHeadline)
                Spacer()
                if model.isSavingSettings { ProgressView().controlSize(.small) }
            }

            if model.isLoadingSettings && model.settings == nil {
                ProgressView().controlSize(.small)
            } else if model.settings == nil {
                Text(model.settingsError ?? "Couldn't load preferences.")
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
                Button("Retry") { Task { await model.loadSettings() } }
                    .buttonStyle(.minch(.ghost))
            } else {
                ForEach(visibleKeys, id: \.self) { key in
                    fieldView(key: key)
                }
                if let error = model.settingsError {
                    Text(error)
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                }
                HStack {
                    Spacer()
                    Button("Save") { Task { await model.saveSettings() } }
                        .buttonStyle(.minch(.primary))
                        .disabled(model.isSavingSettings || !model.hasSettingsChanges)
                }
            }
        }
        .task { await model.loadSettings() }
    }

    private var visibleKeys: [String] {
        Self.allowedKeys.filter { model.settings?[$0] != nil }
    }

    private func label(for key: String) -> String {
        key.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    @ViewBuilder
    private func fieldView(key: String) -> some View {
        if let value = model.settings?[key] {
            let tooltip = Self.tooltips[key] ?? ""
            if key == "seed_torrents" {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label(for: key))
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: seedTorrentsBinding()) {
                        ForEach(Self.seedTorrentsOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
                .help(tooltip)
            } else {
                switch value {
                case .bool:
                    HStack {
                        Toggle(isOn: boolBinding(key)) {
                            Text(label(for: key))
                                .font(.minchCaption)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Spacer()
                    }
                    .help(tooltip)
                case .string, .null:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: key))
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        TextField(label(for: key), text: stringBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                    }
                    .help(tooltip)
                case .number:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: key))
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        TextField(label(for: key), text: numberBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                    }
                    .help(tooltip)
                }
            }
        }
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { model.settings?[key]?.boolValue ?? false },
            set: { model.updateSetting(key: key, value: .bool($0)) }
        )
    }

    private func stringBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { model.settings?[key]?.stringValue ?? "" },
            set: { model.updateSetting(key: key, value: .string($0)) }
        )
    }

    private func seedTorrentsBinding() -> Binding<Int> {
        Binding(
            get: {
                let raw = model.settings?["seed_torrents"]?.numberStringValue.flatMap(Int.init) ?? 1
                return Self.seedTorrentsOptions.contains { $0.value == raw } ? raw : 1
            },
            set: { model.updateSetting(key: "seed_torrents", value: .number(Double($0))) }
        )
    }

    private func numberBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { model.settings?[key]?.numberStringValue ?? "" },
            set: { raw in
                if raw.isEmpty {
                    model.updateSetting(key: key, value: .null)
                } else if let value = Double(raw) {
                    model.updateSetting(key: key, value: .number(value))
                }
            }
        )
    }
}
```

- [ ] **Step 2: Wire `PreferencesSection` into the sheet's body**

In `AccountView.swift`, in `body` (line ~14), update the `VStack` inside the `ScrollView` to:

```swift
            ScrollView {
                VStack(alignment: .leading, spacing: MinchSpacing.xl) {
                    planSection
                    usageSection
                    PreferencesSection(model: model)
                    subscriptionsSection
                    signOutSection
                    if let error = model.accountLoadError {
                        Text(error)
                            .font(.minchCaption)
                            .foregroundStyle(Color.minchDanger)
                    }
                }
                .padding(MinchSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
```

Also bump the sheet height — replace `.frame(width: 520, height: 560)` with `.frame(width: 520, height: 720)` to fit the new section without forcing a scroll for the common case.

- [ ] **Step 3: Delete `App/Minch/SettingsView.swift`**

```bash
rm App/Minch/SettingsView.swift
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds clean. If a leftover `SettingsView` reference exists, grep + remove it: `grep -rn "SettingsView" App/Minch`. (LibraryView's reference was removed in Task 4; double-check.)

- [ ] **Step 5: Smoke-test**

Run: `swift run Minch`. Open the Account sheet via the header chip. Verify:
- Plan / Usage sections render as before.
- Preferences section appears below Usage with the four expected fields once `loadSettings()` resolves.
- Save button enables only when a value is changed; Save persists and disables.

- [ ] **Step 6: Commit**

```bash
git add App/Minch/AccountView.swift
git rm App/Minch/SettingsView.swift
git commit -m "feat(Account): merge Settings into Account sheet as Preferences"
```

---

## Task 6: Add API key rotation control to Account sheet

**Files:**
- Modify: `App/Minch/AccountView.swift`

- [ ] **Step 1: Add `APIKeySection` private view**

Append to `AccountView.swift` (after `PreferencesSection`):

```swift
// MARK: - API Key

private struct APIKeySection: View {
    @Bindable var model: AppModel

    @State private var isEditing: Bool = false
    @State private var draftKey: String = ""
    @State private var inFlight: Bool = false
    @State private var localError: String?
    @State private var maskedDisplay: String = "••••••••"

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("TorBox API key")
                .font(.minchHeadline)

            if isEditing {
                SecureField("Paste your TorBox API key", text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(inFlight)
                if let localError {
                    Text(localError)
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        isEditing = false
                        draftKey = ""
                        localError = nil
                    }
                    .buttonStyle(.minch(.ghost))
                    .disabled(inFlight)
                    Button("Save") { Task { await save() } }
                        .buttonStyle(.minch(.primary))
                        .disabled(inFlight || draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                HStack {
                    Text(maskedDisplay)
                        .font(.minchCaption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Replace…") { isEditing = true }
                        .buttonStyle(.minch(.ghost))
                }
                Text("Stored locally in your macOS Keychain. Generate a new one at torbox.app/settings.")
                    .font(.minchMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await refreshMasked() }
    }

    private func refreshMasked() async {
        let suffix = await model.currentAPIKeyLast4() ?? ""
        maskedDisplay = suffix.isEmpty ? "••••••••" : "••••••••\(suffix)"
    }

    private func save() async {
        inFlight = true
        localError = nil
        do {
            try await model.replaceAPIKey(draftKey)
            isEditing = false
            draftKey = ""
            await refreshMasked()
        } catch {
            localError = model.friendlyAPIKeyError(error)
        }
        inFlight = false
    }
}
```

- [ ] **Step 2: Add helpers on `AppModel`**

In `App/Minch/AppModel.swift`, add these methods (anywhere in the class — put them next to `replaceAPIKey`):

```swift
    /// Last 4 characters of the currently-persisted key, or nil if no key
    /// is stored. Used by the Account sheet to render a masked display
    /// (`••••••••abcd`) without exposing the full secret.
    func currentAPIKeyLast4() async -> String? {
        guard let key = try? await secretStore.read(SecretKey.torboxAPIKey),
              let key, key.count >= 4 else { return nil }
        return String(key.suffix(4))
    }

    /// Maps an error from `replaceAPIKey` to a short user-facing string.
    /// Mirrors `friendlyMessage(for:)`'s style without making it public.
    func friendlyAPIKeyError(_ error: Error) -> String {
        if let api = error as? APIError {
            return friendlyMessage(for: api)
        }
        return "Couldn't update key. Check your connection and try again."
    }
```

> If `friendlyMessage(for:)` is private, either widen its access to internal in this file or duplicate the relevant message strings — duplicating is fine since this is a single fallback path.

- [ ] **Step 3: Wire `APIKeySection` into the sheet**

In `AccountView.body`, place `APIKeySection` immediately above `signOutSection`:

```swift
                    planSection
                    usageSection
                    PreferencesSection(model: model)
                    subscriptionsSection
                    APIKeySection(model: model)
                    signOutSection
```

> Per the design spec the API key control lives inside the Session group. Render order in code: `APIKeySection` → `signOutSection`. To keep them visually grouped under one "Session" heading, optionally drop the separate `signOutSection` heading and move the Sign-out button to the bottom of `APIKeySection`. Implementation note: simpler is to keep both as separate sections — the headers "TorBox API key" and "Session" read fine adjacent, and changes to either remain isolated.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 5: Manual smoke test**

Run: `swift run Minch`. Open the Account sheet.
Verify:
- A masked key like `••••••••XXXX` displays under "TorBox API key", where XXXX matches the last 4 of your real key.
- Clicking "Replace…" reveals a `SecureField` plus Save/Cancel.
- Pasting a bogus key + Save → red error appears, the original key is still present after closing/reopening the sheet (check by re-opening the app — it should still authenticate against TorBox).
- Pasting a fresh valid key + Save → masked display updates to the new last-4, the sheet returns to the masked state.

- [ ] **Step 6: Commit**

```bash
git add App/Minch/AccountView.swift App/Minch/AppModel.swift
git commit -m "feat(Account): add TorBox API key rotation control"
```

---

## Task 7: Delete unused MinchUI sidebar components

**Files:**
- Delete: `Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift`
- Delete: `Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift`
- Delete: `Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift`
- Delete: `Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift`

- [ ] **Step 1: Confirm there are no remaining usages**

Run:
```bash
grep -rn "MinchSidebarRow\|MinchSidebarFooter" App Packages
```

Expected: only the source/test files themselves match (no usages in `App/`).

- [ ] **Step 2: Delete the files**

```bash
rm Packages/MinchUI/Sources/MinchUI/MinchSidebarRow.swift
rm Packages/MinchUI/Sources/MinchUI/MinchSidebarFooter.swift
rm Packages/MinchUI/Tests/MinchUITests/MinchSidebarRowSelectionTests.swift
rm Packages/MinchUI/Tests/MinchUITests/MinchSidebarFooterTests.swift
```

- [ ] **Step 3: Build + test**

Run:
```bash
swift build
swift test
```

Expected: build is clean; all remaining tests pass. `MinchAccountChipTests` should still pass — `MinchAccountChip` is still in use.

- [ ] **Step 4: Commit**

```bash
git add -A Packages/MinchUI
git commit -m "chore(MinchUI): remove unused MinchSidebarRow + MinchSidebarFooter"
```

---

## Task 8: Final verification

- [ ] **Step 1: Full build + test pass**

Run:
```bash
swift build
swift test
```

Expected: zero warnings, zero failures.

- [ ] **Step 2: Manual end-to-end smoke test**

Run: `swift run Minch`.

Walk through:
1. Sign in with a valid TorBox key on a fresh keychain (delete the keychain entry first if needed). Confirm the Library window opens with the new layout.
2. Click each filter pill — list updates correctly.
3. Type in the search bar — filtering still works.
4. `⌘N` focuses the magnet bar.
5. `⌘K` opens command palette.
6. Click the header account chip → Account sheet opens. Verify all five sections render: Plan, Usage, Preferences, Subscriptions, TorBox API key, Session (Sign out).
7. Toggle a preference, Save — sheet shows saving spinner, returns clean.
8. Replace the API key with a bogus value — error renders inline, original key still works (close the sheet and re-open; the masked last 4 hasn't changed).
9. Replace the API key with a valid (regenerated-from-TorBox) key — masked display updates, transfers continue to refresh successfully.
10. Sign out — returns to the unauthenticated screen.

- [ ] **Step 3: No floating commits**

```bash
git status
```

Expected: clean working tree on `main` (or your feature branch).

- [ ] **Step 4: No further commits — implementation is complete.**

The user is responsible for the merge/PR decision. Stop here unless they say otherwise.

---

## Self-review notes

- **Spec coverage:** every section in the design spec has a task — sidebar removal (Task 4), filter pills (Task 3+4), single-column layout (Task 4), Account header button (Task 4 via `MinchAccountChip` reuse), Preferences merge (Task 5), API key control (Task 6), `replaceAPIKey` semantics (Task 2), MinchUI cleanup (Task 7).
- **Type consistency:** `replaceAPIKey(_:)`, `currentAPIKeyLast4()`, `friendlyAPIKeyError(_:)`, `activate(client:signedInAs:)` are referenced consistently across Tasks 2 and 6.
- **No placeholders:** every step contains the actual code or command. Two notes flag "if `APIError.transport(URLError)` doesn't exist" / "if `friendlyMessage(for:)` is private" — both give a concrete pivot, not a TODO.
- **Tests:** Task 2 introduces a small test target. Existing `MinchUI` tests are pruned in Task 7 to match the deletions.
- **Risk:** the new `App/MinchTests` target requires the executable target's symbols to be accessible. If `@testable import Minch` fails (e.g. unresolved framework signing), drop the test file and rely on the manual smoke test in Task 8 — the `replaceAPIKey` logic is short enough that this is acceptable, though less ideal.
