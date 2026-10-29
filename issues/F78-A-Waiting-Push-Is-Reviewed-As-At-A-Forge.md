# F78 — A Waiting Push Is Reviewed As At A Forge

**Status:** Analyzed.
**Size:** M - one view (`lib/src/ui/gate_view.dart`), `Gate` (`lib/src/app/gate.dart`), `parseUnifiedDiff`
(`lib/src/app/diff.dart`), and a syntax-highlighting dependency, with Gherkin scenarios.

**What must be true.** A person reads a waiting push the way they read a pull request at a forge, not as git's change
format, with the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`) shown above the file list and
each file's risk class shown in the list.

## Why

The review shows git's diff, which is correct but made for a machine. Showing the files in risk order with their
per-file risk classes, side-by-side or inline diffs, expandable context, and commit-bound read ticks lets the person
review high-risk changes first without losing their place.

## Plan

Read in today's code: `Gate` (`lib/src/app/gate.dart`) holds the push's `diff`, `ranked` and `asked`;
`parseUnifiedDiff` (`lib/src/app/diff.dart`) turns the diff into `ChangedFile`s of `DiffLine`s; `ReviewView`
(`lib/src/ui/gate_view.dart`) draws one list, a `_RankedFile` or `_File` per file opening to its `_Line`s, with
`_OwnClone` and *Copy the diff* in `_Decision`. One `Gate` lives for the whole app (`lib/main.dart`), so what it keeps
survives leaving the review.

- **Two panes.** `ReviewView` (`lib/src/ui/gate_view.dart`) becomes a file list on the left, in `gate.ranked` order (or
  `gate.changed` from a Porelo that does not rank), and the chosen file on the right. Red first: the scenario "a push
  is reviewed in the order that matters, dangerous by kind first and volume last" in
  `test/features/work_handover.feature`, asserting the left list's order.
- **Source level and risk class header.** Above the file list, `ReviewView` displays the waiting push's source level
  (`E0`, `E1`, `I1`, `A`) and highest risk class (`C0`–`C3`), as the daemon reports them.
- **Per-file risk class.** Every file row in the left list shows its risk class (`C0`–`C3`) alongside `gate.ranked`'s
  reason.
- **Side by side or inline.** `lib/src/app/diff.dart` gains 1-based line numbers on `DiffLine` and a pairing of removed
  and added lines into rows for the side-by-side view; a switch in the right pane picks it or one under the other. Red
  first: a new widget test, `test/ui/review_diff_test.dart`, for the switch.
- **Syntax colors.** By file extension, with a highlighting package added to `pubspec.yaml` (none is there today) and
  its licence passing `test/licence_test.dart`.
- **Unchanged lines expandable.** Between hunks a row opens the lines around them up to the whole file, read from
  `FleetBackend.pendingBundle` (`lib/src/app/fleet_backend.dart`, Varlink `PendingBundle`) or from the daemon
  at the waiting commit SHA
  (`PendingPush.commit`) and base commit SHA.
- **Commit-bound read ticks.** `Gate` (`lib/src/app/gate.dart`) keeps a set of read paths per push name and commit,
  cleared when the push is approved or dropped, and kept on disk per piece of work beside the operations record (the
  state folder `Desk.state` in `lib/src/app/desk.dart`), so they survive a restart; read ticks are void whenever
  `PendingPush.commit` changes. Red first: a scenario in `test/features/work_handover.feature` that ticks a file, goes
  back to the gate and opens the push again, and one that restarts the interface and finds the tick, and none after a
  new commit.
- **Approve waits on every C3 file.** `_Decision` lists *Approve* as unable to run, with its reason, until every
  file of risk class `C3` in the push is ticked as read; a `C2` file needs no tick. Red first: a scenario that leaves
  one `C3` file unticked and finds *Approve* refused, and one with only `C2` files unticked that approves.
- **Bidi and control-character escaping.** Every line and text span rendered in `ReviewView` (diff lines in `_Line`,
  file paths in `_RankedFile` and `_File`, commit messages, and branch names) is rendered as plain text with Unicode
  bidi overrides (`U+202A`–`U+202E`, `U+2066`–`U+2069`) and control characters (`< 0x20` except `\t` and `\n`, plus
  `0x7F`–`0x9F`) escaped or shown as visible badges.
- **Kept.** *Copy the diff* and `_OwnClone` stay in `_Decision` and above the list; the scenarios "a waiting push can
  be fetched into the person's own clone" and "the diff leaves the interface in one action, for reading somewhere else"
  stay green.

## Acceptance

- Above the file list, `ReviewView` shows the push's source level (`E0`, `E1`, `I1`, `A`) and highest risk class
  (`C0`–`C3`), and each file on the left shows its own risk class (`C0`–`C3`) in the machine's order. Seen to fail: a
  scenario in `test/features/work_handover.feature` where the list is in another order or the source-level and
  risk-class badges are missing.
- On the right, the file shows old and new side by side, or one under the other at a switch, with syntax colors, and
  the unchanged lines around a change expandable to the whole file. Seen to fail: a widget test where the switch, the
  colors or the expansion is missing.
- Each file can be ticked as read, and the review remembers it until the push is decided, across a restart of the
  interface, and forgets it once `PendingPush.commit` changes. Seen to fail: a scenario where a tick is lost on leaving
  and coming back, or after a restart, or kept for a new commit.
- *Approve* cannot run while a `C3` file of the push is not ticked as read, and says so; unticked `C2` files do not
  hold it. Seen to fail: a scenario where an unticked `C3` file lets *Approve* run, or an unticked `C2` file stops it.
- Diff lines, file paths, commit subjects, and branch names containing Unicode bidi overrides or control characters
  render them as visible badges rather than interpreting them. Seen to fail: a widget test with `U+202E` in a diff line
  or file path.
- Copying the diff and the fetch into one's own clone stay, for what an IDE does better. Seen to fail: the existing
  scenarios for both go red.

## To be checked

- Where the whole file comes from: the daemon
  answering a file or context at the waiting commit and base commit, or the interface reading `PendingBundle` with git
  on this computer.
- Which highlighting package, and whether its licence and size pass `test/licence_test.dart`.
