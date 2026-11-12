# F521 — A Machine And A Host Played Through From Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F521",
  "title": "A Machine And A Host Played Through From Windows",
  "state": "Backlog",
  "size": "L",
  "priority": "High",
  "rank": 94,
  "blockedBy": [],
  "covers": "Story ST50, a machine and a host reached from Windows, played once from the Windows build as a person would, for ST347's gathered story run: the test VM watched over ssh with its projects, work, terminal and gate, and a host from its card joined, prepared, admitted and added to."
}
```

**Why this size.** L: the Windows form of two existing features, the machine's (`reaching_a_machine.feature`) and the
host's (`rehearsing_a_move.feature`), run from a Windows guest against the test VM and a rented host, with the host's
ssh checked as Windows does it; it crosses the Windows guest, the VM and a rental, so a guess at twice M.

**What must be true.** A run from the Windows build shows, or names as missing, what ST50 promises: a machine over ssh
shows its projects, work, a terminal and the gate, and a host from its card is joined, prepared, admitted and added to,
with no ssh master and with the card's loopback ports held by the window.

## Why

- Serves porelo-project's *A machine and a host reached from Windows* (story ST50, porelo-project cb298f4), as its part
  of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test
  run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** from the Windows build, watches a machine over ssh and opens its projects, its work, a terminal and the
  gate; connects a host from its card, prepares it, admits a person and adds to it.
- **Sees:** each of them answering as on Linux; on Windows no ssh master and each card port served on loopback.

## What exists already

- `i watch the test machine through a forward raised here`, `the test machine is answering`, `i open the project
  on the host`, `i review that work at the gate` and `i close the terminal` (`integration_test/step/`).
- `tool/rehearse_window.sh` drives the host's scenarios against a rented host; `i connect the host from the
  organization` and `the host is answering through the window`.
- The story's test speaks of one ssh process with loopback ends; [F290](README.md#f290) decided otherwise for
  Windows: loopback ports the window holds itself, each connection over its own ssh, no `-L`, no master. The script
  checks the shape [F290](README.md#f290) decided.

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
- On Windows there is no virtual display: the window runs in the Windows machine's own desktop session, and the driver's
  Windows form does there what the Plan says.

## Plan

- The driver's Windows form (as [F516](README.md#f516) makes it) copies HEAD to a Windows guest and runs the feature
  with `flutter test -d
  windows`, the test VM as the machine and, on the operator's word, a rented host as `tool/rehearse_window.sh` rents
  and sweeps it.
- Machine scenario: watch the VM over ssh; `Then its projects, its work, a terminal and the gate are shown`.
- Host scenario: connect from the card, prepare, admit a person, add a repository; `Then the host answers each`, read
  on the host as root; `And no ssh on this computer runs with a master, -L or -R` and `the card's ports are held by
  the window`, read from the guest's process list and `netstat`.
- The rental is swept and the guest's window, config and keys removed at every ending.

## Expected failures

- [F290](README.md#f290) (Implementing): the host functions from a Windows desktop; the host scenario fails on it
  until it is in Review.

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

- One run from the Windows build with a report naming each step: OK, FAIL with what was asked and got, or EXPECTED
  with [F290](README.md#f290).
- The rental is gone after the run, and nothing of the run is left on the guest or the VM.

## To be checked

- Which Windows machine runs it, as for [F516](README.md#f516); and whether the rented host of the move's rehearsal can
  serve
  this run too, so only one rental is made.

## Estimate

`F521 size=L est=122 basis=no measured L median; M median 61 (24 records), about twice, a guess`
