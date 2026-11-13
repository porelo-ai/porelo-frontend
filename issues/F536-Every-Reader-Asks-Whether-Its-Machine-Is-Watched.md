# F536 — Every Reader Asks Whether Its Machine Is Watched

```json
{
  "$schema": "issue-1.json",
  "id": "F536",
  "title": "Every Reader Asks Whether Its Machine Is Watched",
  "state": "Backlog",
  "size": "L",
  "priority": "Medium",
  "rank": 107,
  "blockedBy": [],
  "covers": "Every page, listener and action of the window asks whether a machine is watched before it reads that machine, and draws one listed and not watched yet as not answering, rather than relying on a stand-in the machine list hands out."
}
```

**Why this size.** L: about 250 reads in one large widget and several pages and listeners, each with a widget test of
the window in which a machine is listed and not watched yet. It splits into issues of M or smaller (below).

**How it stands.** A machine is listed and not watched yet while the window takes in its stored list, while a host's
card is replaced, and while a machine reconnects. In that time `Machines.of` and `Machines.fleet` hand a stand-in that
does not answer and refuses every call, as built for [F530](README.md#f530), so nothing throws; `Machines.watching`
answers null. The readers still read through `of` and so cannot tell a stand-in from the machine itself: an action
taken on a stand-in is refused as on a machine that does not answer, and what a page sets on it (a selected project, a
line said about a task) is lost when the machine is watched again.

**What must be true.**
- Every page, listener and action asks `watching` before it reads a machine, and draws or answers one that is not
  watched yet as not answering, in its own words.
- Nothing set on a machine while it is not watched yet is lost without a word.
- Once nothing reads through `of` for a machine not watched yet, the stand-in goes, and `of` is for a caller holding a
  machine it opened.

## Found

The readers through `Machines.of`, `Machines.fleet` or `Attention.fleetOf` (line numbers of 2026-11-13):

- `lib/src/ui/shell.dart`: 105 reads of `machines.of(...)` in about 70 methods - builds and menus (the rail at 5287,
  `_machineMenu` 1093, `_projectMenu` 1272, `_machinesFacts` 4639, `_workArea` 5443, `_projectPage` 6168), the
  listener `_leaveTheSignInsOfForgottenMachines` 2808, and the actions from 569 to 6742; and `_fleet` (335), read 123
  times, among them `_unscopedCommands` 903 on every build.
- `lib/src/ui/attention_view.dart`: 13 reads of `fleetOf` (316 to 801).
- The guards on `machines.all.contains`: `machines_page.dart` 147-148, `projects_page.dart` 70, 73, 113, 115,
  `machine_details_page.dart` 116.
- `lib/src/ui/work_page.dart` 332, 364, 369, 452, 630-631; `running_view.dart` 137, 288; `host_dialog.dart` 613.
- Readers that keep what `of` handed them past a reconnect, which may then be a stand-in no longer replaced: the
  machine's details in `shell.dart` (`Listenable.merge([_hostRuns, ... machines.of(machine)])`, near 6555) listen to
  it, and an unattended run (`UnattendedRun`, made in `shell.dart` near 3130) keeps it as its fleet.
- `lib/src/ui/planning_embedding.dart` 73, 492; `planning_reports.dart` 189; `lib/src/app/where_you_were.dart` 57;
  `lib/src/app/planner.dart` 162.

## Plan

Split into issues of M or smaller:
- `shell.dart`: `_fleet` and the builds first, then its actions.
- The pages: Needs you, My machines, My projects, the machine's details, Work and the running view.
- The app callers: the planning, where the person was, and the planner's chosen project.

Each with a widget test of the window that pumps frames while a machine is listed and not watched yet.
