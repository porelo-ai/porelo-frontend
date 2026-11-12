# F518 — The Chosen Branch Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F518",
  "title": "The Chosen Branch Played Through On The VM",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 91,
  "blockedBy": [],
  "covers": "Story ST38, the chosen branch receives the work, played once on the test VM in the window as a person would, for ST347's gathered story run: a branch template and an explicit branch chosen, the work approved, the result read on GitHub, another's branch refused."
}
```

**Why this size.** M: a feature of two forwards and a refusal against the test organization on GitHub, a stand-in for
another person's branch there, and a reading of the forge's branches before and after; the forwarding step of the move's
rehearsal and the walk's forge seeding are there.

**What must be true.** A run on the test VM shows, or names as missing, what ST38 promises: work approved onto a branch
template and onto an explicit branch lands on exactly that branch on GitHub, no other branch moves, and a forward onto
an existing branch that belongs to someone else is refused.

## Why

- Serves porelo-project's *The chosen branch receives the work* (story ST38, porelo-project cb298f4), as its part of
  *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test run
  once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** chooses a branch template for one task's work and an explicit branch for another's, approves each at
  the gate, and reads the result on GitHub; then tries to forward onto a branch that someone else already pushed.
- **Sees:** each piece of work on exactly the branch chosen, every other branch where it was; the forward onto the
  other person's branch refused, saying whose it is, and that branch unchanged.

## What exists already

- `i forward it to the task's own branch on the host's forge` (`integration_test/step/`) forwards a gate's work
  through the which-branch dialog (`askWhichBranch` in `lib/src/ui/gate_view.dart`) and `the host's forge has that
  branch at the reviewed commit` reads it; both are written for a rented host's forge.
- `tool/walk_idea.sh` seeds repositories of a GitHub test organization, notes their tips as T0, reaches GitHub's API
  with the test identity's token on standard input, and puts every branch back at the end.
- `a task of the project … has work waiting at its gate` makes a task with work at its gate.

## How it is run

- One feature file and its test, as the existing ones are, run on the test VM `ubuntu26.04` in this repository's own
  account: the checkout's HEAD copied there, the window started under `xvfb-run` inside `dbus-run-session` through
  `tool/e2e.sh --machine`, as `tool/walk_idea.sh` and `tool/rehearse_window.sh` do. Steps already in
  `integration_test/step/` are reused by their sentence; new steps go beside them.
- The run is driven by one story driver, `tool/play_story.sh check|run --vm USER@VM --vm-key FILE --story <id>
  --report DIR`, modelled on `tool/rehearse_window.sh`: the first of these story issues to be built makes it, the
  others add their story. Its report holds one line per step (`OK`, `FAIL` with what was asked and got, or `EXPECTED`
  with the missing issue), a picture of the window where a step failed, and one closing line per story for ST347's
  gathered run: passed, failed with the step, or waiting on the missing issue.

## Plan

- The driver seeds one repository of the test organization (as `walk_idea.sh` does) and pushes a branch
  `someone-else/…` there as a second identity, or with a commit whose author is not the test person, and notes every
  branch's tip.
- Steps: two tasks with work at the gate on the VM's porelo; `When I forward the first to the branch template …` and
  `When I forward the second to the explicit branch …`; `Then GitHub has exactly that branch at the reviewed commit`
  and `no other branch of the repository moved`, read over GitHub's API; `When I forward the third onto
  someone-else/…`; `Then it is refused, naming whose branch it is` and `the branch is unchanged on GitHub`.
- Every branch the run made is deleted and every repository put back at T0 at the end.

## Expected failures

- [F97](README.md#f97) (Implementing): forwarding to a chosen branch measured against GitHub; the GitHub reads fail
  on it until it is in Review.

## Note

- A test script is test tooling, not production code: no tests for the test scripts, no red-first, no review loops
  (one Sonnet reading at most). The script is proven by its run on the VM.
- On the VM a failing script is fixed ad hoc on the spot and the run carries on. Every fault found, in the script or in
  the product, is collected, not fixed one by one. After the run: product faults become estimated Backlog issues,
  script fixes go into one commit, then one new run.
- One VM run at a time on this host, through the Coordinator: ask before you start a run and post when it ends. No
  second VM, no Molecule beside it; clean up after.
- A story whose issues are not all in Review yet still gets its script and one run; the run names the missing issue as
  an expected failure.

## Acceptance

- One run on the test VM with a report naming each step: OK, FAIL with what was asked and got, or EXPECTED with
  [F97](README.md#f97).
- The test organization's repositories stand at their T0 after the run, and no branch the run made is left.

## To be checked

- Where the window offers a branch template: at Start, or in the gate's which-branch dialog only; the step chooses
  it where the window offers it.
- How the second identity's branch is made with no token of another person: a deploy key of the test organization,
  or the forge's own refusal of a branch the person did not create.

## Estimate

`F518 size=M est=61 basis=median M 61 (24 records)`
