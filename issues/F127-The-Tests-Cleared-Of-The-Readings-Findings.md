# F127 — The Tests Cleared Of The Reading's Findings

**Status:** Implementing; Review once it is pushed and published as a snapshot.
**Size:** L - six groups of findings across `test` and `integration_test`: the integration leg's
cleanup moved into tear-downs and made to fail when it fails, the tests that cannot fail repaired
where they guard a harm and deleted where they do not, and the host kept out of the suite.

**What must be true.** What [F119](README.md#f119)'s reading found in the tests is fixed: a red run
leaves nothing behind on the test machine, every test that guards a harm can fail, a test that guards
none is gone, and no test reaches the host's own configuration, daemon or clock.

## Plan

- **Findings 25-30 of [F119](README.md#f119)**, one commit per group:
  - **the integration leg (25):** every scenario's cleanup registered as a tear-down when what it
    removes is made, each cleanup step failing when the removal fails, and what `matrixInTheAccount`
    and the stub agent install removed after the run - what a run made left in an account;
  - **the `lib` static a step leaves at zero (26)**, restored in a tear-down;
  - **`pumpAndSettle` out of the steps and `World` (27)** - a hang in place of a named failure - and
    `settle`'s doc back on it;
  - **the tests that pass with what they test removed (28)**, each named by the harm it guards and
    repaired, or deleted where it guards none:
    - repaired: the rpm half of the index wait in `workflow_publish_test` (a release published
      before it is served), the IDL declaration check and `held()` in `live_daemon_test` (the contract
      read wrong), Check it now in `live_refresh_test` (a refused repository reported as checked);
    - deleted, as each holds only text or a colour: the second half of `it_says_keeps_running`,
      `the_repositories_are_listed_a_card_each`, `probe_look_test`'s colour, the probe step, and the
      two `textContaining` over the whole screen, unless one turns out to guard a harm, said in its
      commit;
  - **the host kept out (29):** git without the host's configuration, the tunnel tests without the
    host's profile - a real daemon started - and three steps without the wall clock;
  - **clean-up after a red expect, and tests that need each other's order (30).**
- **`doc/decisions.md`** names what `dart-build-cli-app` asks that the suite does otherwise: stand-in
  scripts in temporary folders rather than `package:test_process`, and a dependency-free
  `tool/contract.dart`.
- **Red first:** for each repaired test, the behaviour removed and the test seen still green before
  its repair, red after; for 25, a scenario failed midway and the test machine's account seen to keep
  what it made.

## Acceptance

- **Each repaired test is green without what it tests before its repair, and red after**; each
  deleted one is named in its commit with why it guarded no harm.
- **A scenario failed midway leaves nothing in the test machine's account**, measured on the VM.
- **The whole workflow is green on the VM** on the commit handed over.

## Outcome

| Finding | Outcome |
|---|---|
| 25, the integration leg | Each step that makes something on the test machine, or has the interface make it (a vault entry, a destination), registers its removal as a tear-down that runs after a red step too and fails naming what is left; the scenarios' own clean-up steps no longer hide a failed removal behind `\|\| true`, and check what is left. The leg reads a script's output and errors at once. `matrixInTheAccount` and the stub agent stay installed in the account on purpose, as their comments say, for the runs after. |
| 26, a static left at zero | Restored in a tear-down. |
| 27, `pumpAndSettle` | `World.settle` in the World and the six steps; `settle`'s doc back on it. |
| 28, tests that could not fail | Repaired, each seen red with what it guards taken out: the rpm half of the index wait; the live contract checks, through one reading that ends a declaration where it closes and finds a field by its whole name (`idl_test`); Check it now's live test, a line per repository and none refused; quitting's warning held to its sentence that work goes on; the emergency stop to its row of what was stopped; the machine's readiness to its verdict. Deleted, as each held only layout or a colour: the scenario counting a card per repository, its step, and `probe_look`'s test of an unknown state's colour. `held()`'s live test is kept: it fails where the daemon no longer answers the call. |
| 29, the host | The workspace tests run git with no host configuration, `features_named_test` too and checks git's exit; the far-end start tests' login shell gets a `.profile` of the test's own after `/etc/profile`. The three steps on the wall clock are kept: a step and the frame it is read in are milliseconds apart, against slacks of thirty seconds and more. |
| 30, clean-up and order | Tear-downs for the forwards, a session, the relay and the clipboard handler; a live take-back hands in its own file; a live start that should have been refused removes the task it made; `ssh-keygen` and `ssh-add` held to their exit; `walks_test` fails when it finds no walk. The fixed 300 ms in `openTheDestinations` is kept: it is what lets a growing menu settle on the VM, and nothing has shown it short. |

`doc/decisions.md` names what the suite does otherwise than `dart-build-cli-app` asks.

