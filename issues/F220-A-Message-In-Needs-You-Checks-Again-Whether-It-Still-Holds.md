# F220 — A Message In Needs You Checks Again Whether It Still Holds

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** M - one recheck for Needs you's rows with a yes/no check each, "Not answering" its first user, the rows it
is worth for named, and their tests.

**What must be true.** A row in Needs you that says a condition ("Not answering") asks again on its own, at an
interval of its kind, whether that condition still holds; once it no longer does, the row leaves Needs you without
anybody pressing anything. One mechanism serves every such row: a row kind gives a check that answers yes or no, and
the mechanism asks it, stops while the window is not shown, and never asks two at once for one row.

## Why

Seen in the operator's round on a rented server (6e-H3): while the server rebooted, Needs you showed "sprint5 server
· Not answering · Try again now". The server answered again minutes later, and the row stayed until Try again was
pressed. The row comes from `Attention`'s silent machines (`lib/src/app/attention.dart`, `AttentionKind.silent`); the
machine's `FleetModel` retries by itself only after a contact it had was lost (`_tryAgainLater`), not after a
connection that never came up, so a machine whose tunnel went with the reboot is asked again only by Try again.

## Plan

- **One recheck:** a row kind may give `Future<bool> stillHolds()`; `Attention` asks it for each such open row at the
  kind's interval, while the window is shown, one question per row at a time, and drops the row when it answers no. A
  check that fails to answer keeps the row as it is.
- **First user, "Not answering":** its check is the machine's own reconnect (`FleetModel.connect`, through the
  machine's tunnel raised again where it went), every 30 s; the row leaves once the machine answers.
- **Further candidates**, each a yes/no check of its own, built where the operator wants them:
  - *VPN down* for a rented server: the same unprivileged link probe and ping `HostRuns.refreshVpns` runs.
  - *Homeserver unreachable* (a host's forward to this computer's homeserver): the forward answering again.
  - *Not following* a project on a machine: the machine following it again.
  - *Given back, VPN still up*: the local link gone (`probeVpnLink`).
- **Red first:** a "Not answering" row whose machine answers again leaves Needs you within one interval, with nothing
  pressed.

## Acceptance

- A rented server rebooted by hand: its "Not answering" row leaves Needs you on its own once it answers again.
- Try again now still asks at once.
- Seen to fail: the test red with the row still there after the machine answers.
