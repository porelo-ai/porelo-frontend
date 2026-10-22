# F110 — An Unattended Run Ends With A Line

**Status:** Implementing.
**Size:** S - one line on the tile, from what the tile already knows; one module and its scenario.

**What must be true.** An unattended run's output ends with a line a person sees: that it finished,
and where to go next - a push waiting, or nothing done and why - not only a word in the header.

## Why

The first of three parts, in their order, of what a piece of work did made one page. After an
unattended run the most important thing is what it came to, and today the tile says it only in its
header.

## Plan

- **Where:** `TaskTile` in `lib/src/ui/attention_view.dart`, under the console (`TileConsole` in
  `lib/src/ui/tile_console.dart`), for `Mode.unattended` work whose agent ended (`task.agentEnded`).
- **What it says:** finished or stopped before its end (from `agentEnded`), and whether its work
  waits at the gate (`hasWorkWaiting`, as `tile-review` already knows); the line names the way to go
  next: the review at the gate, or the output above it, which is the run's log.
- **Red first:** three scenarios in `test/features/work_tiles.feature`: finished with work at the
  gate, finished with nothing there (and no review named), and stopped before its end.

## Acceptance

- A finished unattended run shows a line under its output: finished, and a push waiting with the
  way to the review, or nothing done and why. Seen to fail: a scenario where a finished unattended
  run shows no such line, or names a push where none waits.
