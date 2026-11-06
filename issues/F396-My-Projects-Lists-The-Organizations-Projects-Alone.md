# F396 — My Projects Lists The Organization's Projects Alone

**Status:** Implementing (Backlog by the operator, 2026-11-06).
**Size:** S - one page's list, the rail's count and their tests; no contract.

**What must be true.** Where the window reads an organization, *My projects* lists the projects of that organization
the person holds a role in, and nothing a start in a checkout made. Every other project of a machine stands under
*All projects on your machines*.

## Why

In the operator's window, *My projects* lists `units4j-project` and `utils4j-task` as *only on this computer*. They came
from starting work in a checkout, and they are no project of the organization.

What the page lists beside the organization's projects today, read in the code:

| Row | What it is | Where it comes from |
|---|---|---|
| A project of source `local`, *only on this computer* (`lib/src/ui/organization_project_pages.dart`, `_listed` where `source == 'local'`) | A project registered on this computer's Porelo alone. A first start in a checkout on the `default` path copies the `project.yml` the person said yes to into `$XDG_CONFIG_HOME/porelo/projects/<name>/` (Core's `FirstStart`), and `porelo project list` answers every such copy, and every project registered by hand, as `local` (Core's `ProjectListCommand` through `OrgAccess.localProjects`). | `porelo project list --json`, read by `OrganizationSource.myProjects` |
| *Default*, one row per machine listed (`lib/src/ui/shell.dart`, `_defaultRows`) | The project every machine has, where work without a project of its own runs. No organization holds it, and no start makes it. | Each machine's inventory; put on this page by F380, after `doc/decisions.md`, *Daily work in front, setting up apart*: "*My projects* lists *Default*" |

The rail counts both (`lib/src/ui/shell_rail.dart`, `builtIn + local`).

*All projects on your machines* (`ProjectsPage`, titled *Projects on my machines* beside an organization) already lists
every project of every machine from its inventory, the local copies and each machine's *Default* among them, with their
pages and menus. Removing a local project (`OrganizationSource.whyNoRemoval`, through `shell.dart`'s
`_whyNoRemoval`) is offered from a project's own menu, which those rows keep.

## Plan

- `OrganizationProjectsPage` lists no row of source `local` and no row of *Default*; the rail's count is the
  organization's projects the person holds a role in, without `local` or `builtIn`.
- *Default* stays under *All projects on your machines* and in *New work*. This takes back the row F380 put on
  *My projects*; F380's own state stays the operator's.
- The section *Daily work in front, setting up apart* in `doc/decisions.md` says *My projects* lists the organization's
  projects the person holds a role in, and *Default* stands with every machine's projects.
- The link *All projects on your machines* stays, and a person with no project of the organization still reads that a
  Project Admin adds them.
- Without an organization read, nothing changes: *My projects* is then the page of every machine's projects.
- Tests in `test/ui/organization_page_test.dart` and the rail's: a `local` project and *Default* stand on *Projects on my
  machines* and not on *My projects*, and the count says the same; each seen red first.

## Decided

- **Default leaves *My projects* too** (operator, 2026-11-06): *My projects* lists only the organization's projects the
  person holds a role in, and the rail counts the same.

## To be checked

- Whether `porelo project list` should keep answering a checkout's copy as `local` at all is Core's; the window needs
  nothing from Core for this.
