# F229 — A Restarted Task Says So In Its Terminal

**Status:** Backlog; found in walk 21, placed in the backlog on the operator's word.
**Size:** S - a line in the task's terminal and on its tile naming when the task was started, set apart from what
was on its screen before, and their tests; about 1 hour.

**What must be true.** When a task's terminal is opened in the interface, its first line, drawn by the interface
above what the task's screen shows, says when the task was started: *sluice, started 20:10 — anything above this line
is from before*. A tile's mini console says the same in its header (*started 20:10*). After a stop and a start, what
the agent still shows from its earlier session can no longer be read as its answer now.

## Why

Seen in walk 21 (sluice-dry, 20:13 local): after `porelo task stop` and `task start` of `porelo-sluice-dry-sluice`,
its terminal still showed the old session's *OAuth token revoked · Please run /login* at the top, as if it were the
current state; the broker's log showed the new start's answers were 429s, not the revoked sign-in. The operator called
it misleading and asked for a visible separator after a restart.

## Plan

- The task's start time is in its listing already (`TaskRow.startedAt`, from `since`).
- `session_view.dart`: a dim line drawn by the interface directly above the terminal, with the task's name and
  `startedAt` in local time: anything its screen shows from before then is from an earlier start. Not written into
  the terminal's buffer: tmux draws on the alternate screen, which hides whatever was written before it. Where
  `startedAt` is unknown (a task from before the field), nothing is shown. `Session` carries `startedAt`, and
  opening the same task with another start opens a new session.
- The tile's mini console header names `started HH:MM`.
- **Red first:** a terminal opened on a task with `startedAt` shows that line before the attach's output; a tile
  shows its start time; a task without one shows neither.

## Acceptance

- After a task's stop and start, its terminal in the interface shows when it was started, above anything the agent
  redraws from before.
- Its tile says when it was started.
