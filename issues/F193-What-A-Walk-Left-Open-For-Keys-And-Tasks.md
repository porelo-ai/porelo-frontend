# F193 — What A Walk Left Open For Keys And Tasks

```json
{
  "$schema": "issue-1.json",
  "id": "F193",
  "title": "What A Walk Left Open For Keys And Tasks",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 42,
  "blockedBy": [],
  "covers": "Key handling, one way to a running task and the proposed project model, built or decided against."
}
```

**What must be true.** Three points a guided walk raised are either built or decided against: how
keys are handled in the interface, one way to reach a running task, and the project model the
backend proposed for a later release.

## How it stands

`StartWorkDialog` in `lib/src/ui/start_work_view.dart` shows `start-prompt` only when
`starting.takesAPrompt`. `IdentityDialog` and `FirstStartWizard` in
`lib/src/ui/identity_view.dart` handle the person's key and card. Their KeePassXC database field,
`identity-database`, takes a `.kdbx` path as text, without a file chooser. These facts do not settle
all three points above.

## To be checked

- Read which of the three points later issues or the current interface already cover; split what
  remains into one issue each.
- Compare the old walk and infrastructure test lists with the finished issues and the test plan for
  acceptance criteria that were never carried over.
