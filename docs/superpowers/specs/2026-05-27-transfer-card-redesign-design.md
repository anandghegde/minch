# Transfer Card Redesign — Design Doc

> **STATUS: DRAFT — brainstorming in progress.** Not yet approved. Do NOT start
> implementation or invoke writing-plans until this doc is complete and the user
> has approved it. Resume the brainstorm from the "Open Question" section below.

**Sub-project:** #2 of ~7 in the Minch UI/UX redesign.

**Context for a fresh agent:**
- Sub-project #1 (Design Foundations v2) is **complete** — plumbing landed across
  6 commits (see `docs/superpowers/plans/2026-05-27-design-foundations-v2.md`).
  Its visual impact was negligible by design (token values sat within 1–2% gray
  of the originals); the user accepted keeping it as plumbing and moving on.
- This sub-project (#2) is where the user expects visible personality.
- Active brainstorming skill rules: one question at a time, multiple choice
  preferred, **no implementation until the design is approved**.

**Target file (primary):**
`Packages/MinchUI/Sources/MinchUI/MinchTransferRow.swift`

**Do NOT touch (user WIP):** `App/Minch/AppModel.swift`,
`App/Minch/SettingsView.swift`,
`Packages/MinchAPI/Sources/MinchAPI/TorBoxClient.swift`.

---

## Decisions locked so far

1. **Goal:** more personality / premium feel.
2. **Approach:** typography-driven, **no artwork** (no TMDB/poster fetching).
3. **Focal point:** the transfer name.
4. **Name treatment:** raw filename, monospace, tighter tracking;
   periods/underscores de-emphasized (lower opacity).
5. **Status glyph:** keep `MinchStatusGlyph` (the bolt) but add subtle
   phase-aware animation (pulse while downloading, settle on done, shake on error).
6. **Progress:** circular ring around the 28pt bolt glyph; ring grows as progress
   accrues (replaces the current linear progress bar in the row).
7. **Meta line:** adaptive per phase —
   - downloading: `speed · ETA · size`
   - done: `size · added X ago`
   - errored: error message
   - queued: queue position
8. **Hover:** **no row lift on hover** (drop the `MinchHoverable` lift for this row).

---

## Open Question (resume here)

With no hover lift, per-transfer actions (play, reveal, delete, etc.) need a home.
Where should they live? Options on the table:

- **Right-click context menu** — zero visual chrome, standard macOS gesture,
  scales to many actions.
- **Always-visible trailing icons** — small row of icon buttons on the right edge,
  present at rest (no hover needed).
- **In the expanded state only** — clicking the row expands it; actions appear
  there, keeping the collapsed row clean.
- **Selection-driven** — actions appear in a toolbar/inspector when the row is
  selected, not on the row itself.

## Still to discuss after the open question
- Row height / density (current row is 64pt).
- Expanded-state content (the row already supports `isExpanded` / `onToggle`).
