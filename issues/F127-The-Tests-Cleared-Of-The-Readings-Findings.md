# F127 — The Tests Cleared Of The Reading's Findings

**Status:** Backlog; blocked by [F124](README.md#f124).
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
