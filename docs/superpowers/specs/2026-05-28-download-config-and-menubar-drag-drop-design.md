# Design Spec: Download Folder Configuration & Menu Bar Enhancements

**Date:** 2026-05-28
**Status:** Approved

## 1. Goal Description

This specification defines the implementation details for three related features:
1. A configuration in Settings (`AccountView`) to choose a custom local download folder.
2. Drag-and-drop support in the Menu Bar app (`MenuBarView`) to add magnets and `.torrent` files by dragging them onto the popover.
3. Displaying actively downloading local files (transfers from TorBox CDN to the local Mac) in the Menu Bar app.

---

## 2. Proposed Changes

### Component 1: Local Settings (Download Folder)

#### AppModel Changes
* Add `customDownloadFolderURL: URL` as an observable property.
* In `AppModel.init()`, resolve the user's custom download folder by checking:
  1. Security-scoped bookmark `customDownloadFolderBookmark` in `UserDefaults`.
  2. Fallback path string `customDownloadFolderPath` in `UserDefaults`.
  3. Default fallback `DownloadManager.defaultDestinationRoot()`.
* Add `updateDownloadFolder(_ url: URL)` which:
  1. Requests/resolves a security-scoped bookmark for `url` and writes it to `UserDefaults`.
  2. Saves the path string to `UserDefaults`.
  3. Updates `customDownloadFolderURL`.
  4. Calls `downloads.setDestinationRoot(url)` to keep the download manager in sync.

#### DownloadManager Changes
* Make `destinationRoot` dynamic and thread-safe by protecting it with `lock` (it is an `@unchecked Sendable` class).
* Expose `public func setDestinationRoot(_ url: URL)`.
* In `urlSession(_:downloadTask:didFinishDownloadingTo:)`, before moving the completed download file to `info.destination`, call `destinationRoot.startAccessingSecurityScopedResource()` and balance it with `stopAccessingSecurityScopedResource()`. This ensures sandboxed write permissions are active if the folder is outside the standard sandbox containers.

#### AccountView Changes
* Add a `LocalPreferencesSection` below the TorBox server-side preferences.
* Render the current `customDownloadFolderURL.path` in a truncated, monospaced view.
* Provide a "Choose…" button that opens `NSOpenPanel` (configured with `canChooseDirectories = true`, `canChooseFiles = false`, `allowsMultipleSelection = false`).

---

### Component 2: Menu Bar Drag-and-Drop Ingestion

#### AppModel Changes
* Add an asynchronous helper method:
  `func ingestDroppedProviders(_ providers: [NSItemProvider]) async -> Bool`
* Inside, check `canLoadObject(ofClass: URL.self)` and `canLoadObject(ofClass: String.self)`.
  * If a file URL with extension `.torrent` is found, load its data and call `addTorrentFile()`.
  * If a magnet URL or string starting with `magnet:` is found, assign it to `pendingMagnet` and call `addMagnet()`.

#### MenuBarView Changes
* Add `@State private var isTargeted = false` to manage the hover/active drag state.
* Add `.onDrop(of: [.fileURL, .text], isTargeted: $isTargeted)` onto the main layout container (`VStack`).
* If `isTargeted` is true, change the container's background to `minchSurfaceSunken` and show a `minchBolt` border overlay.

---

### Component 3: Local Active Downloads in Menu Bar

#### AppModel Changes
* Define `InflightDownload` structure:
  ```swift
  struct InflightDownload: Identifiable {
      var id: String { fileID }
      let fileID: String
      let fileName: String
      let transferName: String
      let progress: Double
  }
  ```
* Add a computed property `activeLocalDownloads: [InflightDownload]` that fetches files corresponding to `inflightFileIDs` from the SwiftData context and merges their progress from `downloadProgress`.

#### MenuBarView Changes
* Add a `localDownloadsList` view component. If `model.activeLocalDownloads` is not empty, display it above the footer with a `MenuBarLocalDownloadRow` displaying the filename, progress bar, and percentage.

---

## 3. Verification Plan

### Automated Tests
* Add unit test in `MinchTests` validating `ingestDroppedProviders` parses file URLs and plain text correctly.
* Add test confirming fallback behaviors for resolving the destination root URL.

### Manual Verification
1. Open the Account window, change the download location to a custom folder outside of `~/Downloads`, and verify the path updates.
2. Download a file and verify it lands in the custom location.
3. Open the Menu Bar app, drag a `.torrent` file and hover over the window to verify the targeted border appears, then drop it and verify the transfer starts.
4. Drag a magnet link string and drop it onto the Menu Bar, verifying it starts downloading.
5. While downloading, check that the file is visible with active progress in the Menu Bar app.
