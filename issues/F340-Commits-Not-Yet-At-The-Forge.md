# F340 — Commits Not Yet At The Forge

**Status:** Review.

**What must be true.** A person sees on a project's row and page whether approved commits on the host wait to go to the central forge,
with the action beside it, and who may do it.

**The operator:** *Push the approved main…* stands visible beside the row while commits wait, a second exception to [F329](README.md#f329).

Read from the code, not run. `OrganizationProjectsPage` in `lib/src/ui/organization_project_pages.dart`
shows the central forge state and its age on the project's row. While approved commits wait and no repository
has moved on, it shows *Push the approved main…* beside the row for an unlocked member.
`OrganizationProjectPage` in the same file does not read or display `CentralState`, so the promised
state and action on the project's page, including a line per repository, are not built.

## The state

The host can work this out with no central token, using the read-only key it already holds for each
repository; its following can keep the result. Host-side key use and following are not checked here.
`CentralState` and `SshHostProgress.central` in `lib/src/app/host_progress.dart` read the answer of
`/usr/local/sbin/porelo-host-push --central <project>` over ssh as root and sum the ahead commits across
repositories. The answer includes `read_at`; a failed or unreadable answer cannot say. Four answers,
not a bare number:

| The host says | The row says | Action |
|---|---|---|
| some commits are ahead | `N approved commits not yet at <forge>` | *Push the approved main…* beside it |
| the same | `up to date with <forge>` | none |
| the forge moved on, or the two went apart | `<forge> has moved on: a push would be refused` | *Take the central state…*, where it applies |
| no read key, or the forge out of reach | `cannot say how it stands with <forge>` | the ⋮ as today |

*Cannot say* must never read as up to date. The answer can be up to five minutes old, so it says when it was read, and it only prompts:
the push still decides.

## Who may do it

Read from the code, not run. A person with a working role in the project, not locked, whose role can be read now; connected to the host
under their own card; with a secrets file chosen, from which the central token comes. Where one of these is missing the action stays
visible and greyed with its reason, as the menu does today. Pushing is no admin's privilege, so the row offers it to every member.

`OrganizationProjectsPage` in `lib/src/ui/organization_project_pages.dart` hides the push button and menu
for a locked member, rather than keeping the action visible and greyed as promised.

## The command

`SshHostProgress.central` in `lib/src/app/host_progress.dart` calls the person-facing command. Its behavior
on a real host is not checked here.

## To be checked

- Several repositories in one project: the row gives a sum, and its page one line each.
- What [F329](README.md#f329) and [F338](README.md#f338) make of the row's other words beside this one.
