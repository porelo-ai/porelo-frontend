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
  "covers": "New work on a repository of default with no checkout on the machine starts again: the window stops sending FirstStart a repository the machine's Porelo does not take, and a live test holds the call against the real interface"
}
```

**Why this size.** S: one client call and its fallback in `lib/src/client/porelo_client.dart` and
`lib/src/app/start_work.dart`, their tests, and one case of the live daemon test; whether the call stays depends on
the machine's Porelo only.

**What must be true.** *Work > New work* in `default`, on a repository with no checkout on the machine, starts the task
as the machine would without a first-start question, wherever the machine's Porelo cannot propose one for a repository
named by its name; and where it can, the question is put as today. Today every such start fails: the form closes and
nothing starts.

## What was found

- In use: Porelo 0.5.1 snapshot 555, the window from main; *New work* in `default`, repository `utils4j` with no checkout
  on the machine, Claude Code, *Start it*. Nothing started; the status line said the machine "could not say what a first
  task on utils4j is to do, so nothing started: a checkout is named b…".
- The window's `firstStartOf` sends `FirstStart` with `repository` (`porelo_client.dart:1291`), and
  `confirmFirstStartOf` `ConfirmFirstStart` the same. The machine's interface is `FirstStart(checkout: string, proxy:
  ?[string]string)`: with no `checkout` it refuses `FirstStartRefused` with reason `NOT_A_CHECKOUT` ("a checkout is
  named by its absolute path"). `askBeforeTheFirstTask` (`start_work.dart:1347`) starts as before only on
  `FeatureNotSupported` or `org.varlink.service.InvalidParameter`, so this refusal ends the start.
- The window was built against a `FirstStart` by repository that Porelo had announced; it was never built, and the
  window's guess at how a Porelo without it refuses was never measured.

## Why no test caught it

- `test/client/porelo_client_test.dart` holds `firstStartOf` against `MockDaemon`, whose `FirstStart` was written to
  take `repository` as the window sends it: the stand-in followed the window's assumption, not the machine's interface.
- `test/client/live_daemon_test.dart`, the one level against a real `porelod`, has no `FirstStart` case, and no walk or
  story starts new work in `default` on a repository without a checkout.

## Plan

- Settled with Porelo's owner which side changes (to be checked). Until a Porelo takes a repository here, a
  `FirstStartRefused` with reason `NOT_A_CHECKOUT` to a call that named no checkout is read as "this machine cannot
  propose here", exactly as `InvalidParameter` is, and the task starts as it would without a question.
- `test/app/start_work_test.dart` (or where `askBeforeTheFirstTask` is held): a machine answering that refusal starts,
  and one answering any other `FirstStartRefused` still stops with its reason; seen red first.
- `test/client/live_daemon_test.dart`: `firstStartOf` against the real `porelod`, answering either a proposal or the
  refusal the fallback reads, so a drift between the two shows on the next live run.
- `doc/Contract-Gaps.md`: the entry says what the machine serves today.

## Acceptance

- The case above, with a repository without a checkout, starts its task; the unit tests were seen red first.

## To be checked

- Whether Porelo builds `FirstStart` by repository (the window then keeps the call) or drops it (the window then never
  asks it for a repository without a checkout).
