# F223 — A Ready Server Runs Its Setup Again

**Status:** Implementing; built, not yet published.
**Size:** S - a *Run its setup again* action on a ready server's row and menu, through the run the interface already
keeps, and its tests.

**What must be true.** A rented server that is ready offers *Run its setup again* in its row's menu in Machines. It
runs `porelo-host up` for the project with the arguments its setup was made with, the setup's files uploaded again, in
the interface's own run: its protocol shows it as a new attempt, a stop it makes is completed from Needs you as at the
first setup, and the server stays ready in Machines while it runs.

## Why

Seen in two operator rounds: the guides say "run `up` again from the interface" on a ready server,
and the interface has no such action: *Try again* is unavailable with "preparation has ended" once the server is
ready, and nothing else runs `up`. The round ran it from a terminal with a script built from the interface's own
argument list, which the interface does not see, so a stop in it would have had nowhere to be completed.

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
