# F318 — An Owner Makes An Admin A Developer

**Status:** Idea.

**What must be true.** An organization owner can turn a project's admin into a developer directly, with an entry of its own, where today they remove the admin and add the person again. `porelo project member role` is the command.

## How it stands

Read from the code, not run. `OrganizationProjectPage` in `lib/src/ui/organization_project_pages.dart` offers
*Change the role…* on a member's row, using `OrganizationChange.changeProjectMemberRole` in
`lib/src/app/porelo_organization_source.dart`, which calls `porelo project member role`.
`OrganizationPage._projects` in `lib/src/ui/organization_page.dart` gates admin actions with
`view.isOrganizationAdmin`; *Remove <login> as admin…* removes the membership with
`OrganizationChange.removeProjectMember`, and that row has no direct demotion entry. The promised owner's
entry is not available there, and an owner outside the Organization Admin list has no admin action in that row.
