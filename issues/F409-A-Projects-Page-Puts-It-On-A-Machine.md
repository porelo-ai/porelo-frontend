# F409 — A Project's Page Puts It On A Machine

**Status:** Backlog.
**Size:** S - *Put it on a machine…* and *Take it off the machine…* offered on the project's own page, the same
dialogs and the same follow as on the Organization page's project row, moved where both pages share them.

**What must be true.** Where a person may put a project on a machine or take it off, the project's own page offers it
as the Organization page's project row does, with the same dialog, the same words and the same follow afterwards.

## Why

The operator's walk on the rehearsal VM (2026-11-06): the project's page, opened from *My projects*, has no *Put it on
a machine…*; it is only in the Organization page's project row menu. A person who opens the project where they see it
looks for it there. A Bug: the action is missing where the project is shown.

## Plan

- `lib/src/ui/organization_page.dart`: `_putOn` (its `OrganizationPickDialog`, the wait for the organization and the
  follow of the machine) and the take-off confirmation move to functions both pages call, their conditions as today:
  not on a machine and a machine there to put it on; on one the organization lists.
- `lib/src/ui/organization_project_pages.dart`: the project page's head offers both, under the same conditions and
  keys `project.putOnMachine` and `project.takeOffMachine`.
- When F407 is built, the choice of repositories comes to both through the shared dialog.
- **The test that goes red first:** a widget test of a project page for a project on no machine, in an organization
  with one: *Put it on a machine…* is there and sends `org host carry <host> <project>`. It guards the action missing
  from the page a person opens.

## Acceptance

- The project page offers putting it on and taking it off a machine, as the project row does.
