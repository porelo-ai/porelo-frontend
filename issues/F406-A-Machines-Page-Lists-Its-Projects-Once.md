# F406 — A Machine's Page Lists Its Projects Once

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - one list of the machine's projects from the two sources the page holds, each row saying where it comes
from and how it stands, and *Managing this machine* as a section of its own; layout and words, no new call.

**What must be true.** A machine's page shows its projects in one list - Default and the organization's projects -
each saying where it comes from (the machine's own last answer, the organization) and its state, and *Managing this
machine* stands as its own section before or after that list, never between two lists of projects.

## Why

The operator's walk on the rehearsal VM (2026-11-06), rehearsal not yet connected: the page showed "Projects 1"
(Default, from the machine's own last known state, `machine_details_page.dart` in `work`) above, "Projects on this
machine 0" (from the organization, `organization_host_pages.dart` `_projects`) below, and *Managing this machine*
between them. A person cannot tell why there are two lists, or why a project shows while the other says "No projects
on this machine yet". A Bug: the page contradicts itself.

## Plan

- `lib/src/ui/organization_host_pages.dart`: the page's order becomes the connection, *Projects* (one list), then
  *Managing this machine* (address and key, how it stands, its Machine Admins).
- `lib/src/ui/machine_details_page.dart`: its project list is not shown in a machine page that holds an organization's
  machine; its rows join the organization's list instead.
- One row per project name: from the machine (Default, or a project it carries) and from the organization (assigned,
  not yet on it, or still carried after it was taken off), each saying which, and what the machine says of it where
  connected; the empty words only where both are empty.
- **The test that goes red first:** a widget test of a machine page whose machine answers Default and whose
  organization lists no project: one *Projects* list holding Default, from the machine, and no "No projects on this
  machine yet". It guards a person told both that a project is there and that none is.

## Acceptance

- One list of projects on a machine's page, each row naming its source and state.
- *Managing this machine* is a section of its own, not between lists.
