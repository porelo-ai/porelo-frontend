# F457 — Needs You Names The One Thing To Do

**Status:** Implementing, part 4 first: the pull request on a host's forge and the done task's own state, freed by
Porelo's `PullRequests`/`WatchPullRequests` and the task state `done` (2026-11-10).
**Size:** L - grown from M at its plan reading: *Needs you* split into one row per cause across the attention model,
the task model and four views; a seen mark kept safely; a project in class `online` said alike on every screen; built
in three parts.

**What must be true.** Each item under *Needs you* says what the person must do and offers that one action; it goes
away when its cause ends; an item that only informs can be marked seen; and nothing there contradicts what the gate
or the forge says.
- An item names its action: "pull request 1 waits for your approval and merge", opening the pull request on the
  host's forge; it does not embed the task's tile, which stays in *Work*.
- It closes itself when its cause ends (merged or closed); one that only informs has *Seen*, and stays gone.
- A project in class `online`, whose pushes pass the gate at once, shows no "its commit waits at the gate" and no
  item for it.
- A task that said it is done and stopped is shown as done in *Work* and under *Needs you*, not as running.
- The commit's makers - author, committer, trailers - are seen on the item that asks for a review.

## Plan

Read in today's code at its plan reading; the parts are built in this order, each with its own red tests.

1. **One row per cause, one action each** (`lib/src/app/attention.dart`, `lib/src/ui/attention_view.dart`).
   `Attention._tilesOf` makes one tile per task today, so a question hides an ended agent, and an ended agent a push at
   the gate. Each open prompt, each unseen ended agent and each push at the gate becomes a row of its own, with its own
   id in `_keepOutcomes`. A row names its action and offers it; a decision keeps both its answers (allow and refuse,
   *Keep it blocked*, *Rework…*) and a held message is still read before it is decided. The task's tile is no longer
   embedded: what only it said and a person must still see - `unenforced` clearance, asked before, a prompt's deadline,
   files changed that never reached the gate (`ended.unpushed`), a prompt with no task - moves onto the cause's row.
2. **Seen, only for what informs** (`attention.dart`, the settings it keeps today: `seenSilent`, `endedPutAway`,
   `ranOut`). *Seen* is offered only where nothing is owed: a silent task, an ended agent with nothing unpushed, ran
   out, missed, set aside, a story's work ended, a failed operation. A mark's key holds the occurrence (its time or
   count), never an error's text, so a later failure of the same task shows again. Marks are pruned only once the
   settings are loaded and the source that names the cause is read whole (a machine connected with its list read, a
   board live and complete); a stream-only cause keeps its mark for a bounded time.
3. **A project in class `online`, said alike everywhere** (`Attention.demandOf`, `Task.atTheGate` in
   `lib/src/client/models.dart`, `TaskTile`, `WorkRow`, `_WorkFacts`, `ProjectsPage`, `MachineTree`). What a real host
   answers for `waiting` and `pending` of an `online` project is measured first; an `online` task or project derives
   no waiting-at-the-gate words or row on any screen, while a push the daemon's `Pending` still lists is shown, never
   hidden; an unread or empty class is not taken for `online`.
4. **Blocked, not built here:** the pull request on a host's forge (its approval and merge as the one action, the row
   closing when it merges or closes) needs a call of `org.fuin.porelo.Tasks1` that reports a host forge's open pull
   requests, their makers and their end; it is in `doc/Contract-Gaps.md`. The window never asks a forge over HTTP,
   and opens a pull request only at the address it builds from the host's forge forward, a repository path and a
   positive number. A done task's own state waits for the backend's; until then `Demand` keeps an ended or unknown
   activity apart from running, in the activity's own words, and a running count leaves it out.
- **The commit's makers** stand on a push's row as the gate's `Pending` reports them, run through the trailer check,
  said as the head commit's alone unless the push's commits were read, and "not reported" where absent.

## Acceptance

- The mock with an `online` project: no waiting item; with a pull request waiting: one item, one action, gone after
  the merge; an informing item marked seen stays gone after a restart. Seen to fail: the task tile inside an item.
