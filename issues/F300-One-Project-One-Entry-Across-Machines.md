# F300 — One Project, One Entry Across Machines

```json
{
  "$schema": "issue-1.json",
  "id": "F300",
  "title": "One Project, One Entry Across Machines",
  "state": "Idea",
  "size": "M",
  "priority": "Medium",
  "rank": 19,
  "blockedBy": [],
  "covers": "One project read as one entry under Projects, with the machines it is on under it."
}
```

**Why this size.** the projects page's rows and its navigation count, with their tests; no contract with another
repository.

**Severity.** Medium.

**What must be true.** A project that this computer and a host both hold reads as one entry under *Projects*, with
the machines it is on under it, so nobody takes two rows of one name for two projects. "Without a project" is shown
once per machine in the same way.

## Why

`OrganizationProjectsPage` in `lib/src/ui/organization_project_pages.dart` lists each organization project once
with its host. *All projects on your machines* opens `ProjectsPage` in `lib/src/ui/projects_page.dart`, which builds
one row per machine and project, including *Without a project* per machine. That file does not meet the promised
grouping of a project held on several machines. `projectsInRail` in `lib/src/ui/shell_rail.dart` counts organization
projects when an organization is read, otherwise machine-project rows.

## The shape

- Grouped by project: the project's name as a heading, one line per machine under it, each with that machine's state
  and actions as today. Alternatively grouped by machine with a heading per machine; reading one project as one entry
  makes grouping by project the first choice.
- The navigation count counts projects, not rows.

## Plan

- `lib/src/ui/projects_page.dart` (`projectListRow` callers), `lib/src/ui/shell.dart` and
  `lib/src/ui/shell_rail.dart` (`projectsInRail`, the count).
- **Red first:** a widget test with one project on two machines shows its name once, with both machines under it.

## Acceptance

- A project on n machines shows its name once and n machine lines.
- Selecting a machine line acts on that machine only, as a row does today.
