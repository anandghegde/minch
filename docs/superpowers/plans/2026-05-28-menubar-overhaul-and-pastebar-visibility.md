# Menu Bar Overhaul & Paste Bar Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve visibility of the main window's torrent/magnet paste bar across all tabs, and perform a major design overhaul of the menu bar app to support drag-and-drop visual indicators, rich transfer info (speed/ETA), and hover control actions.

**Architecture:** Modify `LibraryView.swift` to place `AddMagnetBar` outside tab conditionals. Refactor `MenuBarView.swift` with custom layout cards, dashed-border states, custom row structures utilizing state-based hover checks (`isHovered`), and wire up pause/resume/delete actions back to `AppModel`.

**Tech Stack:** Swift, SwiftUI, SwiftData, MinchUI, MinchKit

---

### Task 1: Main Window Paste Bar Visibility

**Files:**
- Modify: `App/Minch/LibraryView.swift:198-200`

- [ ] **Step 1: Make AddMagnetBar visible on all tabs**
  * Open `App/Minch/LibraryView.swift`.
  * In the `LibraryContent` body, remove the `if selection == .active` conditional enclosing the `AddMagnetBar` component so that it displays on all tabs.
  * Target Content:
    ```swift
                if selection == .active {
                    AddMagnetBar(model: model, focusRequested: $focusMagnet)
                }
    ```
  * Replacement Content:
    ```swift
                AddMagnetBar(model: model, focusRequested: $focusMagnet)
    ```

- [ ] **Step 2: Commit**
  ```bash
  git add App/Minch/LibraryView.swift
  git commit -m "feat: show paste magnet bar on all tabs in main window"
  ```

---

### Task 2: Expose controlTransfer in AppModel

**Files:**
- Modify: `App/Minch/AppModel.swift:440` (below `deleteTransfer`)

- [ ] **Step 1: Add controlTransfer helper in AppModel**
  * Open `App/Minch/AppModel.swift`.
  * Add the following method below `deleteTransfer(_ transferID: String) async`:
    ```swift
        func controlTransfer(_ id: String, op: Endpoint.ControlOp) async {
            guard let client else { return }
            do {
                try await client.controlTransfer(id: id, op: op)
                await refresh()
            } catch {
                addError = "Failed to \(op.rawValue) transfer: \(error.localizedDescription)"
            }
        }
    ```

- [ ] **Step 2: Commit**
  ```bash
  git add App/Minch/AppModel.swift
  git commit -m "feat: expose controlTransfer in AppModel for pause/resume actions"
  ```

---

### Task 3: Overhaul Menu Bar App Layout & Styles

**Files:**
- Modify: `App/Minch/MenuBarView.swift`

- [ ] **Step 1: Redesign the Header & Drop Zone Quick Add Card**
  * Open `App/Minch/MenuBarView.swift`.
  * Modify `header` to display account subscription plan and status dot.
  * Modify `quickAdd` to render as a dashed-border card that highlights when a drag/drop is targeted over the popover.
  * Update `MenuBarView.body` switch case to pass the signed-in account to the header.

- [ ] **Step 2: Redesign MenuBarTransferRow and MenuBarLocalDownloadRow**
  * Define speed and ETA formatting helpers inside `MenuBarView.swift`.
  * Update the rows to track `@State private var isHovered = false`.
  * Lay out progress, percentage, speed, and ETA when not hovered.
  * Show Pause/Resume, Cancel/Delete, and Reveal-in-Finder buttons when hovered.

- [ ] **Step 3: Update overall container styling and footer button styles**
  * Apply `minchSurfacePrimary` and hairline border style to the body.
  * Replace the simple buttons in the footer with styled system buttons.

- [ ] **Step 4: Commit**
  ```bash
  git add App/Minch/MenuBarView.swift
  git commit -m "feat: overhaul menu bar view with premium card drop zone, account status, and interactive hover rows"
  ```
