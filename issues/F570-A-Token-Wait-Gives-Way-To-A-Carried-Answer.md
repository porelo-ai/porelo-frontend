# F570 — A Token Wait Gives Way To A Carried Answer

```json
{
  "$schema": "issue-1.json",
  "id": "F570",
  "title": "A Token Wait Gives Way To A Carried Answer",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 15,
  "blockedBy": [],
  "covers": "Story ST361: once porelo answers that a project is carried, the window drops what it kept of an earlier token wait and stops offering the token, without a restart."
}
```

**Why this size.** The window's projects model and its watch: one stale state, one test.

**What must be true.** A machine's project page says what porelo says now.

## Plan

Found live: after the token took effect, the window still said that the project waits for the forge token.

Agent Core read porelod. It holds no cache of the host state. `Projects` reads it afresh on every call, and
`WatchProjects` pushes each change within 3 s. So the stale state is the window's. Either a WatchProjects stream ended
and was not opened again, or a model keeps `hostState` from an earlier answer (or the hand-over's) and does not replace
it on a Refresh.

- Find which, and fix it.
- Agent Core's B772 is rewritten or closed on this issue's finding.

## Acceptance

- The red test Agent Core named: a WatchProjects or Projects answer carrying hostState "carried" after one with "waiting-for-token" shows carried and drops *Give token*, with no restart. Also one where the watch stream ended.
