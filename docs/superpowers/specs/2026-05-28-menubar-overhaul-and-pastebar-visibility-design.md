# Design Spec: Menu Bar App Design Overhaul & Main Window Paste Bar Visibility

**Date:** 2026-05-28
**Status:** Approved

## 1. Goal Description

This specification addresses two key user experience improvements for Minch:
1. **Paste/Torrent Add Bar Visibility:** The paste magnet/torrent input bar (`AddMagnetBar`) in the main window should be visible across all tabs (not just on the "Active" tab) and remain frozen (sticky) at the top of the content pane.
2. **Menu Bar App Design Overhaul:** The menu bar popover needs a major visual and interactive design overhaul. It must offer:
   * A highly visible and intuitive drag-and-drop zone that doubles as the manual magnet/link text input.
   * A premium, unified, and highly informative active downloads list displaying transfer name, status, progress bar, speeds, and ETAs.
   * Action buttons (Pause/Resume, Cancel/Delete, Reveal in Finder) that appear on hover for each transfer.
   * Quota/subscription status info integrated into the header.

---

## 2. Proposed Changes

### Component 1: Main Window Paste Bar Visibility

#### [MODIFY] [LibraryView.swift](file:///Users/ahegde/projects/Minch/App/Minch/LibraryView.swift)
* Move the `AddMagnetBar` call in `LibraryContent` outside the `selection == .active` conditional check.
* Position it directly under `SearchBar` and above the error/info banners.
* This ensures that it is visible on all tabs (Active, Downloaded, Videos, Audio, Recent). Because the bar is outside the `LibraryList` scroll view, it will remain frozen at the top.

---

### Component 2: Menu Bar Popover Design Overhaul

#### [MODIFY] [MenuBarView.swift](file:///Users/ahegde/projects/Minch/App/Minch/MenuBarView.swift)

##### 1. Header Account & State Display
* Update the header section to display:
  * A styled leading brand mark: SF Symbol `bolt.fill` in `Color.minchBolt` followed by "Minch" in `.minchHeadline`.
  * A trailing subscription chip: Displays the plan name (e.g. `Pro` or `Free`) with a status dot indicator (using `MinchAccountChip.statusDotColor(isSubscribed:)`) representing account status.
  * An alignment-friendly background refresh spinner next to the plan name.

##### 2. Combined Drop Zone & Text Input Card ("Drop Card")
* Create a dedicated container for magnet link addition and drag-and-drop:
  * Renders with rounded corners (`MinchRadius.m`), `Color.minchSurfaceSunken` background, and a dashed border (`Color.minchHairline`).
  * Inside, shows a prominent center icon (`tray.and.arrow.down` or similar) with the text *"Drag & drop .torrent/magnet or paste link"*.
  * Integrates the quick-add text field (`TextField`) underneath, accompanied by a clean "Add" button.
  * **Interactive State:** If `isTargeted` (drag hovering over the popover) is true, the dashed border becomes solid `Color.minchBolt` with a glowing outline, and the icon pulses.

##### 3. Premium Interactive Transfer & Download Rows
* Define a modern, interactive design for both `MenuBarTransferRow` and `MenuBarLocalDownloadRow`:
  * Use a custom `.onHover` handler on each row to track when the mouse cursor is over it.
  * When **not hovered**, the row displays:
    * The transfer/download name.
    * A thin, sleek progress bar (using `Color.minchBolt`).
    * An inline metadata string: progress percentage, speed, and ETA (e.g., `12.5 MB/s · 2m 14s remaining (72%)`).
  * When **hovered**, the metadata string transitions (cross-fade or slide) to display compact control buttons:
    * **Pause/Resume** (triggering TorBox API call via `AppModel`).
    * **Cancel/Delete** (triggering TorBox API call via `AppModel`).
    * **Reveal in Finder** (if the file is downloaded locally or is a local download task).
  * Ensure the text uses `monospacedDigit()` and `.minchMono` for all numbers, speeds, and ETAs.

##### 4. Footer Clean-up
* Format the footer buttons neatly. "Open Minch" becomes a prominent action styled with `.buttonStyle(.minch(.primary))`.
* "Refresh" and "Quit" are laid out side-by-side using the secondary/ghost button styling, separated nicely with spacers.

---

## 3. Verification Plan

### Automated Tests
* Validate model persistence and state updates on `MenuBarView` drop events.
* Ensure action button handlers on rows call `AppModel` methods correctly.

### Manual Verification
1. Open the main window and click on the "Downloaded", "Videos", "Audio", and "Recent" tabs. Verify that the "Paste a magnet or download link..." bar is visible and frozen at the top.
2. Verify that using the shortcut `⌘N` focuses the paste input field on all tabs.
3. Open the Menu Bar app popover and confirm the new layout:
   * Header shows user's active plan (e.g. Pro/Free) and status dot.
   * Drop card is visually distinct with a dashed border.
4. Drag a `.torrent` file or a magnet link over the popover. Check that the drop zone border lights up in blue (`Color.minchBolt`). Drop the item and confirm it is successfully added to the active downloads.
5. While downloading, check the transfer rows in the popover:
   * Verify they display transfer speeds and ETAs when idle.
   * Hover over a row to confirm the metadata switches to control buttons (Pause, Cancel, Reveal).
   * Click Pause and Resume, verifying the state changes in real-time.
