# F223 — A Ready Server Runs Its Setup Again

```json
{
  "$schema": "issue-1.json",
  "id": "F223",
  "title": "A Ready Server Runs Its Setup Again",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 62,
  "blockedBy": [],
  "covers": "A ready rented server offers Run its setup again, which runs `up` in the interface's own run, a stop in it completed from Needs you."
}
```

**Why this size.** a *Run its setup again* action on a ready server's row and menu, through the run the interface already
keeps, and its tests.

**What must be true.** A rented server that is ready offers *Run its setup again* in its row's menu in Machines. It
runs `porelo-host up` for the project with the arguments its setup was made with, the setup's files uploaded again, in
the interface's own run: its protocol shows it as a new attempt, a stop it makes is completed from Needs you as at the
first setup, and the server stays ready in Machines while it runs.

## Why

On a ready server, the guides say "run `up` again from the interface", and the interface has no such action: *Try
again* is unavailable with "preparation has ended" once the server is ready, and nothing else runs `up`. Running it
from a terminal outside the interface hides the run from the interface, so a stop in it has nowhere to be completed.

## Plan

- `HostRuns` gains `again(project)`: a new attempt of the kept run, for a ready server only, refused while one runs
  or waits; the record's `preparing` stays unset, so the server stays listed as ready.
- The server's row menu in Machines gets *Run its setup again*, unavailable with its reason while a setup runs.
- **Red first:** on a ready server the action starts exactly one `up` with the record's arguments, and a stop in it
  shows in Needs you.

## Acceptance

- On a ready rented server, Run its setup again runs `up`, its protocol shows the new attempt, and the server stays
  in Machines.
- While it runs, the action is unavailable and says why.
