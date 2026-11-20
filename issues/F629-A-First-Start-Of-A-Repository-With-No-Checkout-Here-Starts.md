# F629 — A First Start Of A Repository With No Checkout Here Starts

```json
{
  "$schema": "issue-1.json",
  "id": "F629",
  "title": "A First Start Of A Repository With No Checkout Here Starts",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "New work on a repository of default with no checkout on the machine starts again: the window asks FirstStart only for a repository with a checkout here, and a live test holds the call against the real interface"
}
```

**Why this size.** S: two client calls removed and one decision in `lib/src/app/start_work.dart`, their tests, and one
case of the live daemon test; no contract changes.

**What must be true.** *Work > New work* in `default`, on a repository with no checkout on the machine, starts the task
with no first-start question, its own settings asked through the start's allowance as for any start; a repository with a
checkout here still gets the question. Today every start without a checkout fails: the form closes and nothing starts.

## What was found

- In use: Porelo 0.5.1 snapshot 555, the window from main; *New work* in `default`, repository `utils4j` with no checkout
  on the machine, Claude Code, *Start it*. Nothing started; the status line said the machine "could not say what a first
  task on utils4j is to do, so nothing started: a checkout is named b…".
- The window's `firstStartOf` sends `FirstStart` with `repository` (`porelo_client.dart:1291`), and
  `confirmFirstStartOf` `ConfirmFirstStart` the same. The machine's interface is `FirstStart(checkout: string, proxy:
  ?[string]string)`: with no `checkout` it refuses `FirstStartRefused` with reason `NOT_A_CHECKOUT` ("a checkout is
  named by its absolute path"). `askBeforeTheFirstTask` (`start_work.dart:1347`) starts as before only on
  `FeatureNotSupported` or `org.varlink.service.InvalidParameter`, so this refusal ends the start.
- The window was built against a `FirstStart` by repository that Porelo never built: it stood only in the window's
  own plan, and the window's guess at how a Porelo without it refuses was never measured.

## Why no test caught it

- `test/client/porelo_client_test.dart` holds `firstStartOf` against `MockDaemon`, whose `FirstStart` was written to
  take `repository` as the window sends it: the stand-in followed the window's assumption, not the machine's interface.
- `test/client/live_daemon_test.dart`, the one level against a real `porelod`, has no `FirstStart` case, and no walk or
  story starts new work in `default` on a repository without a checkout.

## Plan

- Porelo builds no `FirstStart` by repository: it reads a checkout on this computer, and a yes writes `porelo.yml` into
  it. A repository added by address (`DefaultRepository.checkout` empty, source `REMOTE`) has no first start; its own
  settings go through `CanStart` (`SETTINGS_NOT_ALLOWED` with `settingsToAllow`, `settingsHash`), `AllowSettings` and
  then `Start`, which the window has already.
- `lib/src/app/start_work.dart`, `askBeforeTheFirstTask`: asked only for a repository with a checkout here, and then
  with `firstStart(checkout)` and `confirmFirstStart(checkout, hash)`; for one without, it asks nothing and the start
  goes on. `firstStartOf` and `confirmFirstStartOf` leave `PoreloClient`, `FleetBackend`, `MockDaemon` and the
  stand-ins.
- `test/app/start_work_test.dart`: a repository without a checkout starts with no `FirstStart` sent; one with a checkout
  sends its path; seen red first. `test/client/live_daemon_test.dart`: `FirstStart` with a checkout against the real
  `porelod`, so the next live run shows a drift.
- `doc/Contract-Gaps.md`: the entry no longer says `FirstStart` takes a repository by its name.

## Acceptance

- The case above, with a repository without a checkout, starts its task; the unit tests were seen red first.

