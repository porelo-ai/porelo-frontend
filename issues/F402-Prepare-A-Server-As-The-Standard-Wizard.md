# F402 — Prepare A Server As The Standard Wizard

```json
{
  "$schema": "issue-1.json",
  "id": "F402",
  "title": "Prepare A Server As The Standard Wizard",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 3,
  "blockedBy": [],
  "covers": "*Prepare a server* as steps of the standard wizard, each fitting the window."
}
```

**What must be true.** *Prepare a server* fits the window: it runs as steps of the standard wizard (choose the
machine and its address, compare its host key, the settings, the bootstrap line on the server, the run), each step on
one screen, rather than one dialog that runs off the bottom of the window.

## Why

The operator's walk on the rehearsal VM (2026-11-06): the dialog is long again and runs off the bottom of the window.

## To be checked

- Which of the dialog's parts are steps and which stay beside every step (the run's progress, a stopped run's line).
- Whether a rental's give-back, which the same dialog holds, stays a dialog of its own.
