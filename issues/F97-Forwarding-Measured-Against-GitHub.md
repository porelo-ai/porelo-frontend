# F97 — Forwarding To A Branch, Measured Against GitHub

```json
{
  "$schema": "issue-1.json",
  "id": "F97",
  "title": "Forwarding To A Branch, Measured Against GitHub",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 5,
  "blockedBy": [],
  "covers": "Forwarding to a chosen branch measured against GitHub."
}
```

**Why this size.** no product code changes, but a new acceptance scenario on the VM against GitHub, with its
support for the run's token and a branch made for the run; M.

**What must be true.** Forwarding approved work to a branch the person chose from the repository's
own lands on that branch at GitHub, and on no other.

## Why

The branches offered, the default first, and a new one typed and checked, are already built; they
have not been measured against GitHub.

## How it stands

The test organization `porelo-ai-test` and its token exist now; the idea walk runs against them on the local VM.

## Plan

- **On the VM, through the walk's script.** `tool/walk_idea.sh run --test forwarding_to_a_branch` runs
  `integration_test/forwarding_to_a_branch_test.dart` there, without a planner or a seed. It makes the branch
  `walk-<run>-existing` of the first issue repository (foo-1) at its default tip, names `walk-<run>-typed` as the
  one to type, and deletes both at its ending, as it deletes every branch named for the run.
- **GitHub in the run.** The window's own forge list reaches GitHub through `PORELO_FORGE_TOKEN`, taken from the
  run's vault into the window's environment alone; the steps read GitHub with `git ls-remote` through the run's
  credential helper, so no token is in the test.
- **What is measured.** `_ShellState._approve` in `lib/src/ui/shell.dart` asks `_branchesFor`, then
  `askWhichBranch` (`lib/src/ui/gate_view.dart`), then `Gate.approve` (`lib/src/app/gate.dart`), whose porelod
  pushes. Nothing of this changes unless the measurement finds a fault.
- **A waiting push.** A task of foo-project in foo-1, started from the window unattended, commits one file and
  pushes it to its gate, as the move rehearsal's gate step does; the person reviews it at the gate.
- **The scenarios.** One forwards onto the branch the repository has, one onto a new branch typed. Each checks that
  the dialog offers the default branch first, that GitHub has the chosen branch at the reviewed commit, and that the
  default branch did not move.

## Acceptance

- On the VM against Porelo's handover, approved work forwarded to an existing branch and to a newly
  typed one arrives on that branch at GitHub. Seen to fail: the commit missing from the chosen branch
  at GitHub, or landing on another.
