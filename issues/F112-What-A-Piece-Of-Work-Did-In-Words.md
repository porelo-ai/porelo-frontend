# F112 — What A Piece Of Work Did, In Words

**Status:** Estimated; blocked by `sokar` [B174](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b174), "A Running Task's Commits And Their Diff".
**Size:** L - five kinds of facts at the top of every tile, one of which needs a new method of
`sokar`'s; crosses repositories.

**What must be true.** At the top of every piece of work a person reads what it did, in words: the
agent's last answer, its commits and their diff since it started, what of it waits at the gate, its
messages, and what the firewall stopped, the last only where something was.

## Why

The third of three parts of what a piece of work did made one page. `task.log` is one JSON object
per line, so the agent's own last answer, the most important thing after an unattended run, is
easily left unread.

## Plan

- **The last answer:** `Task.lastMessage`, which `sokar` answers already; shown as text.
- **The commits and their diff since it started:** no method answers them for a running task today
  (`workHeld` in `lib/src/app/work_held.dart` answers counts, `Review` only a push at the gate);
  `sokar` [B174](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b174) answers them: `TaskCommits(task)` the commits `WorkHeld` counts (commit, time, subject; for a
  stopped task from the note its stop wrote, with `asOf`), and `TaskDiff(task, commit?)` the patch
  of one or of all, cut at a file boundary with `files` whole. `SokarClient`, `FleetBackend` and the
  stand-in take both; a running task's diff is asked only when the person opens it.
- **What waits at the gate:** `Gate.waiting`. **Its messages:** `Mailboxes`. **What the firewall
  stopped:** the task's `events.jsonl`, shown only where it holds a line.
- **Where:** a section at the top of `TaskTile` in `lib/src/ui/attention_view.dart`.
- **Red first:** a scenario in `test/features/work_tiles.feature` with nothing stopped, which must
  show no firewall part; then one per kind of fact.

## Acceptance

- *What it did* at the top of every tile: the agent's last answer as text; its commits and their
  diff since it started; what of that waits at the gate; its messages; what the firewall stopped,
  only where something was. Seen to fail: a scenario in `work_tiles.feature` where any of these is
  missing, or the firewall part shows when nothing was stopped.

