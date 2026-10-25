# F187 — Needs You As Compact Expandable Rows Without Pink Surfaces

**Status:** Implementing.
**Size:** L - `AttentionView` in `lib/src/ui/attention_view.dart` and 21 other files under `lib/src/ui/` using `errorContainer`.

**What must be true.** Every row under *Needs you* is a single-line row of fixed height (icon, short
title, the one button that resolves it on the right, and an expand arrow) that expands in place to
show the full explanation and any further actions; *Recently resolved* rows use the same single-line
row without the action button and stay expandable. The pink `errorContainer` fill is no longer used
as a card or notice surface across the interface, staying only on removed diff lines in a review and
on emergency stop and dangerous confirmations.

## Plan

- **Order.**
  - Build [F188](README.md#f188) first, which introduces the shared single-line expandable list-row
    component used across *Projects*, *Forges*, *Machines*, and *Needs you*; this issue builds
    *Needs you* and *Recently resolved* on that component and removes the `errorContainer` surface
    fills across `lib/src/ui/`.
- **Where it is today.**
  - `AttentionView` (`lib/src/ui/attention_view.dart`) renders each open item (`_MachineProblem`,
    `_VaultLocked`, `_MissingForgeKey`, `_SigningKeyNotice`, `_HostWaiting`, `_TileAttention`) and
    each resolved item (`_ResolvedAttention`) as a multi-line `Card` or `Container` with full
    paragraphs, multiple buttons, and `colorScheme.errorContainer` backgrounds.
  - `grep -rn 'errorContainer' lib/` finds 41 occurrences across 23 files in `lib/src/ui/`:
    1. `lib/src/ui/theme.dart` (2: lines 32, 69 — `ColorScheme` definitions `Primitives.redContainer` and `Primitives.deepRedContainer`, kept).
    2. `lib/src/ui/attention_view.dart` (7: lines 268, 293, 468, 552, 631, 756, 905 — card and chip fills on *Needs you* rows).
    3. `lib/src/ui/backups_view.dart` (3: lines 65, 75, 111 — backup/restore notice banners).
    4. `lib/src/ui/project_following_view.dart` (3: lines 90, 140, 145 — follow/unfollow problem blocks).
    5. `lib/src/ui/gate_view.dart` (3: line 333 dangerous-file row, line 475 `DiffLineKind.removed`, line 538 `GateProblem`).
    6. `lib/src/ui/host_readiness_view.dart` (2: lines 59, 66 — host readiness problem banners).
    7. `lib/src/ui/widening_view.dart` (2: lines 262, 338 — widening problem and notice surfaces).
    8. `lib/src/ui/start_work_view.dart` (2: lines 167, 663 — upstream/start problem banners).
    9. `lib/src/ui/connections_view.dart` (2: lines 76, 256 — connection error banners).
    10. `lib/src/ui/project_deletion_view.dart` (2: lines 53, 67 — deletion problem and dangerous forced-deletion confirmation block).
    11. `lib/src/ui/panes.dart` (1: line 177 — pane problem banner).
    12. `lib/src/ui/vault_view.dart` (1: line 58 — vault problem block).
    13. `lib/src/ui/operations.dart` (1: line 366 — failed operation banner).
    14. `lib/src/ui/log_view.dart` (1: line 158 — log error banner).
    15. `lib/src/ui/authentication_view.dart` (1: line 40 — authentication error block).
    16. `lib/src/ui/held_message_view.dart` (1: line 50 — refused held-message banner).
    17. `lib/src/ui/egress_view.dart` (1: line 39 — egress error block).
    18. `lib/src/ui/agents_view.dart` (1: line 35 — agents error block).
    19. `lib/src/ui/leaving.dart` (1: line 59 — quit warning block).
    20. `lib/src/ui/narrowing_view.dart` (1: line 229 — narrowing problem block).
    21. `lib/src/ui/session_view.dart` (1: line 119 — session error banner).
    22. `lib/src/ui/emergency_stop_view.dart` (1: line 99 — emergency stop confirmation block).
    23. `lib/src/ui/refusal.dart` (1: line 30 — refusal pane background).
- **Steps.**
  1. Refactor `AttentionView` (`lib/src/ui/attention_view.dart`) to render every row in `openRows`
     with the shared expandable list-row component from [F188](README.md#f188):
     - Collapsed single line: kind/state icon, short one-line title (`machine: what waits`), the
       single primary resolving button on the right (such as *Unlock*, *Open terminal*, *Go on*,
       *Reconnect*, *Review*), and the expand arrow.
     - Expanded area: the full explanation text and any secondary actions (such as *Stop following
       <project>*, *Remove*, or *Details*).
  2. Render every row under *Recently resolved* (`_ResolvedAttention` in
     `lib/src/ui/attention_view.dart`) with the same single-line component, without the resolving
     action button on the right, keeping the expand arrow so the person can still open the row to
     read what was resolved and how.
  3. Replace `errorContainer` surface fills with neutral surface tokens (`surfaceContainerLow` /
     `surfaceContainerHighest` with a subtle border or leading error icon) across `lib/src/ui/`,
     keeping `errorContainer` only on:
     - `lib/src/ui/theme.dart` (the theme token definitions),
     - `lib/src/ui/gate_view.dart` line 475 (`DiffLineKind.removed` in review diffs, and line 333 if
       kept as a dangerous-change indicator), and
     - `lib/src/ui/emergency_stop_view.dart` line 99 and the dangerous-confirmation blocks (such as
       forced deletion in `lib/src/ui/project_deletion_view.dart` line 67 and `lib/src/ui/refusal.dart`).
- **Tests, their harm, red first.**
  - None: row layout, expansion presentation, and surface colors are visual and layout changes;
    words, colors, and layout get no test. Existing tests in `test/attention_test.dart` and widget
    tests that click secondary actions inside `AttentionView` will be updated to expand the row
    before tapping secondary buttons that moved into the expanded section.

## Acceptance

- Every open item in *Needs you* is a single-line row of the shared height with an icon, short title,
  its resolving action button on the right, and an expand arrow; clicking the arrow reveals the
  explanation and any further actions below the line.
- Every item under *Recently resolved* is a single-line row without an action button and expands on
  clicking its arrow to show the details.
- Normal *Needs you* rows, status notices, and inline problem banners no longer render on pink
  `errorContainer` surfaces; `errorContainer` appears only on removed diff lines in reviews and on
  emergency stop and dangerous confirmations.
