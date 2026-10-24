# F169 — A Server In Preparation Kept Across A Restart

**Status:** Backlog.
**Size:** M - a persisted preparation record, its restore into *Machines*, two commands, and the close guard.

**What must be true.** A rented server still being prepared stands under *Machines* as *In
preparation* after the interface was closed and started again, with *Go on* and *Take it down*; and
closing the interface while a preparation runs warns that the server keeps billing and says where to
go on.

## Plan

- **Today**, read in the code: `HostRuns` keeps runs in memory only (`host_runs.dart`), so after a
  restart *Machines* shows neither run nor host; the wizard's answers survive in `Settings.hostUp`
  (written before `up` starts, `host_dialog.dart`). The close guard (`shell.dart` `_letGo`,
  `leaving.dart`) asks about running tasks and clearance questions, not host runs. `up` finds a
  rented server again by its tag (`host_run.dart` `provider.find(plan.tag)`).
- **The record:** `HostUpRecord` gains `preparing: true` with the instant it started, written before
  `up` starts and cleared when the host became a machine or a `down` confirmed the give-back; a
  failed `down` keeps it. Read field by field as today.
- **Restore:** at start, every kept record with `preparing` becomes a `HostPreparation` in
  `HostRuns` in an *interrupted* state (no process, nothing rented, nothing run by itself). Its row
  under *Machines* says *Interrupted when the interface closed; the server is still rented* and
  offers *Go on* (runs `up` with exactly the kept arguments) and *Take it down* (the confirmation
  of [F176](README.md#f176)).
- **The close guard:** while any run is not ready, leaving lists it: *<project> server is being
  prepared; the server stays rented and billed. Go on later from Machines*. Cancel keeps the
  interface and the run.
- **Tests, their harm, red first:** a preparation stopped, `Settings` and `HostRuns` made anew from
  the same store, shows as interrupted and *Go on* runs `up` with the kept project, account and
  provider project (an invisible billing server; a command for another server); a confirmed down
  clears it, a refused one keeps it. Words get no test.

## Acceptance

- In the guided walk: start a preparation, close the interface at the warning's *Leave*, start it
  again: the row stands under *Machines* and *Go on* reaches the stop again.
