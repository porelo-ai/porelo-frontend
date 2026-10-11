# F77 — What A Piece Of Work Did Is One Page

**Status:** Analyzed.
**Size:** XL - five kinds of facts on the tile, a merged timeline and an end line; it splits into an
S (the end line), an M (the timeline) and an L (*What it did*, which needs answers from `sokar`).

**What must be true.** A person sees on one page what a piece of work did, in words, and one
timeline of everything that happened; the logs by source are for troubleshooting only.

## Why

A piece of work's logs are split by where they come from (firewall, DNS, vault, gate, agent), and
`task.log` is one JSON object per line, so the agent's own last answer is easily left unread. That
answer is the most important information after an unattended run and must be easy to reach.

## Plan

Read in today's code: the tile is `TaskTile` in `lib/src/ui/attention_view.dart`, its console
`TileConsole` in `lib/src/ui/tile_console.dart` (the last 5 lines of `task.log`, formatted); a log
is a `LogTail` in `Logs` (`lib/src/app/logs.dart`), drawn by `LogView` and chosen in `_WhichLog`
(`lib/src/ui/log_view.dart`). Lines come from `SokarClient.tailLog` as plain strings, with no time
of their own. Built as three issues, in this order:

- **The end line (S).** In `TaskTile`, for `Mode.unattended` work whose agent ended
  (`task.agentEnded`), a line under the console: finished, and a push waiting (from the gate, as
  `tile-review` already knows) or nothing done. Red first: a scenario in `work_tiles.feature`, "a
  finished unattended run says it finished and where to go next".
- **One timeline (M).** A new `Timeline` in `lib/src/app/` beside `Logs`, opening one `LogTail` per
  log `logsOf` names and merging their lines by a time read from each line; a source filter on it.
  `LogView` shows it first; the logs by source move under a fold, still opened as `LogOpened` in
  `lib/src/ui/shell.dart`. Red first: a scenario in `live_logs.feature` with two sources written
  out of order.
- **What it did (L).** A section at the top of `TaskTile`: the agent's last answer, its commits and
  diff since it started, what waits at the gate (`Gate.waiting`), its messages (`Mailboxes`), and
  what the firewall stopped (`events.jsonl`), the last only where it holds a line. The commits and
  diff of a running task have no method today: `workHeld` (`lib/src/app/work_held.dart`) answers
  counts, and `Review` only a push at the gate. Red first: a scenario in `work_tiles.feature` with
  nothing stopped, which must show no firewall part.

## Acceptance

- *What it did* at the top of every tile: the agent's last answer as text; its commits and their
  diff since it started; what of that waits at the gate; its messages; what the firewall stopped,
  only where something was. Seen to fail: a scenario in `work_tiles.feature` where any of these is
  missing, or the firewall part shows when nothing was stopped.
- *Everything*: all its logs in one timeline, by time, filterable by source. Seen to fail: a scenario
  in `live_logs.feature` where lines from two sources are out of time order or a filter leaves
  another source's line.
- The logs by source stay, folded away. Seen to fail: a scenario where one source's log cannot be
  opened.
- An unattended run's output ends with a line a person sees: finished, and where to go next (a push
  waiting, or nothing done and why), not only a word in the header. Seen to fail: a scenario where a
  finished unattended run shows no such line.

## To be checked

- Where the agent's last answer comes from: a field `sokar` answers, or the frontend picking it out
  of `task.log`, which is one JSON object per line in each agent's own shape (Agent Core's).
- Whether `sokar` answers the commits and diff of a running task since it started, since no method
  does today (Agent Core's).
- How each line gets its time for the timeline: a time field from `Tail`, or each source's format
  read here (Agent Core's).
- Whether F77 is split into the three issues the plan names before it is built (the operator's).
