# F318 — An Owner Makes An Admin A Developer

```json
{
  "$schema": "issue-1.json",
  "id": "F318",
  "title": "An Owner Makes An Admin A Developer",
  "state": "Idea",
  "size": "-",
  "priority": "Low",
  "rank": 12,
  "blockedBy": [],
  "covers": "An Organization Admin turns a project's admin into a developer with an entry on the organization page."
}
```

**What must be true.** An Organization Admin turns a project's admin into a developer directly, by an entry *Make a developer* of its own on the organization page, where today they remove the admin and add the person again. An owner has no exception: an owner lists themselves as Organization Admin first. `porelo project member role` is the command.

## How it stands

Read from the code, not run. `OrganizationProjectPage` in `lib/src/ui/organization_project_pages.dart` offers
*Change the role…* on a member's row, using `OrganizationChange.changeProjectMemberRole` in
`lib/src/app/porelo_organization_source.dart`, which calls `porelo project member role`.
`OrganizationPage._projects` in `lib/src/ui/organization_page.dart` gates admin actions with
`view.isOrganizationAdmin`; *Remove <login> as admin…* removes the membership with
`OrganizationChange.removeProjectMember`, and that row has no direct demotion entry. The promised entry
is not available there.
