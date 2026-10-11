# F110 — An Unattended Run Ends With A Line

**Status:** Analyzed.
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
- **What it says:** finished, and a push waiting (from the gate, as `tile-review` already knows), or
  nothing done; the line names the way to go next: the review, or the log.
- **Red first:** a scenario in `test/features/work_tiles.feature`, "a finished unattended run says it
  finished and where to go next", and its pair with nothing done.

## Acceptance

- A finished unattended run shows a line under its output: finished, and a push waiting with the
  way to the review, or nothing done and why. Seen to fail: a scenario where a finished unattended
  run shows no such line, or names a push where none waits.
