# F112 — What A Piece Of Work Did, In Words

**Status:** Analyzed; blocked by `sokar`: a method for a running task's commits and their diff since
it started (to be opened by Agent Core).
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
  the method comes from `sokar`, and `SokarClient`, `FleetBackend` and the stand-in take it.
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

## To be checked

- **The method's name and shape** for a running task's commits and diff, once Agent Core writes its
  issue. (Agent Core's)
