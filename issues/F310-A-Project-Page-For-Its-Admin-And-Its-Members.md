# F310 — A Project Page For Its Admin And Its Members

**Status:** Backlog.
**Size:** L - *Projects* becomes one entry per project with no machine, and a project's page with repositories and members replaces today's page per machine; several days, the calls behind it come separately.

**What must be true.** *Projects* lists the projects a person is the project admin or a member of, once each, with their role. A project's page holds the project repository's address, its repositories and its members with their role: its project admin changes them there, a member reads the same page and changes nothing, and nothing on it names a machine.

## The contract in words

A project is the card in the organization (name, project repository's address, project admin), its members with their role, and its `project.yml` in the project repository (its repositories, agents and signers). A member's key is the one on their card. The project admin signs the members; only `signers` sign `project.yml`. Writes name the person, revision and id, as on the organization's page.

The interface writes no `project.yml` itself: a project's repositories are changed through Porelo's own command, which signs. The project admin makes the project repository when they first open the project; the page offers that step and says what it does.

## Plan

- Extends the source of the organization's page in `lib/src/app/organization_source.dart` with a project's view and writes, and its fixtures.
- `lib/src/ui/projects_page.dart`: the list by `getProjects` for this person, one row per project, no machine; *Projects you may join*, *Set up a project from a repository* and *Follow a project by its address* leave it.
- `lib/src/ui/project_page.dart` (new): *Change the address…*, repositories with *Add*/*Remove*, members with *Add*, *Remove* and a change of role in their rows, for the project admin; the same page read-only for a member.
- What today's page per machine also shows moves: saved jobs, terminals and running work stay with a machine or with *Work*; `project_details_page.dart` loses its *Machines* section and its registry parts. To be read per item when building, and said in the issue where it moves.
- Red first: widget tests for the admin's and the member's page, and that no host name occurs on either.

## Acceptance

- Widget tests with the fixtures: a project on two hosts is one row; the project admin's actions write what they say; a member sees every value and no action; no text on the list or the page names a host; a refused write shows the store's words and changes nothing.
- Seen to fail by giving a member an action, and by listing a project per host.

## To be checked

- The design canvas's project page for its admin and for a member.
- Where a daily action of today's page per machine goes when it has no other home; a loss of function is said in the channel before it is built.
