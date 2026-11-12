# F450 — The Window's Tests Follow The Test Pyramid

```json
{
  "$schema": "issue-1.json",
  "id": "F450",
  "title": "The Window's Tests Follow The Test Pyramid",
  "state": "Analyzed",
  "size": "XL",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "The window's tests moved to the test pyramid's shares: waits, network and processes faked, flows proven below the end-to-end runs, logic out of the widgets."
}
```

**Why this size.** XL: the measured work below sums to well over a week (shell.dart's controller alone is L), so it
is built as the five issues of L or smaller that *Plan* names, each green and pushed on its own.

**What must be true.** The window's tests follow the pyramid: about 70-80 % unit tests (one class or method, no outside
system, milliseconds), 15-20 % integration tests (components together, or against a real socket, a daemon or a
process), 5-10 % end-to-end runs (the window as its user meets it). A flow is plain logic behind small interfaces,
proven by unit tests over fakes; a widget test shows only what the widget adds; the end-to-end run on a leased machine
proves only what nothing lower can show.

## Why

The shared rule *Testing and machines* asks it of every repository. Measured, the window's suites stand the pyramid on
its head: almost all time goes to tests that boot the whole window.

## As it stands (measured)

The last whole local `flutter test` (on the planning board's commit, 2026-11-09) ran 519 s wall, 3458 s summed over
3482 tests:

| Level | Where | Files | Tests | Summed time |
|---|---|---:|---:|---:|
| Unit | `test/app` | 107 | 1180 | 142 s |
| Integration: whole window over the fake backend | `test/features` (Gherkin) | 46 | 836 | 1992 s |
| Integration: widgets, many booting the whole window | `test/ui` | 95 | 1044 | 1254 s |
| Integration: client against `MockDaemon` over a unix socket | `test/client` | 31 | 293 | 28 s |
| Integration: tools, packaging, documents | other `test/` | 16 | 107 | 42 s |
| Live: real daemon and vault (skipped locally) | `test/client/live_*` | 5 | 24 | — |
| End-to-end: leased machine over ssh, headless | `integration_test/` | 2 | 22 | up to 40 min in CI |

By count: unit 34 %, integration 65 %, end-to-end 0.6 %. By time: unit 4 %, integration 96 %. The shared
bottleneck is `World.startApp`, which boots the whole window per scenario, and `World.settle`, which pumps three
full-tree frames (0 + 350 + 350 ms) per action.

## Flows proven only end-to-end or live

- Client methods with no mock and no wire test: `destinations`, `writeDestination` (with `dryRun`),
  `removeDestination`, `authorizations`, `authorize`, `joinMessages`, `moderate`, `say`, `talk` (only in
  `reaching_a_machine.feature`); `held`, `readHeld`, `peers` (only live). Fix: handlers in `MockMachine`, wire tests in
  `test/client`, and a test that every method the client calls is known to the mock. **M**
- `StartAgents` open, start all and reopen empty over `PoreloBackend` (only live). Fix:
  `test/app/start_agents_test.dart` over a fake. **S**
- `EarlierWorkWaits` from `startTask`, and the gate's approval onto a taken branch (only live). Fix: both in
  `porelo_backend_test.dart` and `gate_test.dart`. **XS**
- Builds streamed by `Watch` into the task's builds (only live). Fix: a `Watch` frame with builds in
  `porelo_client_test.dart`. **XS**
- The review's `against` left out for a push of several commits (only live). Fix: in `review_commits_test.dart` and
  `gate_test.dart`. **XS**
- A hand-in in progress, files arriving and going by `Watch`, and hand-ins kept after removal (only live). Fix: modelled
  in `MockMachine`, tested in `hand_in_test.dart`. **S**
- The ssh forward's start, its stderr failure and its readiness poll (only end-to-end). Fix: an injected starter, as
  `Tunnel` has, tested in `login_reply_test.dart`. **S**
- `tailLog` with `formatted`, and the empty machine's first start through to *New work* (only end-to-end). Fix: the
  parameter in `mock_machine_test.dart` (XS) and the flow over the fake backend; `reaching_a_machine.feature` then keeps
  about five scenarios that need the real ssh, terminal and daemon. **S**

## Tests that wait, use the network or start processes where a fake would do

- Real waits in unit tests: `organization_connections_test.dart` (3.3 s; and 2 x 200 ms on loopback sockets though a
  `connect:` can be given), `forge_test.dart` (1 s on a loopback socket beside its fake HTTP client),
  `terminal_close_test.dart` (300-1200 ms), `machines_raise_hold_test.dart` and `operations_record_test.dart` (80-150 ms
  polls though a clock can be given). Fix: an injected clock and `fakeAsync`. **S** (five XS)
- Real waits over sockets in `test/client`: `porelo_client_test.dart` (1.1 s), `agent_sign_in_test.dart` (600 ms),
  `varlink_connection_test.dart` (20-200 ms). Fix: an in-memory connection under `fakeAsync`; one socket test stays.
  **S**
- Widgets mixing a fake clock with `DateTime.now()` (`placing_project_dialog.dart`'s six-minute patience), widgets
  reading files directly (`organization_page_test.dart`, the file hand-in step), and timers that always run
  (`work_page.dart` 30 s, `attention_view.dart` 15/30 s, `running_view.dart` 15 s). Fix: an injected clock and reader,
  timers started only while shown. **S**
- `published_key_test.dart` fetches from the internet and runs `gpg`. Fix: the live check moves to the release
  workflow; the unit test keeps a fixture. **XS**
- Processes started in tests: `world.dart`'s fake machine setup runs `chmod` and `ssh-keygen`; `tunnel_test.dart`,
  `machine_setup_test.dart`, `host_card_tunnel_test.dart`, `pinned_ssh_test.dart` start `sh`, `python3` or a Dart VM
  where their `start:` accepts a fake; `porelo_host_test.dart`, `down_cli_test.dart`, `secret_store_test.dart`,
  `test_report_test.dart` start a Dart VM per assertion; `run_here_test.dart` waits 3 x 600 ms. Fix: fakes, the runners
  called in-process, one process smoke test each. **M**

## Slow widget suites whose logic belongs in unit tests

- `task_creation` (142 s, 78 scenarios): name rules, defaults and retries on `StartWork` in `test/app`, about eight
  dialog tests left. **M**
- `machine_sections` (124 s, 52): which machine a leaf's command acts on, resolved in `ShellModel` and
  `commands.dart`. **M**
- `adding_a_machine` (103 s, 45) and `managed_tunnels` (54 s, 21): a plain wizard model with its transitions. **M**
- `agent_sign_in` (93 s, 32): the state matrix on `AgentSignIn` and `StartWork`, three widget tests left. **S**
- `live_logs` (93 s, 12; one scenario pumps 400 frames): coalescing, caps and truncation in `test/app/logs_test.dart`
  under `fakeAsync`. **S**
- `organization_page` (89 s, 98) and `organization_host_pages` (55 s, 86): role and standing rules, write payloads and
  central state as plain projections. **M**
- `work_handover`, `network_exposure`, `work_tiles`, `task_control`, `work_page_faults`: their orchestration on `Gate`,
  `Widening`, `Attention` and `Commands`; views mounted alone. **M**

## Logic that lives in widgets

`shell.dart` (6437 lines) is the window's controller: task start, sign-in recovery, gate forwarding and more live in
`_ShellState` (**L**, in M slices). Then `host_dialog.dart` (a fifteen-flag state machine with debounce timers),
the organization pages and dialogs, `identity_view.dart`, `machine_switcher.dart` with `new_machine.dart`, and the
model-less dialogs `connection_wizard.dart`, `destinations_view.dart`, `held_message_view.dart`, `default_view.dart`,
`forges_page.dart` and the work facts in `attention_view.dart` (**M** each, some **S**).

## Plan

Read in today's code (`test/features/support/world.dart`'s `World.startApp` and `World.settle`, `lib/src/ui/shell.dart`
at 7 k lines, 124 files in `test/app`). Split into five issues, built in this order; each sees its new unit tests red
first, and removes the widget scenarios and the waits they replace in the same commit:

1. **Waits, network and processes faked** (M): an injected clock (a `clock:` function, as `Organization` takes) and
   `fakeAsync` for the real waits listed above; an in-memory varlink connection under `fakeAsync` in `test/client`, one
   socket test kept; the `start:` parameters the classes under `tunnel_test.dart`, `machine_setup_test.dart`,
   `host_card_tunnel_test.dart` and `pinned_ssh_test.dart` take given fakes, one process smoke test each;
   `published_key_test.dart`'s live fetch moved to the release workflow. First red test:
   `organization_connections_test.dart` under `fakeAsync`, which fails while a real wait remains in it.
2. **The flows proven only end-to-end or live, proven below** (M): the `MockMachine` handlers and wire tests listed
   above, and a test in `test/client` that every method `PoreloClient` calls is known to `MockMachine`, red first for
   `destinations`. Also the two placed from F451: a finder test per planning command, and the start dialog's rejected
   machine change.
3. **The Gherkin suites' rules as unit tests** (L): the slow suites listed above, slice by slice, their rules on
   `StartWork`, `ShellModel` and `commands.dart`, a wizard model for adding a machine and tunnels, `AgentSignIn`, `Logs`
   and the organization projections; each feature keeps the scenarios that show what the window adds. `World.settle`
   pumps only the frames a scenario needs.
4. **The shell's controller out of `_ShellState`** (L): task start, sign-in recovery and gate forwarding into plain
   classes in `lib/src/app` behind the interfaces the shell already holds (`Machines`, `Gate`, `StartWork`), in M
   slices, each with its unit tests and the shell's widget tests that become redundant removed.
5. **The model-less dialogs** (L): `host_dialog.dart`'s state machine, the organization pages and dialogs,
   `identity_view.dart`, `machine_switcher.dart` with `new_machine.dart`, `connection_wizard.dart`,
   `destinations_view.dart`, `held_message_view.dart`, `default_view.dart`, `forges_page.dart` and
   `attention_view.dart`'s work facts, each given a model with unit tests.

After each, the table above is measured again the same way (`flutter test --reporter json`, summed per folder) and the
shares written into this issue.

## Acceptance

- The measured shares, by count and by time, reach the pyramid's bands, measured the same way as above.
- No unit test waits on real time, the network or a process.
- Every flow above has a test below the end-to-end and live runs that fails when the flow breaks.

## Open questions

- Split F450 into the five issues of *Plan*, each with its own number, size and place in the backlog (the
  operator's to order), with F450 closed once they are filed; or kept as one issue built in five pushes?
- The Gherkin features are read as the window's specification (`test/features/*.feature`, 51 files). Moving a
  feature's rules into unit tests removes most of its scenarios. May a feature keep only the scenarios that show
  what the window adds, its rules then specified by the unit tests' names, or must every scenario stay?

## Placed here from F451

Placed by the operator (2026-11-10) from [F451](README.md#f451), points 4 and 5:
- **The planning commands in the finder** (open a story or an issue, move an issue, open its web page, save, undo) are
  registered with no test that fails when they are not.
- **The start dialog's machine choice** has a test that fails only as a type error when the old field returns, not on
  the behavior it guards: a rejected machine change leaving the old working state selected.

## To be checked

- The end-to-end run's measured time per scenario on the leased machine, for the table.
