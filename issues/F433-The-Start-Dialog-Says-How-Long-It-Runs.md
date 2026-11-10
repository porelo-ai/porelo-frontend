# F433 — The Start Dialog Says How Long It Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F433",
  "title": "The Start Dialog Says How Long It Runs",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 20,
  "blockedBy": [],
  "covers": "The start dialog's modes say how long they run; an unattended run's minutes are asked and sent."
}
```

**Why this size.** the start dialog's modes say how long the work runs, and an unattended run's minutes are a field.

**What must be true.** *A shell, driven by hand* says it has no time limit and runs until it is stopped. *Unattended,
against a prompt* has *Minutes it may run*, 30 unless changed, and says that at the end the run is stopped and what it
made is kept. The number is sent as `Start`'s `minutes`; a session sends none.

## Why

The second move (2026-11-08), finding 10: the dialog asked no time limit and said nothing of one; `Start` gives an
unattended run 30 minutes when none is sent. Among the small fixes (E10).

## Plan

- `lib/src/ui/start_work_view.dart` `_WhichMode`: the words of each mode; under the prompt a whole-number field,
  1 or more, 30 by default.
- The start model: `minutes` kept for an unattended run only, handed to the client's `minutes`.
- Red first: the field shows only for unattended; its number reaches `Start`; a session sends no `minutes`.

## Acceptance

- Each mode says how long it runs; the unattended minutes are asked and sent.
