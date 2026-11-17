# F612 — Handing On the Token Shows Its Step and Time

```json
{
  "$schema": "issue-1.json",
  "id": "F612",
  "title": "Handing On the Token Shows Its Step and Time",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 132,
  "blockedBy": [],
  "covers": "While the window hands the declared token to a machine for a new project, Putting <project> on <machine> shows the step it is in (connecting, reading the declared entry, handing it on, waiting for the machine's answer) and how long it has been running"
}
```

**Why this size.** S: `handOnDeclared` (`lib/src/app/host_token_sources.dart`) runs its steps without saying which,
and `placing_project_dialog.dart` shows one fixed line while `_handingOn` holds. The steps become a state the dialog
shows, with a running time. A widget test.

**What must be true.** A person waiting on *Putting a project on a machine* sees that it is moving and where, and can
tell a slow step from a hung one.

## Found

On 2026-11-17, in a live test. "Handing on the token your Porelo-Vault declares for GitHub to <host>…"
stood for a very long time with nothing moving. It ended in "Done · <host> carries porelo".

## Plan

- Today: `_words` in `placing_project_dialog.dart` says one sentence for the whole `_handingOn` time.
- Change: `HostTokenSources` says which step of the hand-over runs: connecting, reading the declared entry, handing
  it on, waiting for the machine's answer. The dialog shows that step and the seconds since the hand-over began.
- Red first: a widget test with a hand-over held in each step. Today the words do not change; after the change each
  step is named and the time counts up.

## Acceptance

- Each step of the hand-over is named while it runs, with the time since it began.
- The end still says Done or the machine's reason, as today.
- The test above fails without the change.
