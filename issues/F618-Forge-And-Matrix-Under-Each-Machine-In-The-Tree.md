# F618 — Forge And Matrix Under Each Machine In The Tree

```json
{
  "$schema": "issue-1.json",
  "id": "F618",
  "title": "Forge And Matrix Under Each Machine In The Tree",
  "state": "Analyzed",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "Under every machine, right after Projects, a Forge and a Matrix entry with a state dot (running, wants something, not installed) and a count of what waits for the person"
}
```

**Why this size.** S: one enum, the tree's leaf rows and their state and count, in two files with their tests; the
pages behind the entries and their data are other issues.

**What must be true.** Under this computer and under each host, right after *Projects*, the person sees *Forge* and
*Matrix*, each with a dot that says whether it runs, wants something or is not installed, and a count of what waits
for them there, so a glance at the tree shows where to look. On Windows and macOS this computer shows neither.

## Plan

- `lib/src/app/shell_model.dart`: `MachineSection` gains `forge` and `matrix` after `projects`.
- `lib/src/ui/shell_rail.dart`: a depth-2 leaf takes a state and a count as the top-level rows do today (`_TreeRow.state`,
  `count`); today a leaf has neither. The two leaves read them from one per-machine summary
  (`PartState { state: running | wants | absent | unknown, waiting }`) that the Forge and Matrix pages fill
  ([F619](README.md#f619), [F620](README.md#f620)); unknown (not read yet, not reachable) shows no dot and no count,
  never 0.
- This computer on Windows and macOS gets neither leaf (`Platform.isLinux`), as the story leaves them to a later one.
- `lib/src/ui/shell.dart` (`_machineSection`, `_readMachineSection`): the two sections route to their pages.
- Tests, widget level, red first: `test/ui/shell_rail_test.dart` (or the rail's existing test): the leaves stand right
  after *Projects* under each machine, an unknown state shows no count, and this computer off Linux has neither
  (harm: a part reads as fine or empty where it was never read).

## To be checked

- The rail's existing tests that count a machine's leaves, which move by two.
