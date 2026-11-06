# F420 — The Gate View Says It Reads, And What Waits Stays Reachable

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the gate view shows that it reads, gathers the repositories it could not read into one line per cause
opened on demand, and keeps the waiting pushes and *Approve* on screen whatever the errors say.

**What must be true.** *Waiting at the gate* says at once that it reads the project's repositories, and how many; the
repositories it could not read are one line per cause ("16 repositories could not be read: no host key for
github.com"), opened on demand, in a box no taller than a few lines that scrolls; the pushes that wait, with their
commits and *Approve*, are always below it and reachable.

## Why

The operator's walk on the rehearsal VM (2026-11-06): opening the sluice task's commit under Needs you took very long
with no sign of working, then showed one error per repository of the project (16, each a failed `git clone` to GitHub
with its whole message), running out of the window's bottom with no scrollbar and no wheel: the waiting commit and
*Approve* below could not be reached.

- `lib/src/app/gate.dart` reads each repository's gate (`_readAgain`, one `Pending` per repository, all at once) and
  joins the refusals into one `problem` string.
- `lib/src/ui/gate_view.dart`: `GateProblem` is a plain `Text` in the view's `Column` above the `Expanded` list, so a
  long problem pushes the list out of the window.
- The long wait and the clones are porelo's (its gate's `Pending` makes a missing mirror from the upstream); Agent
  Core files that. The window still has to say it waits, and keep what it read reachable.

## Plan

- `gate.dart`: keeps the refusals per repository (`unread` as name and words) beside `problem`, and a `reading` state
  with the count from the start of `_readAgain` to its end.
- `gate_view.dart`: while reading, "Reading the gate of <n> repositories…" with a small ring; the refusals grouped by
  their words, one line each with the count and the names, opened on demand, in a box of bounded height that
  scrolls; the list below in the `Expanded` as today.
- **The test that goes red first:** a gate whose sixteen repositories refuse with a long message and whose one
  repository has a push waiting shows that push and its *Approve* within the view's height. It guards a commit that
  cannot be approved because errors cover it.
