# Download Config & Menu Bar Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configuration in the Settings view to select a custom download folder, support dragging and dropping torrents/magnets onto the Menu Bar app to add them, and show actively downloading local files in the Menu Bar list.

**Architecture:** 
1. Use `UserDefaults` and a security-scoped bookmark to store and retrieve the custom download folder URL in `AppModel`.
2. Update `DownloadManager` dynamically when settings change, and wrap local file completion operations in a security-scoped access block.
3. Handle drop events on `MenuBarView` via SwiftUI `.onDrop` and parse items using a helper in `AppModel`.
4. Fetch active local downloads by joining `inflightFileIDs` with SwiftData context files.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UniformTypeIdentifiers, AppKit

---

### Task 1: Update DownloadManager & AppModel for custom download folder

**Files:**
- Modify: [DownloadManager.swift](file:///Users/ahegde/projects/Minch/Packages/MinchDownloads/Sources/MinchDownloads/DownloadManager.swift)
- Modify: [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift)
- Modify: [AppModelReplaceAPIKeyTests.swift](file:///Users/ahegde/projects/Minch/App/MinchTests/AppModelReplaceAPIKeyTests.swift)

- [ ] **Step 1: Update DownloadManager with dynamic destinationRoot and security-scoped access**
  In [DownloadManager.swift](file:///Users/ahegde/projects/Minch/Packages/MinchDownloads/Sources/MinchDownloads/DownloadManager.swift):
  - Change `private let destinationRoot: URL` to `private var destinationRoot: URL`.
  - Add thread-safe helper `public func setDestinationRoot(_ url: URL)`.
  - In `Inflight` struct, add `let rootURL: URL`.
  - In `start`, capture the current `destinationRoot` and store it in `Inflight.rootURL`.
  - In `urlSession(_:downloadTask:didFinishDownloadingTo:)`, wrap moving/copying the download file inside `info.rootURL.startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`.

- [ ] **Step 2: Add customDownloadFolderURL and updateDownloadFolder to AppModel**
  In [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift):
  - Add `var customDownloadFolderURL: URL` as a stored property.
  - In `AppModel.init()`, resolve the initial folder path from `UserDefaults` key `customDownloadFolderBookmark` (as a security-scoped bookmark) or fallback `customDownloadFolderPath` (as a path string) or default to `DownloadManager.defaultDestinationRoot()`.
  - In `AppModel.init()`, construct `self.downloads` with the initial custom URL.
  - Add `func updateDownloadFolder(_ url: URL)` that creates a security-scoped bookmark from the URL, writes it to `UserDefaults`, saves the path, and calls `downloads.setDestinationRoot(url)`.

- [ ] **Step 3: Write tests for download folder resolution**
  In [AppModelReplaceAPIKeyTests.swift](file:///Users/ahegde/projects/Minch/App/MinchTests/AppModelReplaceAPIKeyTests.swift):
  - Add a `@Test` that verifies `customDownloadFolderURL` defaults to `DownloadManager.defaultDestinationRoot()`.
  - Add a `@Test` that verifies updating the download folder persists the path in `UserDefaults` and updates `customDownloadFolderURL`.

- [ ] **Step 4: Run tests to verify they pass**
  Run: `swift test`
  Expected: PASS

- [ ] **Step 5: Commit changes**
  Run: `git add Packages/MinchDownloads/Sources/MinchDownloads/DownloadManager.swift App/Minch/AppModel.swift App/MinchTests/AppModelReplaceAPIKeyTests.swift && git commit -m "feat(download): support dynamic download folder with security scoped bookmarks"`

---

### Task 2: Build the Settings UI for local folder selection

**Files:**
- Modify: [AccountView.swift](file:///Users/ahegde/projects/Minch/App/Minch/AccountView.swift)

- [ ] **Step 1: Add LocalPreferencesSection in AccountView.swift**
  In [AccountView.swift](file:///Users/ahegde/projects/Minch/App/Minch/AccountView.swift):
  - Declare a new private struct `LocalPreferencesSection: View` that:
    - Renders "Local Preferences" section header.
    - Shows `model.customDownloadFolderURL.path` in monospaced format.
    - Provides a "Choose…" button that opens `NSOpenPanel`.
    - If `NSOpenPanel` runModal succeeds, calls `model.updateDownloadFolder(url)`.
  - Embed `LocalPreferencesSection(model: model)` below the server-side `PreferencesSection` inside the main scroll view.

- [ ] **Step 2: Build the project and run manual smoke test**
  Run: `swift build`
  Expected: Success

- [ ] **Step 3: Commit changes**
  Run: `git add App/Minch/AccountView.swift && git commit -m "feat(settings): add local preferences section with folder picker in settings sheet"`

---

### Task 3: Support Drag-and-Drop provider ingestion in AppModel

**Files:**
- Modify: [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift)
- Modify: [AppModelReplaceAPIKeyTests.swift](file:///Users/ahegde/projects/Minch/App/MinchTests/AppModelReplaceAPIKeyTests.swift)

- [ ] **Step 1: Add ingestDroppedProviders to AppModel**
  In [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift):
  - Add `func ingestDroppedProviders(_ providers: [NSItemProvider]) async -> Bool`
  - In this method, iterate over `providers`:
    - If provider is `URL.self`: load it, check if it's a file URL with `.torrent` extension, read its data, set `pendingTorrentFile`, and call `addTorrentFile()`. If it's a web URL starting with `magnet:`, set `pendingMagnet` and call `addMagnet()`.
    - If provider is `String.self`: load it, check if text starts with `magnet:`, set `pendingMagnet` and call `addMagnet()`.
    - Return `true` if any provider was successfully handled.

- [ ] **Step 2: Add tests for ingestDroppedProviders**
  In [AppModelReplaceAPIKeyTests.swift](file:///Users/ahegde/projects/Minch/App/MinchTests/AppModelReplaceAPIKeyTests.swift):
  - Add a `@Test` using mock `NSItemProvider`s to verify file URL drops (.torrent) and string/URL drops (magnet links) correctly parse and submit.

- [ ] **Step 3: Run tests and verify they pass**
  Run: `swift test`
  Expected: PASS

- [ ] **Step 4: Commit changes**
  Run: `git add App/Minch/AppModel.swift App/MinchTests/AppModelReplaceAPIKeyTests.swift && git commit -m "feat(model): add ingestDroppedProviders for magnet and torrent file drop support"`

---

### Task 4: Add Drag-and-Drop UI and hover effects to MenuBarView

**Files:**
- Modify: [MenuBarView.swift](file:///Users/ahegde/projects/Minch/App/Minch/MenuBarView.swift)

- [ ] **Step 1: Enable .onDrop on MenuBarView container**
  In [MenuBarView.swift](file:///Users/ahegde/projects/Minch/App/Minch/MenuBarView.swift):
  - Import `UniformTypeIdentifiers`.
  - Add `@State private var isTargeted = false` to track drag hover.
  - In `body`, append `.onDrop(of: [.fileURL, .text], isTargeted: $isTargeted)` on the outer `VStack`.
  - Perform ingestion by calling `_ = await model.ingestDroppedProviders(providers)` inside a `Task`.
  - Use `isTargeted` to visually update the background to `Color.minchSurfaceSunken` and draw a highlighted `Color.minchBolt` overlay border.

- [ ] **Step 2: Verify the project builds**
  Run: `swift build`
  Expected: Success

- [ ] **Step 3: Commit changes**
  Run: `git add App/Minch/MenuBarView.swift && git commit -m "feat(menubar): add drag-and-drop drop zone with active hover highlights to menu bar view"`

---

### Task 5: Implement active local downloads resolution in AppModel

**Files:**
- Modify: [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift)

- [ ] **Step 1: Add InflightDownload struct and activeLocalDownloads computed property**
  In [AppModel.swift](file:///Users/ahegde/projects/Minch/App/Minch/AppModel.swift):
  - Declare `public struct InflightDownload: Identifiable, Sendable` with `fileID`, `fileName`, `transferName`, `progress`.
  - Declare a computed property `var activeLocalDownloads: [InflightDownload]` that:
    - Queries the model container context for `StoredTransferFile` matching `inflightFileIDs`.
    - Maps the found files to `InflightDownload` containing file progress from `downloadProgress`.
    - Returns the list sorted by filename.

- [ ] **Step 2: Commit changes**
  Run: `git add App/Minch/AppModel.swift && git commit -m "feat(model): add activeLocalDownloads metadata helper for tracking inflight local downloads"`

---

### Task 6: Display active local downloads list in MenuBarView

**Files:**
- Modify: [MenuBarView.swift](file:///Users/ahegde/projects/Minch/App/Minch/MenuBarView.swift)

- [ ] **Step 1: Render Local Downloads section in MenuBarView**
  In [MenuBarView.swift](file:///Users/ahegde/projects/Minch/App/Minch/MenuBarView.swift):
  - Add a computed private view property `localDownloadsList: some View` showing headers and mapping `model.activeLocalDownloads` to `MenuBarLocalDownloadRow`.
  - Implement private struct `MenuBarLocalDownloadRow: View` rendering progress bar and percentage.
  - Insert `localDownloadsList` in `MenuBarView` case `.signedIn` above the footer (separated by a Divider) if `!model.inflightFileIDs.isEmpty`.

- [ ] **Step 2: Run all tests**
  Run: `swift test`
  Expected: PASS

- [ ] **Step 3: Commit changes**
  Run: `git add App/Minch/MenuBarView.swift && git commit -m "feat(menubar): render active local downloads section with real-time progress"`
