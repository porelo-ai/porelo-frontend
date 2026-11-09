# F457 — Needs You Names The One Thing To Do

**Status:** Backlog; blocked, for the done task's own state, by the backend's state for a task that said it is done.
**Size:** M - *Needs you*'s items rebuilt around one action each, closing with their cause, a seen mark for those that
only inform, a done task shown as done, and the commit's makers shown.

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

- `lib/src/ui/attention_view.dart` and `lib/src/ui/running_view.dart`: an item takes its words and action from its
  cause (`lib/src/app/` attention sources), not from the task tile; the expanded tile is dropped there.
- The gate's class is read for the project; an `online` project derives no waiting-at-the-gate item.
- A seen mark is kept per item in the window's settings, keyed by the item's cause, and dropped with it.
- A done state is shown where the backend reports it; until then the item says what the machine reports and no more.
- Red first: a feature scenario with an `online` project whose push reached the forge, which today shows "waits at
  the gate" and *Needs you* 1.

## Acceptance

- The mock with an `online` project: no waiting item; with a pull request waiting: one item, one action, gone after
  the merge; an informing item marked seen stays gone after a restart. Seen to fail: the task tile inside an item.
