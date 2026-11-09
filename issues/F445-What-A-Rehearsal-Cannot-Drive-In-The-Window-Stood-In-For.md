# F445 — What A Rehearsal Cannot Drive In The Window, Stood In For

**Status:** Implementing.
**Size:** S - three scenarios added to the move rehearsed through the window, a screenshot on failure, and their
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
