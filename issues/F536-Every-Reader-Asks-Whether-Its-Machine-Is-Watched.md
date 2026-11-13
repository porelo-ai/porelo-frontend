# F536 — Every Reader Asks Whether Its Machine Is Watched

```json
{
  "$schema": "issue-1.json",
  "id": "F536",
  "title": "Every Reader Asks Whether Its Machine Is Watched",
  "state": "Review",
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

The readers through `Machines.of`, `Machines.fleet` or `Attention.fleetOf`, as found before the work began:

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

Built in one issue, as commits that each pass on their own; the type checker finds the readers, so none is missed.

1. `shell.dart`'s `_fleet` becomes the fleet of the selected machine while it is watched, else null. Each build and
   menu draws null as not answering; each action on null changes nothing and says, in a notice, that the machine is
   not answering yet and what was not done. Red: an action on the selected machine while it reconnects (choosing a
   project, saying a line) is lost without a word.
2. `shell.dart`'s reads of `machines.of(...)` ask `watching` the same way, the machine's details and an unattended
   run follow the fleet that watches the machine (`Machines.follow`) instead of keeping the one handed once.
3. `attention_view.dart`'s `fleetOf`, and the pages: My machines, My projects, the machine's details, Work, the
   running view and the host dialog.
4. The app callers: the planning embedding and reports, where the person was, and the planner's chosen project.
5. The stand-in goes: `of` is for a caller holding a machine it opened, and throws for a machine not watched. Red: the
   window-level tests that draw every page and act while a machine reconnects
   (`test/ui/listed_not_watched_pages_test.dart`, `test/app/listed_not_watched_test.dart`) throw on any reader
   left; they pass once none is.

Each step adds to the widget tests of the window in which a machine is listed and not watched yet.

## How it was built

- `lib/src/app/commands.dart`, `lib/src/ui/status_line.dart`: the commands of the selected machine and its status
  line take a fleet that may be null; for null every command is unavailable because the machine is `not answering
  yet: it is being opened`, and the line says so.
- `lib/src/ui/shell.dart`: `_fleet` and every read of a machine ask `watching`. An action on a machine not watched
  changes nothing and says, in a notice (`not-watched-yet`), that it is not answering yet and nothing was done; a line
  said for it while it is not watched is shown as a notice too. A machine's section opened while it is not watched
  draws a page saying it is being opened (`not-watched-yet-page`).
- `lib/src/app/unattended_run.dart`: a run takes the machines and follows the fleet that watches its machine
  (`Machines.follow`), reading the run and its last line again from a fleet that replaced the first.
- `lib/src/app/attention.dart`, `lib/src/ui/attention_view.dart`: `fleetOf` may be null; a row's actions are then
  unavailable with the same reason, and a held message's or grant's row says the machine is being opened; *Seen* of
  dropped questions says why it cannot be pressed. My
  machines, My projects, the machine's details, Work, the running view and the host dialog read `watching`.
- `lib/src/app/where_you_were.dart`: the saved project and task are set on the machine's fleet once it is watched.
  The planning starts and reports, the agents offered and the planner's chosen project read `watching`; a planned
  start on a machine not watched is refused in words.
- `lib/src/app/machines.dart`, `lib/src/app/fleet_model.dart`: the stand-in is gone; `of` and `fleet` throw for a
  machine not watched.
- Tests, each red first: the selected machine reconnecting offers no refresh or reconnect and says why
  (`test/ui/listed_not_watched_pages_test.dart`); a run follows its machine through a reconnect
  (`test/ui/unattended_run_test.dart`); the place saved on a machine that reconnects is taken up once it is watched
  (`test/app/listed_not_watched_test.dart`). With the stand-in gone and the readers as they were before, the pages
  test throws in all three cases. Of the two app tests of the stand-in, one now checks that `of` throws for a machine
  not watched, so a reader left on it is found; the other, that a machine watched again is read, guarded nothing the
  other reconnect tests do not, and went. The pages and listeners moved in the third step change nothing a test can
  see while the stand-in stood; the last step's red covers them.
- Left as they are, from the code reading: two restores in one turn could let the first one's end stop the second's
  wait for the machine; `work.stop`, `work.resume` and `work.messages` give no reason, or another, for a fleet that is
  null, on a path nothing takes today; and a few actions in `shell.dart` keep the fleet they read across an await,
  which a disposed fleet ignores.
- Each step ran the tests built on what it changed (498, 601, 519, 365 and 409); the module suites ran on the build
  box at the end.
