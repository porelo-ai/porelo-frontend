# F483 — The Window Keeps A Log Of What Only Informs

```json
{
  "$schema": "issue-1.json",
  "id": "F483",
  "title": "The Window Keeps A Log Of What Only Informs",
  "state": "Idea",
  "size": "M",
  "priority": "High",
  "rank": 5,
  "blockedBy": [],
  "covers": "The window writes what only informs, and every row put away, to a log of its own under the person's state directory, and shows it in a view a person opens from the window; Needs you keeps only what a person must act on, each row naming its action."
}
```

**Why this size.** A new log of the window's: a file with a bound on its length, the view that reads it, the command
that opens it, and the routing in `Attention` of what only informs. The routing of planner rows waits on the planner
saying which of its entries ask for an action.

**What must be true.** A person looking at *Needs you* sees only what asks something of them, each row saying what to
do; what only informs can be read in the window's log, and still is after a restart of the window.

## Why

The window has no log of its own. Its few lines (`debugPrint` in `planning_reports.dart`, `stderr` in `main.dart`) go
to the terminal it was started from, or, started from the desktop entry, to the session's journal (`journalctl
--user`), where a person does not look. The only logs a person opens in the window are a task's own (`task.log`,
`gate.log`; *Read a log* on a task, `lib/src/ui/log_view.dart`). So everything the window has to say lands in *Needs
you*, also what asks nothing.

## Plan

- The log is `frontend.log` in the window's state directory, `$XDG_STATE_HOME/porelo` (`Desk.state` names it), one line per entry with its time, machine and words, cut to its newest lines past a bound.
- A view of it, drawn with `LogView`, opened by a command *Window log* in the menu and the command palette.
- `Attention` writes a row it no longer shows, put away or resolved, to the log; a planner entry the planner marks as
  information goes to the log alone.
- Each row left in *Needs you* names its action: a button, or words saying what to do where the action is elsewhere.

## To be checked

- Planner: how the board says an entry only informs, and what a reading stop asks of a person.
