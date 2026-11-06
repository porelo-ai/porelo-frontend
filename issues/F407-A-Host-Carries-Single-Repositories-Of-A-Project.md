# F407 — A Host Carries Single Repositories Of A Project

**Status:** Accepted.
**Size:** M - carrying a project onto a machine chooses its repositories, the machine's page lists what it carries by
repository, and one is taken off alone; on porelo's new answer and verbs, with their stand-ins and tests.

**What must be true.** Putting a project on a machine offers the whole project, the comfortable form when all are
needed, or chosen repositories of it; the machine's page lists what it carries, a whole project or its single
repositories; and a repository is taken off alone, saying that its read key goes off the central forge too, or naming
it for removal where that cannot be done from here.

Requirement of the operator (2026-11-06). porelo's part names in the organization's files how a machine's card holds
single repositories and carries them by `porelo org host carry <host> <project> --repository <name>…` and `uncarry`
likewise; porelo-host's part has the machine follow only the named repositories and take one off its forge and its
deploy key off the central forge. Each is filed in its repository.

## Plan

- `lib/src/app/organization_source.dart`: `OrganizationHost` reads what porelo's answer says a machine carries per
  project - the whole project or its named repositories - kept open for a form it does not know, which is shown with
  porelo's words; `OrganizationChange.addProjectToHost` and `removeProjectFromHost` take `repositories`, sent as
  `--repository` each (`porelo_organization_source.dart`), none meaning the whole project as today.
- `lib/src/ui/organization_page.dart`: the dialog that puts a project on a machine (`addProjectToHost`) offers *The
  whole project* (preselected) or a choice of its repositories, from the project's repositories the organization
  lists; taking off (`removeProjectFromHost`) is offered per repository and for the whole, its confirmation saying the
  read key goes off the central forge, or that it is named for removal.
- `lib/src/ui/organization_host_pages.dart`: *Projects on this machine* lists a project carried in part with its
  repositories, each with *Take it off this machine…*.
- `test/support/organization_fixtures.dart` and the features' stand-in learn the new answer.
- **The test that goes red first:** carrying one repository of a project sends exactly `org host carry <host>
  <project> --repository <name>` and the page lists that repository alone; taking it off sends `uncarry` with it and
  leaves the project's other repositories. It guards a whole project put on a machine, or taken off it, when one
  repository was meant.

## Blocked by

- porelo's answer naming a machine's carried repositories and its verbs with `--repository` (Agent Core's issue).

## To be checked

- The form of porelo's answer, field by field, once it is filed; until then the plan's names are this window's.
