# F499 — The Model-Less Dialogs Given Models

```json
{
  "$schema": "issue-1.json",
  "id": "F499",
  "title": "The Model-Less Dialogs Given Models",
  "state": "Estimated",
  "size": "L",
  "priority": "Medium",
  "rank": 21,
  "blockedBy": ["F498"],
  "covers": "The host dialog's state machine, the organization pages and dialogs and the other model-less views each given a model with unit tests; the window's tests then measured at the test pyramid's shares."
}
```

**Why this size.** L: about ten views, each an M or an S of its own, `host_dialog.dart`'s fifteen-flag state machine
with debounce timers the largest; the last measurement of the pyramid's shares closes it.

**What must be true.** A dialog's logic is a model proven by unit tests; the dialog's widget tests show only what the
widget adds. With this, the last of five issues, the window's tests follow the pyramid: about 70-80 % unit tests (one
class or method, no outside system, milliseconds), 15-20 % integration tests (components together, or against a real
socket, a daemon or a process), 5-10 % end-to-end runs (the window as its user meets it).

## Why

The window's tests follow the test pyramid, as the shared rule *Testing and machines* asks. Measured, the window's
suites stand the pyramid on its head: almost all time goes to tests that boot the whole window. The measurement below
is the basis of all five issues ([F495](README.md#f495), [F496](README.md#f496), [F497](README.md#f497),
[F498](README.md#f498) and this one, split from [F450](README.md#f450) by the operator); each writes its new shares
here.

## Decided by the operator (2026-11-12)

- The window's move to the test pyramid is five issues of their own; this one is built after
  [F498](README.md#f498), and its acceptance is the whole move's.

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

By count: unit 34 %, integration 65 %, end-to-end 0.6 %. By time: unit 4 %, integration 96 %. It is measured again
the same way (`flutter test --reporter json`, summed per folder) after each of the five issues, and the shares are
written here.

## Measured: logic that lives in widgets

`host_dialog.dart` (a fifteen-flag state machine with debounce timers), the organization pages and dialogs,
`identity_view.dart`, `machine_switcher.dart` with `new_machine.dart`, and the model-less dialogs
`connection_wizard.dart`, `destinations_view.dart`, `held_message_view.dart`, `default_view.dart`, `forges_page.dart`
and the work facts in `attention_view.dart` (**M** each, some **S**).

## Plan

- Each view above is given a model in `lib/src/app` with unit tests, one view per slice; the widget tests the model
  makes redundant are removed in the same commit.
- **Red first:** `host_dialog.dart`'s state machine as a model's unit tests under `fakeAsync`, its debounce included,
  before the model exists.
- Then the organization pages and dialogs, `identity_view.dart`, `machine_switcher.dart` with `new_machine.dart`,
  `connection_wizard.dart`, `destinations_view.dart`, `held_message_view.dart`, `default_view.dart`, `forges_page.dart`
  and `attention_view.dart`'s work facts.
- Last, the shares are measured as above and written here.

## Acceptance

- Each view above has a model whose unit tests fail with its logic broken; its widget tests show only what it adds.
- The measured shares, by count and by time, reach the pyramid's bands, measured the same way as above.
- No unit test waits on real time, the network or a process.
- Every flow proven only end-to-end or live has a test below them that fails when the flow breaks.

## To be checked

- The end-to-end run's measured time per scenario on the leased machine, for the table.
