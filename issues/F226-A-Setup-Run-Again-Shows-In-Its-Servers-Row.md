# F226 — A Setup Run Again Shows In Its Server's Row

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** S - the ready server's row shows a setup run again as the first setup's row does, the commands that must
not run meanwhile unavailable with the reason, and their tests; about 1.5 hours.

**What must be true.** While *Run its setup again* ([F223](README.md#f223)) runs or waits on a ready server, its row in
Machines says so as the first setup's row does: the state *Setting up again* (or *Needs you* at a stop), the current
step and the time left from its protocol, and *Open the host protocol* as the row's primary action. Meanwhile
*Take this server down*, *Forget this machine*, *Put this project on a server…* and *Run its setup again* are
unavailable, each saying "its setup is running again; see its protocol". The server stays in Machines and stays
reachable as before; once the run ends, the row is the ready server's again, with how the run ended in its protocol.

## Why

Seen in the operator's round (6i, step 5): after *Run its setup again* nothing visible changed; the row said
*Connected* while `porelo-host up` ran for about five minutes, and only the stop's dialog showed it. The operator: one
cannot tell that something runs, the display should be like the setup's with its log, otherwise someone could start
something else in the middle of the setup.

## Plan

- `machines_page.dart`: a ready server whose `HostPreparation` is `running`, `needsYou` or `interrupted` gets the
  state, the step lines and the protocol action of the preparation row (the same widgets, factored out), above its
  machine details.
- `commands.dart`: `machine.takeDown`, `machine.forget` and `project.server` take the run's reason where
  `HostRuns.of(project)` runs or waits; `host.again` already does.
- **Red first:** on a ready server, *Run its setup again* makes its row say *Setting up again* with the protocol's
  current step and makes *Take this server down* unavailable with the reason; at the stop it says *Needs you*; when
  `up` ends 0 the row is *Connected* again and the commands are back.

## Acceptance

- During a setup run again, the server's row shows that it runs, its step and the way to its protocol.
- Taking the server down, forgetting it, putting the project on a server and running the setup again are unavailable
  meanwhile, each saying why.
