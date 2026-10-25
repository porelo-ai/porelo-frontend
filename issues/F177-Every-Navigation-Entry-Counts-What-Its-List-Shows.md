# F177 — Every Navigation Entry Counts What Its List Shows

**Status:** Analyzed.
**Size:** XS - `Shell._rail` in `lib/src/ui/shell.dart` and `Attention` in `lib/src/app/attention.dart`.

**What must be true.** Every entry in the left navigation rail that opens a list shows the count of
the rows that list shows — including servers in preparation and interrupted ones under *Machines*,
and every open row under *Needs you*.

## Plan

- **Where it is today.**
  - `Shell._rail` (`lib/src/ui/shell.dart`) builds `ShellRail` (`lib/src/ui/shell_rail.dart`) inside a
    `ListenableBuilder`. Its `Listenable.merge` listens to `_attention`, `widget.shell`, `_forges`,
    and each machine's `FleetModel`, but not to `widget.machines` (`Machines`) or `_hostRuns`
    (`HostRuns`).
  - For `machines`, `Shell._rail` passes `widget.machines.all.length`. `MachinesPage`
    (`lib/src/ui/machines_page.dart`) shows `_hostRuns.preparing` (running, waiting, failed, and
    interrupted server preparations) plus every machine in `widget.machines.all` whose name is not in
    `_hostRuns.preparing`. While a server is in preparation or interrupted before becoming a
    configured machine, *Machines* shows its row while the navigation rail shows `0`.
  - For `needing`, `Shell._rail` passes `_attention.needingSomebody`
    (`lib/src/app/attention.dart`), which filters `_openRows` so that `AttentionKind.tile` rows count
    only when `demand == Demand.question || demand == Demand.ended`, omitting gate reviews and
    settled tiles that `AttentionView` (`lib/src/ui/attention_view.dart`) lists under `openRows`.
  - For `work`, `Shell._rail` sums `widget.machines.of(machine).tasks.length` across machines,
    whereas `WorkPage` (`lib/src/ui/work_page.dart`) renders `_attention.tiles` (or the narrowed
    project's slice).
  - For `projects` and `forges`, `Shell._rail` already counts the same distinct non-`default`
    project names as `ProjectsPage` (`lib/src/ui/projects_page.dart`) and the same `_forges.entries`
    as `ForgesPage` (`lib/src/ui/forges_page.dart`).
- **Steps.**
  1. Add `widget.machines` and `_hostRuns` to the `Listenable.merge` list in `Shell._rail`
     (`lib/src/ui/shell.dart`) so the rail rebuilds whenever a machine or a `HostPreparation` in
     `_hostRuns.preparing` is added, updated, or removed.
  2. Compute the `machines` count in `Shell._rail` (or a helper shared with `MachinesPage` in
     `lib/src/ui/machines_page.dart`) as the number of rows `MachinesPage` shows:
     `_hostRuns.preparing.length` plus every `MachineEntry` in `widget.machines.all` whose name is
     not in `_hostRuns.preparing`.
  3. Pass `_attention.openRows.length` for `needing` and the count of rows `WorkPage` shows for
     `work` so every navigation badge equals the number of rows in the list it opens.
- **Tests, their harm, red first.**
  - None: a badge count in the navigation rail is a display count; words, colors, and layout get no
    test.

## Acceptance

- While a server is in preparation or its preparation is interrupted and no configured machine exists
  yet, *Machines* in the navigation rail shows `1`, matching the one row on the *Machines* page.
- When that server finishes setup and becomes a configured machine, the count stays `1` rather than
  jumping to `2` or `0`.
- For *Needs you*, *Work*, *Projects*, *Forges*, and *Machines*, the number on the navigation entry
  equals the number of rows shown on the page it opens.
