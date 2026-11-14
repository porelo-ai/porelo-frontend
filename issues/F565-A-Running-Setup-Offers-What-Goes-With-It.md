# F565 — A Running Setup Offers What Goes With It

```json
{
  "$schema": "issue-1.json",
  "id": "F565",
  "title": "A Running Setup Offers What Goes With It",
  "state": "Review",
  "size": "M",
  "priority": "Highest",
  "rank": 9,
  "blockedBy": [],
  "covers": "Story ST361: while a machine's setup runs, its wizard step and its row offer only what makes sense then: no Back, a Leave without a warning for work that goes on by design, a protocol that says it waits for its first line, and a row menu with the protocol alone."
}
```

**Why this size.** Four places on one path, each with a guard: the wizard's navigation while a step's action runs,
its leave dialog, the following output's empty state, and the machine row's menu during a preparation.

**What must be true.** A person setting up a machine is never offered a step that has no meaning or races the setup,
and never warned about the way the setup is meant to go on.

## Plan

Found in the operator's live setup of a machine, at "Set up a machine", step 8 of 9 (Prepare), while the
preparation ran:

- **Back while the action runs.** "Back" stands beside "Leave" while the step's action runs, though going back has no
  meaning there: the action goes on, and the earlier steps are done. The fix: no Back while a step's action runs.
- **Leave asks about work that goes on by design.** `lib/src/ui/wizard.dart` ~267–270 asks "Leave this wizard? The
  action is unfinished and may keep running…" for a preparation that goes on by design and whose row opens its
  protocol again. Such a step leaves without asking; its line already says that the work goes on and where to find it.
  Steps whose work ends with the wizard keep the question.
- **A protocol that comes late.** The area under *Following* (`lib/src/ui/following_output.dart`) stayed black and
  empty for over a minute after the preparation started, while the state said running. Its lines did arrive later.
  The fix: find where the lines wait (the protocol's read interval, a buffer that flushes only in blocks, or
  porelo-host writing late), measure the delay and remove it where it is the window's. Until the first line comes,
  the area says *Waiting for the first line*.
- **The row menu during a preparation.** A machine row *In preparation* offers *Open its forge* (unavailable),
  *Take Porelo off this machine…*, *Enter address and key…* and *Remove the machine…*; the two removals race the
  setup. While a preparation runs, the row's menu offers the protocol alone, as its button does. Everything else
  comes back when the preparation has ended or failed. porelo-host has no clean stop of a running `up` today, so a
  stop entry waits on Agent Machines, filed there with what a half-set-up server is left as.

## Acceptance

- A guard per point, each red first; the wizard, machine row and following-output tests green; the whole
  test/features before hand-over, as the wizard and the row are on many paths.

## Built

- **Where the protocol waited.** Not in the window's buffering: `HostSession` reads porelo-host's standard output line
  by line and notifies at once, and the wizard and the row's dialog rebuild on that. The wait was the window's own,
  before porelo-host started at all: the wizard (and *Add a machine*) read the organization to write the machine
  file, and `HostRuns` then read it twice more (`check`, then `machineFile`, which checks again) before `up`. Measured
  in `host_runs_test.dart` with a counting stand-in: two reads between the start and `up`'s process, beside the
  caller's one. Each read is a `porelo org` and, when its answer is stale, a `porelo org --refresh` that may take up
  to 60 seconds, so the empty pane of over a minute fits two such reads; the time itself was not measured on a real
  forge. A start whose caller has just read the organization (`HostRuns.start(organizationReadJustNow: true)`, both
  callers) now starts `up` without reading it again, the admin still required on that read; a setup taken up again
  reads it once, by writing the machine file, instead of twice.
- Until this start's first line comes, the protocol says *Waiting for the first line* (`FollowingOutput`'s
  `waitingForFirstLine`, from `HostPreparation.waitsForFirstLine`), in the wizard and in the row's protocol.
- **No Back while a step's action runs**: the wizard hides Back while the shown action step runs; it comes back once
  the action waits or has answered.
- **Leave without a warning** while an action step's `goesOnWhenLeft` answers true at the moment of leaving: Prepare
  answers so only while its run in `HostRuns` runs, and its line says it goes on and that its row opens the protocol
  again. Before the run started, once it was refused or ended, and for other actions, among them the token step,
  Leave keeps the question.
- `ServerSetup` stops quietly once put away, as the window does when the wizard returns: a preparation left before it
  started starts nothing (no machine file handed on, no old key taken out, no run), and one left while it runs goes on
  in `HostRuns` and ends without notifying the setup.
- From the press on, before the run exists (the organization read and the key fetched again), the protocol pane
  already says *Waiting for the first line*.
- **The organization row's menu** offers *Open the machine protocol* alone while its preparation runs; everything else
  comes back once it has ended or failed. The *Machines* page's preparation row was left as it was: its *Try again*
  and *Take Porelo off this machine…* stand grey there with the reason that the setup command still runs.
- **To be filed with Agent Machines:** porelo-host has no clean stop of a running `up`, so no stop entry is offered;
  a stop needs one there, with what a half-set-up server is left as.
- Seen while reading: between `ssh` done and `copy` started, porelo-host runs the carried collection's check with no
  step line of its own, so the last line stands still for as long as that check runs.

