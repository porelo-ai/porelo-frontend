# F628 — Approval, New Work And Forms Moved Into Services

```json
{
  "$schema": "issue-1.json",
  "id": "F628",
  "title": "Approval, New Work And Forms Moved Into Services",
  "state": "Estimated",
  "size": "M",
  "priority": "High",
  "rank": 4,
  "blockedBy": [],
  "covers": "Approving a push, starting new work, a key recovery attempt and saving a forge run in services tested without widgets; the handlers keep the asking"
}
```

**Why this size.** M: four handlers of about 50 to 80 lines in four files, each moved into a service method with unit
tests; no contract changes.

**What must be true.** Approving a push, starting new work, attempting a key recovery and saving a forge behave as
today, with their steps and rules in services under `lib/src/app/`, tested without widgets; the handlers only ask and
show. Last of the four parts begun in [F625](README.md#f625).

## Plan

Read in today's code.

- `_approve` (`lib/src/ui/shell.dart:3742`): the task's forge branch, the branch last forwarded, the forge's branches,
  the branch asked, `gate.approve`, the branch remembered, guarded against the shown push changing meanwhile.
- `_newWork` (`lib/src/ui/shell.dart:6178`): the connected machines and their projects, each chosen by dialog, the
  project selected and the work started, again when the project changes.
- `_attempt` (`lib/src/ui/key_recovery_dialog.dart:89`): the file picked, the request started, the terminal run, the
  request ended, and restored where the terminal never opened.
- `_save` (`lib/src/ui/forges_view.dart:269`): the address checked, the token asked, the forge added, edited, renamed
  or its identity added.
- Steps as in [F625](README.md#f625): the services' unit tests first, seen red, then the handlers reduced to the
  mapping. Harm guarded: a push approved onto a branch other than the one chosen, a recovery request left open, a
  forge saved without its token.

## Acceptance

- `test/features` and `test/ui` pass unchanged; the new unit tests were seen red first.
