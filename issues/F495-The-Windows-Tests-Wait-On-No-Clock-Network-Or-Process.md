# F495 — The Window's Tests Wait On No Clock, Network Or Process

```json
{
  "$schema": "issue-1.json",
  "id": "F495",
  "title": "The Window's Tests Wait On No Clock, Network Or Process",
  "state": "Estimated",
  "size": "M",
  "priority": "Medium",
  "rank": 17,
  "blockedBy": [],
  "covers": "The window's unit tests wait on no real time, network or process: an injected clock under fakeAsync, an in-memory varlink connection, fake process starts, one smoke test each."
}
```

**Why this size.** M: about ten test files and the classes under them take a clock or a start they mostly take
already; one in-memory connection in `test/client`; one release workflow step. No contract changes.

**What must be true.** A unit test of the window runs in milliseconds: it waits on no real time, reaches no network
and starts no process. What needs a real socket or process is shown once, in a smoke test of its own.

## Why

The window's tests follow the test pyramid, as the shared rule *Testing and machines* asks. This is the first of five
issues; the measured basis, the shares by count and by time, stands in [F499](README.md#f499).

## Decided by the operator (2026-11-12)

- The window's move to the test pyramid is five issues of their own, of which this is the first in order.

## Measured: what waits, uses the network or starts a process

- Real waits in unit tests: `organization_connections_test.dart` (3.3 s; and 2 x 200 ms on loopback sockets though a
  `connect:` can be given), `forge_test.dart` (1 s on a loopback socket beside its fake HTTP client),
  `terminal_close_test.dart` (300-1200 ms), `machines_raise_hold_test.dart` and `operations_record_test.dart` (80-150 ms
  polls though a clock can be given).
- Real waits over sockets in `test/client`: `porelo_client_test.dart` (1.1 s), `agent_sign_in_test.dart` (600 ms),
  `varlink_connection_test.dart` (20-200 ms).
- Widgets mixing a fake clock with `DateTime.now()` (`placing_project_dialog.dart`'s six-minute patience), widgets
  reading files directly (`organization_page_test.dart`, the file hand-in step), and timers that always run
  (`work_page.dart` 30 s, `attention_view.dart` 15/30 s, `running_view.dart` 15 s).
- `published_key_test.dart` fetches from the internet and runs `gpg`.
- Processes started in tests: `world.dart`'s fake machine setup runs `chmod` and `ssh-keygen`; `tunnel_test.dart`,
  `machine_setup_test.dart`, `host_card_tunnel_test.dart`, `pinned_ssh_test.dart` start `sh`, `python3` or a Dart VM
  where their `start:` accepts a fake; `porelo_host_test.dart`, `down_cli_test.dart`, `secret_store_test.dart`,
  `test_report_test.dart` start a Dart VM per assertion; `run_here_test.dart` waits 3 x 600 ms.

## Plan

- **Red first:** `test/app/organization_connections_test.dart` run under `fakeAsync`, which fails while a real wait
  remains in it.
- The real waits above take an injected clock (a `clock:` function, as `Organization` takes) and run under
  `fakeAsync`; the loopback sockets give way to the `connect:` the class already takes.
- In `test/client`, an in-memory varlink connection under `fakeAsync`; one socket test is kept.
- The widgets above take an injected clock and file reader; their timers start only while they are shown.
- The classes under `tunnel_test.dart`, `machine_setup_test.dart`, `host_card_tunnel_test.dart` and
  `pinned_ssh_test.dart` are given fakes through their `start:`; the runners started as a Dart VM are called
  in-process; one process smoke test is kept for each.
- `published_key_test.dart`'s live fetch and `gpg` move to the release workflow; the unit test keeps a fixture.
- Each change removes the wait it replaces in the same commit. Afterwards the shares are measured again as
  [F499](README.md#f499) says and written there.

## Acceptance

- No test in `test/app` or `test/client` waits on real time, the network or a process, smoke tests aside; one put back
  is seen to fail `organization_connections_test.dart`'s run under `fakeAsync`.
- `published_key_test.dart` passes offline; the release workflow still checks the published key live.
