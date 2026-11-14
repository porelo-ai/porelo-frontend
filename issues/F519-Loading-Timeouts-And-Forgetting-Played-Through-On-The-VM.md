# F519 — Loading Timeouts And Forgetting Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F519",
  "title": "Loading Timeouts And Forgetting Played Through On The VM",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 92,
  "blockedBy": [],
  "covers": "Story ST32, load, time out and forget one connection, played once on the test VM in the window as a person would, for ST347's gathered story run: a first load and a rare action showing one loading state, a server that never answers ending in a named timeout, one connection forgotten and the others kept."
}
```

**Why this size.** S: a feature of three scenarios, almost all of whose steps exist in `reaching_a_machine.feature`
(trying a socket from the dialog, declaring and forgetting a connection); new are a stand-in socket that accepts and
never answers, and a comparison of two loading states.

**What must be true.** A run on the test VM shows, or names as missing, what ST32 promises: a page loaded for the first
time and a rarely used connection action show the same loading state, a connect to a server that accepts and never
answers ends with a named timeout, and forgetting one connection leaves the others.

## Why

- Serves porelo-project's *Load, time out and forget one connection* (story ST32, porelo-project cb298f4), as its part
  of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test
  run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** opens a page for the first time, and a rarely used connection action; connects to a server that
  accepts and never answers; declares two connections and forgets one.
- **Sees:** the same loading state in both; the connect ending within its stated time with a named timeout; the
  forgotten connection gone and the other still listed.

## What exists already

- `i try the test machine from the dialog with the socket …` and `the trial says …` try a given socket from the
  dialog and read what the window says; `no forward raised for the trial is left` checks the forwards.
- `i declare the machine's own key for … from the interface`, `i forget the connection … from the interface`,
  `the machine lists the connection …` and `the machine no longer lists the connection …` declare, forget and read
  connections on the machine.
- Nothing listens on a socket and stays silent, and nothing compares two loading states.

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

- Scenario one: `When I open the connections for the first time` and `When I open a rare connection action`;
  `Then both show the same loading state`, judged by the shared loading widget's key in both.
- Scenario two: `Given a socket on the test machine that accepts and never answers` (a small Python listener in the
  account's runtime directory, started over ssh and ended at the end); `When I try the test machine from the dialog
  with that socket`; `Then the trial ends within its stated time, naming a timeout`; `And no forward raised for the
  trial is left`.
- Scenario three: two connections declared, one forgotten, `Then the machine lists the other connection still`; both
  removed at the end.

## Expected failures

- One way to show loading, built since: scenario one failed without it.
- Porelo's Varlink calls ending within a stated time with a named error when the other side accepts and never
  answers; scenario two's named timeout fails until Porelo gives it.
- No forward left behind when the interface ends without asking, built since; a forward left after the timeout
  names it.

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
  the loading's one way, the forward left behind, or Porelo's missing read deadline.
- No listener, connection or forward of the run is left on the VM.

## Estimate

`F519 size=S est=15 basis=median S 15 (11 records)`
