# F425 — The Repositories Put On A Machine Chosen From A List

```json
{
  "$schema": "issue-1.json",
  "id": "F425",
  "title": "The Repositories Put On A Machine Chosen From A List",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 72,
  "blockedBy": [],
  "covers": "Putting some of a project's repositories on a machine lists them by full name with the key beside, checkboxes, a search field, *All* and *None*."
}
```

**Why this size.** one dialog's choice widget (`CarryChoice` in `lib/src/ui/organization_dialogs.dart`) and its tests.

**What must be true.** Putting some of a project's repositories on a machine lists every repository by its full
name, the project's key beside it, each with a checkbox, under a search field, with *All* and *None*, so a person
finds and ticks the ones they mean without guessing what a key stands for.

## Why

The trial move of 2026-11-07 put one repository of the `porelo` project on a rented host. *Put porelo on a
machine* offered *Some of its repositories* as chips labelled only by the project's repository keys (`core`,
`sluice`, …). A person who knows the repositories by their full names (`porelo-message-sluice`) had to guess,
and with seventeen of them the chips found nothing.

## Plan

- `CarryChoice` reads the project with `organization.source.readProject` as now. Each repository row shows its full
  repository name, the last part of its central address (`ProjectRepository.central`, else `address`, without
  `.git`), and its key beside it, smaller, with a checkbox; a row with neither address shows the key alone. What goes
  into `repositories` stays the key.
- A search field on top filters the rows by name or key, case-insensitive, while typing; a filter that matches
  nothing says so. *All* ticks every row the filter shows, *None* clears every row the filter shows.
- A repository already on another machine stays listed, not tickable, with the machine named on its row, in place
  of the sentence below the chips.
- Red first: a widget test that finds the full name `porelo-message-sluice` in the list, types `sluice` into the
  search, ticks the one row left, and confirms that the change is sent with `repositories: sluice`.

## Acceptance

- Each repository is shown by full name with its key beside it, and a checkbox; ticking sends its key.
- Typing into the search field narrows the list by name or key; *All* and *None* act on the rows shown.
- A repository on another machine is shown with that machine's name and cannot be ticked.
- *Put it on the machine* stays grey, with its reason, while no repository is ticked.
