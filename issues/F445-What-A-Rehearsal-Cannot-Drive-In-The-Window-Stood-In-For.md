# F445 — What A Rehearsal Cannot Drive In The Window, Stood In For

```json
{
  "$schema": "issue-1.json",
  "id": "F445",
  "title": "What A Rehearsal Cannot Drive In The Window, Stood In For",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 78,
  "blockedBy": [],
  "covers": "The sign-in up to its terminal, the host key compared by the test, a screenshot on failure, and the gathered push, each passed, failed or said not run."
}
```

**Why this size.** three scenarios added to the move rehearsed through the window, a screenshot on failure, and their
tests; the gathered push only once the host takes the central token from the person's vault.

**What must be true.** The parts of a move a person does outside the window, or by eye, are covered in the unattended
rehearsal as far as they can be, and what cannot be is said in its report rather than passed over.

## Why

The move rehearsed through the window (driven in a local VM against a rented host) leaves out what needs a browser, a
person's comparison by eye, or a secret typed into a terminal: an agent's own sign-in, the host's key on first
connecting, and the gathered push to central. Left out silently, a fault there shows only in the operator's test.

## What it builds against (in words)

- **The sign-in:** the host starts an agent's login in a container of its own and names the command that attaches a
  terminal to it; closing that terminal ends only the watching, and a login nobody finishes ends by itself after 30
  minutes.
- **The host's key:** the rehearsal's own root ssh to the server, trusted when the server was rented, reads the host's
  key as the server has it.
- **The gathered push to central:** the host's push asks the person's central token on its terminal today; once the
  host reads it from the person's vault on the host, nothing is typed.

## Plan

- **The sign-in, up to the terminal:** the window starts it, the terminal opens on the host and shows the provider's
  link; the scenario then closes the terminal and checks on the host that the login still runs, and leaves it to end
  by itself. The browser login is not driven; the report says so.
- **The host's key:** the scenario reads the fingerprint the window shows when connecting and compares it with the one
  read over the rehearsal's root ssh; a mismatch fails the run.
- **A screenshot of the virtual display** beside the screen's text, for every failed scenario.
- **The gathered push and pull to central**, once the host takes the central token from the person's vault: driven from
  the window, checked at the central forge. Until then the scenario is not run, and the report says why.

## Acceptance

- The report names each of these four as passed, failed (with its screenshot), or not run with its reason.
- No token is typed into the window or a terminal by the rehearsal.

## To be checked

- Whether the window shows the host's fingerprint at a point a test can read before it is trusted.

## How it stands

Built on the rehearsal of [F444](README.md#f444), in the same feature file and runner.

- **The host's key:** the scenario opens the host's page in the organization and compares the key it shows (the one
  the window trusts, from the organization's card) with the key the rehearsal read from the server as root
  (`--host-key`), scrolled to where the page says it; the comment is not compared. A mismatch fails it.
- **The sign-in, up to the terminal:** from *New work* on the first carried repository, where the host says the agent
  is not signed in: the sign-in's terminal shows the provider's `https://` link (up to 15 minutes, the first one
  builds its image), *Close the terminal* closes it, and the host's `AgentSignIns` still lists a login running for
  an agent it said was not signed in before. The browser login is not driven and the login is left to end by itself.
  Where the agent is signed in, or the host holds a sign-in of its own, the scenario is not run and says so. So one
  host covers either this scenario or the work started in the ones before, never both: those need the agent signed
  in.
- **A picture of the window** for every failed scenario, as `pictures/<scenario>.png` beside the report: each step of
  the rehearsal runs inside `pictured`, which on a failure draws the window from its own root layer, the whole of
  it, and lets the failure go on unchanged. The VM has no screen-capture tool, and none is needed. The interface's
  own start (`the interface is running`) is shared with the leased suite and not pictured. Not yet seen from a real
  run.
- **The gathered push to central** is not run and says why: it waits on the host taking the central token from
  the vault. The window has no gathered push yet either; it is built with that.
- `tool/test_report.dart --lines=` gives a skipped scenario's reason (`SKIPPED <name>: <why>`), read from the
  `messageType: skip` event `markTestSkipped` prints, as a real run showed it. `rehearse_window.sh` now fails a run
  with a `FAIL` or with no scenario that ran, and lets a `SKIPPED` with its reason stand.
- agy's reading (gemini-4-argon-high), not ready: the picture hung on `reportTestException`, which Flutter checks
  after every test, so every passing and skipped scenario would have failed; a login check that held whatever ran;
  the sign-in pressed while still disabled; the host's key line not scrolled into view; the picture cropped; a tar
  error on a run without pictures; "no scenario ran" said of a run where all failed. All fixed.
- **To be checked, answered:** connecting from the organization shows no fingerprint before trusting; the window
  trusts the card's key, and the host's page says it as a key line, which is what the scenario compares.

