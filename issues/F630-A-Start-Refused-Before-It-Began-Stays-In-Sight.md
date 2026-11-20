# F630 — A Start Refused Before It Began Stays In Sight

```json
{
  "$schema": "issue-1.json",
  "id": "F630",
  "title": "A Start Refused Before It Began Stays In Sight",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "A start the machine refuses before its task exists, such as at the first-start question, is said in full in the open form and listed under Needs you, never only in a status line cut short after the form closed"
}
```

**Why this size.** S: the refusal paths before a task exists in the shell's start, their wording and a Needs-you entry,
with widget tests; no contract.

**What must be true.** When *Start it* ends in a refusal before any task exists, the person sees it whole where they
pressed, and it stays under *Needs you* with the machine and the repository until dismissed. Today the form closes and
the only trace is a status line cut short ("…so nothing started: a checkout is named b…").

## Plan

- `lib/src/ui/shell.dart:3405`: the refusal of `askBeforeTheFirstTask` is said with `_say` after the form closed. It
  goes instead to the form's own problem line, which keeps the form open, and to a Needs-you entry naming the machine,
  the repository and the reason in full; the same for the other refusals on that path before Start is asked.
- Test, seen red first, in `test/ui` or `test/features`: a machine refusing the first-start question leaves the form
  open with the reason whole and lists it under *Needs you*. Harm guarded: a person who thinks the task runs.

## Acceptance

- With the refusal of [F629](README.md#f629) reproduced against `FakeBackend`, the form stays open with the whole
  reason, and *Needs you* lists it.
