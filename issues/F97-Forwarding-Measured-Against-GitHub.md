# F97 — Forwarding To A Branch, Measured Against GitHub

**Status:** Analyzed.
**Size:** M - no product code changes, but a new acceptance scenario on the VM against GitHub, with
its support for a token and a test repository; it waits for both from the operator, as [F59](README.md#f59) does.

**What must be true.** Forwarding approved work to a branch the person chose from the repository's
own lands on that branch at GitHub.

## Why

The branches offered, the default first, and a new one typed and checked, are already built; they
have not been measured against GitHub.

## Plan

- **What is measured.** `_ShellState._approve` in `lib/src/ui/shell.dart` asks `_branchesFor`
  (which reads `Forge.branches` and the default branch from `Forge.repository`), then
  `askWhichBranch` (`lib/src/ui/gate_view.dart`), then `Gate.approve(backend, branch)` in
  `lib/src/app/gate.dart`. Nothing of this changes unless the measurement finds a fault.
- **A waiting push on the VM.** No integration scenario reaches the gate today. A step makes one
  through `onTheTestMachine` (`integration_test/support/remote.dart`): a task in a project
  following the test repository commits and pushes, so its push waits at the gate.
- **GitHub in the run.** A support file in `integration_test/support/` reads the token and the test
  repository from the environment, as `E2e` in `integration_test/support/e2e.dart` reads
  `SOKAR_E2E_HOST`, and skips the scenario when they are not set. It asks GitHub's API for a
  branch's head commit, and deletes the typed branch afterwards. `tool/e2e.sh` passes the variables
  through.
- **Red first.** A scenario in `integration_test/reaching_a_machine.feature`, "approved work
  forwarded to a branch chosen from the repository's lands on it at GitHub": open the waiting push,
  forward it through "Forward it upstream…" onto an existing branch, and find the commit at the
  head of that branch at GitHub and not on the default branch. A second one types a new branch.
- **The run.** On the VM against Sokar's handover, named in the result, as the other acceptance
  scenarios are.

## Acceptance

- On the VM against Sokar's handover, approved work forwarded to an existing branch and to a newly
  typed one arrives on that branch at GitHub. Seen to fail: the commit missing from the chosen branch
  at GitHub, or landing on another.

## Open questions

- The GitHub token and the test repository for the run, and where the run reads them from without
  their being kept here or in the channel. (the operator's)
- Is this issue blocked by them, as [F59](README.md#f59) is, so its status says so? (the operator's)
- A waiting push needs a task that pushes; is a task whose shell commits and pushes on the VM
  enough, or must it be an agent's work? (the operator's)
