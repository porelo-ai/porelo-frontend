# F459 — The Footer Counts What Runs Where

**Status:** Backlog.
**Size:** XS - two lines of the footer worded for the machine they count.

**What must be true.** The footer never reads as if nothing runs while a task and its workflows run: each count names
the machine it counts, and says what it counts.
- "Refreshed: 0 tasks" names the machine refreshed; tasks on another machine are not counted as none.
- "Actions: 0 running, 1 finished" counts this window's actions on the machine shown and says so, apart from the
  workflows a task runs.

## Plan

- `lib/src/app/fleet_model.dart` (the refresh's sentence) and `lib/src/ui/status_line.dart` (the actions' indicator)
  name the machine and what they count. Wording only: no test.

## Acceptance

- With a task running on a host and none here, the footer names the machine of each count.
