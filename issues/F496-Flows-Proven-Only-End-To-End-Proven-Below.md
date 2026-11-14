# F496 — Flows Proven Only End-To-End Proven Below

```json
{
  "$schema": "issue-1.json",
  "id": "F496",
  "title": "Flows Proven Only End-To-End Proven Below",
  "state": "Estimated",
  "size": "M",
  "priority": "Medium",
  "rank": 18,
  "blockedBy": [],
  "covers": "The flows proven only by the end-to-end or live runs proven below them: MockMachine handlers and wire tests, a test that every client method is known to the mock, the planning commands and the start dialog's machine change."
}
```

**Why this size.** M: handlers in `MockMachine`, wire tests in `test/client` and a handful of unit tests over fakes,
one XS to S each; one injected starter for the ssh forward. No contract changes.

**What must be true.** Every flow the window offers has a test below the end-to-end and live runs that fails when the
flow breaks; the end-to-end run keeps only what needs the real ssh, terminal and daemon.

## Why

The window's tests follow the test pyramid, as the shared rule *Testing and machines* asks. This is one of five
issues and independent of the others; the measured basis stands in [F499](README.md#f499).

## Decided by the operator (2026-11-12)

- The window's move to the test pyramid is five issues of their own; this one stands alone in order.
- The two points placed from the planning board's leftovers (2026-11-10), points 4 and 5, belong here.

## Measured: flows proven only end-to-end or live

- Client methods with no mock and no wire test: `destinations`, `writeDestination` (with `dryRun`),
  `removeDestination`, `authorizations`, `authorize`, `joinMessages`, `moderate`, `say`, `talk` (only in
  `reaching_a_machine.feature`); `held`, `readHeld`, `peers` (only live).
- `StartAgents` open, start all and reopen empty over `PoreloBackend` (only live).
- `EarlierWorkWaits` from `startTask`, and the gate's approval onto a taken branch (only live).
- Builds streamed by `Watch` into the task's builds (only live).
- The review's `against` left out for a push of several commits (only live).
- A hand-in in progress, files arriving and going by `Watch`, and hand-ins kept after removal (only live).
- The ssh forward's start, its stderr failure and its readiness poll (only end-to-end).
- `tailLog` with `formatted`, and the empty machine's first start through to *New work* (only end-to-end).
- **The planning commands in the finder** (open a story or an issue, move an issue, open its web page, save, undo) are
  registered with no test that fails when they are not.
- **The start dialog's machine choice** has a test that fails only as a type error when the old field returns, not on
  the behavior it guards: a rejected machine change leaving the old working state selected.

## Plan

- **Red first:** a test in `test/client` that every method `PoreloClient` calls is known to `MockMachine`, red for
  `destinations`.
- Handlers in `MockMachine` and wire tests in `test/client` for the client methods above (M).
- `test/app/start_agents_test.dart` over a fake (S); `EarlierWorkWaits` and the taken branch in
  `porelo_backend_test.dart` and `gate_test.dart` (XS); a `Watch` frame with builds in `porelo_client_test.dart` (XS);
  the review's `against` in `review_commits_test.dart` and `gate_test.dart` (XS).
- The hand-in modelled in `MockMachine` and tested in `hand_in_test.dart` (S).
- The ssh forward takes an injected starter, as `Tunnel` has, tested in `login_reply_test.dart` (S).
- `formatted` in `mock_machine_test.dart` (XS) and the empty machine's first start over the fake backend;
  `reaching_a_machine.feature` then keeps about five scenarios that need the real ssh, terminal and daemon (S).
- A finder test per planning command, which fails when the command is not registered.
- The start dialog: a rejected machine change leaves the old working state selected, tested on that behavior.
- Afterwards the shares are measured again as [F499](README.md#f499) says and written there.

## Acceptance

- Each flow above has a test below the end-to-end and live runs, each seen to fail with its flow broken: a client
  method unknown to `MockMachine`, a planning command not registered, a rejected machine change that selects the new
  state.
- `reaching_a_machine.feature` keeps only scenarios that need the real ssh, terminal and daemon.
