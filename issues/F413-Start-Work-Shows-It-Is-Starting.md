# F413 — Start Work Shows It Is Starting

**Status:** Accepted (operator, 2026-11-06).
**Size:** XS - from the press of *Start work* on a machine's page until its answer, the button is disabled and a line
says what it waits for.

**What must be true.** A press of *Start work* on an organization's machine page shows at once that it works ("Starting
work in porelo on rehearsal…", the button disabled) until the work is open or the refusal is said; a second press
starts nothing more.

## Why

The operator's walk on the rehearsal VM (2026-11-06): "Start work in porelo" on rehearsal's page seemed to do nothing
for many seconds, then said why it was refused ("porelo could not be taken on this machine: …"). Nothing showed the
press was taken, so a person presses again or leaves.

`lib/src/ui/organization_host_pages.dart` `_startWork` awaits `onStartWork` (`shell.dart`
`_startFromTheMachinePage`, which asks the machine to take the project before work opens) with no state of its own:
the button stays as it was and `_startWhy` is set only at the end.

## Plan

- `_startWork` keeps `_starting` (the project, or Default) from the press to the answer; the button is disabled with
  a small turning ring, and a line under it says "Starting work in <project> on <machine>…, which can take a minute
  while the machine takes the project".
- **The test that goes red first:** a page whose `onStartWork` has not answered yet shows the line and a disabled
  button after one press, and a second press calls it no second time. It guards a second start sent by a person who saw
  nothing happen.
