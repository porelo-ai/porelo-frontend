# F550 — My Projects Is One List With Default

```json
{
  "$schema": "issue-1.json",
  "id": "F550",
  "title": "My Projects Is One List With Default",
  "state": "Backlog",
  "size": "M",
  "priority": "Highest",
  "rank": 5,
  "blockedBy": [],
  "covers": "Beside an organization, My projects lists every project the person works in, each machine's Default and its local projects included, each marked for what it is, and the link All projects on your machines goes; the rail counts the same rows."
}
```

**Why this size.** Several modules (the organization's projects page, the shell's projects page and rail count, the
shared project row) and about ten tests that open the machines' list, plus a decision that changes.

**What must be true.** Beside an organization, a person finds every project they work in under *My projects*, the
*Default* project included, without a second list behind a link: each row says what it is (a project of the
organization, *Default* on a machine, a project local to a machine) and opens the page it opens today.

## Plan

- **Today.** With an organization, `OrganizationProjectsPage` (`lib/src/ui/organization_project_pages.dart`) lists
  only `view.projects` where `view.isMine(project)` (a role in it and its Git repository), one row each, keyed
  `my-project <name>`, naming its host. Its button `projects-of-machines`, *All projects on your machines*, sets the
  shell's `_machineProjects` (`lib/src/ui/shell.dart`), which shows `ProjectsPage` (`lib/src/ui/projects_page.dart`)
  titled *Projects on my machines*: for every `listedMachines` machine, every project of `projectsOnMachine`
  (`lib/src/app/machines.dart`), keyed `project <machine>/<name>`. Those rows are of four kinds:
  - **Default**, once per machine, always there, even before the machine answers: it **lands in My projects** as its
    own row per machine, *Default* on that machine, with the row `projectListRow` draws today.
  - **A project of the organization the person holds a role in**, on the machine that carries it: it **lands in its
    organization row**, which already names its host; no second row.
  - **A local project**, such as one a start in a checkout copied onto a machine: a machine's row that is neither
    *Default* nor a project of the organization (`project list` says its source is `local`). It **lands in My
    projects** as its own row, marked as local to its machine, never counted or worded as the organization's.
  - **A project of the organization the person holds no role in**, on a machine they watch: it is no project they
    work in and **stays only in that machine's own Projects section** (`machine_details_page.dart`), which keeps
    listing every project of the machine.
- **Steps.** `OrganizationProjectsPage` takes the machines' rows from the shell (Default and local projects, drawn by
  `projectListRow`, opening through the same `onProject` as today) below the organization's; the button and the
  shell's `_machineProjects` go, with the *Projects on my machines* title and path. The rail's `projectsInRail` counts
  the rows the page lists. Without an organization, `ProjectsPage` stays *My projects* as it is.
- **Red first.** `test/ui/my_projects_organization_alone_test.dart` is rewritten to state the new harm: with an
  organization, *Default* on each machine and a local project stand under *My projects*, the local project marked as such
  and not worded as the organization's, an organization project its machine carries stands once, and the rail counts
  exactly the rows shown; it fails on today's code. The phone-title test of *Projects on my machines* is deleted with
  the page.
- **Tests that open the machines' list** by `projects-of-machines` are moved to the one list:
  `organization_project_pages_test.dart`, `project_address_test.dart`, `organization_page_test.dart`,
  `project_room_test.dart`, `rail_navigation_test.dart`, `leaf_page_look_test.dart` and
  `test/features/support/tiles.dart`.
- `doc/decisions.md` (*My machines and My projects*) and its index row say the one list; the explanation *What is in
  My projects?* in `shell.dart` too if it names the split; a `CHANGELOG.md` entry under `[Unreleased]`.

## Acceptance

- With an organization, *My projects* shows the person's organization projects, *Default* once per machine and each
  local project marked as one, with no link to another list; an organization project carried on a machine shows once;
  the rail's count equals the rows. The rewritten test is seen red on today's code, and red again when the local
  copy's mark is broken on purpose.

## To be checked

- That no other page (a machine's page, *New work*, the finder) links to *Projects on my machines*, by a search for
  `_machineProjects` and the title once the button is gone.
