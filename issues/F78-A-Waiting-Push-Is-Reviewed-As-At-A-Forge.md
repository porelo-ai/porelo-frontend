# F78 — A Waiting Push Is Reviewed As At A Forge

**Status:** Analyzed.
**Size:** M - the review's model and view are rewritten in one repository, with a new dependency for
syntax colors; it becomes L if showing the whole file needs a method from `sokar`.

**What must be true.** A person reads a waiting push the way they read a pull request at a forge,
not as git's change format.

## Why

The review shows git's diff, which is correct but made for a machine. The backend is short of
nothing.

## Plan

Read in today's code: `Gate` (`lib/src/app/gate.dart`) holds the push's `diff`, `ranked` and
`asked`; `parseUnifiedDiff` (`lib/src/app/diff.dart`) turns the diff into `ChangedFile`s of
`DiffLine`s; `ReviewView` (`lib/src/ui/gate_view.dart`) draws one list, a `_RankedFile` or `_File`
per file opening to its `_Line`s, with `_OwnClone` and *Copy the diff* in `_Decision`. One `Gate`
lives for the whole app (`lib/main.dart`), so what it keeps survives leaving the review.

- **Two panes.** `ReviewView` becomes a file list on the left, in `gate.ranked` order (or
  `gate.changed` from a Sokar that does not rank), and the chosen file on the right. Red first: the
  scenario "a push is reviewed in the order that matters" in `work_handover.feature`, asserting the
  left list's order.
- **Side by side or inline.** `diff.dart` gains a pairing of removed and added lines into rows for
  the side-by-side view; a switch in the right pane picks it or one under the other. Red first: a new
  widget test, `test/ui/review_diff_test.dart`, for the switch.
- **Syntax colors.** By file extension, with a highlighting package added to `pubspec.yaml` (none is
  there today) and its licence passing `test/licence_test.dart`.
- **Unchanged lines expandable.** Between hunks a row that opens the lines around them up to the whole
  file. `diff.dart` says no method reads a file at a revision; the whole file comes from a diff with
  full context or from the `PendingBundle` the fetch already uses.
- **Read ticks.** `Gate` keeps a set of read paths per push name and commit, cleared when the push is
  approved or dropped, and kept on disk per piece of work beside the operations record (the state
  folder `Desk.state`), so they survive a restart; a tick is void once the push's commit changes.
  Red first: a scenario in `work_handover.feature` that ticks a file, goes back to the gate and
  opens the push again, and one that restarts the interface and finds the tick, and none after a
  new commit.
- **Kept.** *Copy the diff* and `_OwnClone` stay in `_Decision` and above the list; the scenarios "a
  waiting push can be fetched" and "the diff leaves the interface in one action" stay green.

## Acceptance

- Files on the left, in the machine's order (what is dangerous by kind first, as now). Seen to fail:
  a scenario in `work_handover.feature` where the list is in another order.
- On the right, the file old and new side by side, or one under the other at a switch, with syntax
  colors, and the unchanged lines around a change expandable to the whole file. Seen to fail: a
  widget test where the switch, the colors or the expansion is missing.
- Each file can be ticked as read, and the review remembers it until the push is decided, across a
  restart of the interface, and forgets it once the work changes. Seen to fail: a scenario where a
  tick is lost on leaving and coming back, or after a restart, or kept for a new commit.
- Copying the diff and the fetch into one's own clone stay, for what an IDE does better. Seen to
  fail: the existing scenarios for both go red.

## To be checked

- Where the whole file comes from: `Review` answering more context or a file at a revision, or the
  interface reading the `PendingBundle` with git on this computer (Agent Core's, then Agent
  Frontend's).
- Which highlighting package, and whether its licence and size are acceptable (Agent Frontend's).
