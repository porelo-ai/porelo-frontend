# F266 — The Project Screen Shows Its Persons

```json
{
  "$schema": "issue-1.json",
  "id": "F266",
  "title": "The Project Screen Shows Its Persons",
  "state": "Idea",
  "size": "M",
  "priority": "Medium",
  "rank": 36,
  "blockedBy": [],
  "covers": "A project's screen shows its server and its persons with their state; actions chosen from the rows."
}
```

**Why this size.** a design, then its screen: a project shows the server it is on and its persons with their roles and state, and its actions are chosen from there.

**How it stands.** Held: GUI changes wait until the whole flow has been gone through again.

**What must be true.** A project's screen shows the server it is on, its project admin and its developers, each with their state (admitted, locked), and offers the project's actions from those rows: change or remove a developer, take the project off its server. The design is filed and agreed before it is built.

## Why

`OrganizationProjectPage` in `lib/src/ui/organization_project_pages.dart` shows members, their roles, card standing
and lock state. Member rows offer *Lock* or *Unlock*, *Remove…* and *Change the role…* to the permitted roles.
It reads the project through `PoreloOrganizationSource.readProject` in `lib/src/app/porelo_organization_source.dart`.

`lib/src/ui/organization_project_pages.dart` does not show the project's machine or offer taking it off that machine
on its detail page. A member's change is written to the organization, and a machine follows it by itself, so a
person has no state between the two. *Take it off the machine…* is on the project's row
under *Organization* in `lib/src/ui/organization_page.dart`. Those parts of the promise above are not met on the
detail page. The related machine page is covered by [F265](README.md#f265).

The Project screen design is the first of two designs ([F265](README.md#f265) is the second), followed by a read-only query contract with Agent Machines.

## Plan

- A design page, written before code, with the project's server, persons, states and row actions.
- The persons from `PoreloOrganizationSource.readProject` until the query contract gives them from the host.
- **Red first:** the built screen's widget test that a locked developer shows "locked" and the project's machine stands there.

## Test

Only the change: the screen's widget tests. On VM A: one look at the project's screen.

## Estimate

`F266 size=M est=60 basis=median M 61 (24 records)`, the query contract not included.
