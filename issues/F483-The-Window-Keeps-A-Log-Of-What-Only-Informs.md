# F483 — The Window Keeps A Log Of What Only Informs

```json
{
  "$schema": "issue-1.json",
  "id": "F483",
  "title": "The Window Keeps A Log Of What Only Informs",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 5,
  "blockedBy": [],
  "covers": "The window writes a log of its own with levels, DEBUG, INFO, WARN and ERROR, in the log directory it shares with the planner, at the level set, INFO by default; what only informs, and every row put away, goes there, and Needs you keeps only what a person must act on, each row naming its action."
}
```

**Why this size.** A log of the window's own: a writer with levels and a bound on its length, the window's few lines
moved into it, and the routing in `Attention` of what only informs. The routing of planner rows waits on the planner
saying which of its entries ask for an action.

**What must be true.** A person looking at *Needs you* sees only what asks something of them, each row saying what to
do; what only informs is in the window's log, at the level set, and still is after a restart of the window.

## Why

- Serves porelo-project's *Logging in the frontend and the planner* (story ST318, porelo-project b08c20d).
- The window has no log of its own. Its few lines (`debugPrint` in `planning_reports.dart`, `stderr` in `main.dart`)
  go to the terminal it was started from, or, started from the desktop entry, to the session's journal (`journalctl
  --user`), where a person does not look. The only logs a person opens in the window are a task's own (`task.log`,
  `gate.log`; *Read a log* on a task, `lib/src/ui/log_view.dart`). So everything the window has to say lands in *Needs
  you*, also what asks nothing.

## Plan

- The log is `frontend.log` in `logs` under the window's state directory: `$XDG_STATE_HOME/porelo/logs` on Linux,
  `%LOCALAPPDATA%\porelo\logs` on Windows (`Desk.state` names the directory above it). The planner writes
  `planner.log` into the same directory, as agreed with the planner for ST318. One line per entry with its time,
  level, machine and words, never a secret; past 10 MB a new file is started and three older ones are kept, as the
  planner keeps its own.
- Levels DEBUG, INFO, WARN and ERROR. The level in force is read from the window's settings
  ([F485](README.md#f485)), INFO where none is set, and a change takes effect at once.
- The window's own lines go there: what `debugPrint` and `stderr` say today, a call to a machine that failed (WARN),
  what a refresh or a start did (INFO), what the window asked and was answered (DEBUG).
- `Attention` writes a row it no longer shows, put away or resolved, to the log at INFO; a planner entry the planner
  marks as information goes to the log alone.
- Each row left in *Needs you* names its action: a button, or words saying what to do where the action is elsewhere.

## To be checked

- Planner: how the board says an entry only informs, and what a reading stop asks of a person.
