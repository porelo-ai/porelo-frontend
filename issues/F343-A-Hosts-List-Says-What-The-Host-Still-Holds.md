# F343 — A Host's List Says What The Host Still Holds

**Status:** Review.

**What must be true.** The list of projects on a host's page shows a project being taken off until the host has let it go, and says why if it
holds on to it.

**The operator:** also on the project's row.

## Why

Read from the code, not run. `OrganizationHostPage._projects` in `lib/src/ui/organization_host_pages.dart`
joins `host.projects` with `_progress?.projects` for a connected Machine Admin. It keeps a project the
machine still names, says `being taken off, which can take up to five minutes` and `held: <why>`, and hides
`gone` rows. Without that connection or role it shows the organization's projects alone.

`OrganizationPage._projects` in `lib/src/ui/organization_page.dart` and `OrganizationProjectsPage` in
`lib/src/ui/organization_project_pages.dart` read the organization's placement without `HostProgress`.
They do not show a machine retaining a project after take-off, so the promised state on the project's row
is not built.

## The shape

For a host admin who is connected, the rows are the organization's projects together with those the host names, each with what the host says:

- the organization no longer names it and the host still carries it: `being taken off, which can take up to five minutes`;
- `held`: `held: <why>`, naming the repositories with unpushed commits;
- `gone`: no row.

Not connected, or no host admin: the organization's word as today, and the line saying so stays.

A test with a host answer naming a project the organization does not, seen red first.

## To be checked

- That the host's answer keeps a taken-off project in `projects` as `held` or `gone`.
- How it fits [F342](README.md#f342), which makes this list read-only.
