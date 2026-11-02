# F310 — A Project Page For Its Admin And Its Members

**Status:** Implementing.
**Size:** L - *Projects* becomes one entry per project with no machine, and a project's page with repositories and members replaces today's page per machine; several days, the calls behind it come separately.

**What must be true.** *Projects* lists the projects a person is the project admin or a member of, once each, with their role. A project's page holds its repositories and its members with their role: its project admin changes them there, a member reads the same page and changes nothing, and nothing on it names a machine.

## The contract in words

A project is its card in the organization (its name and its project admin), its members with their role, and its repositories, each with its address, which is a place of work. Where a project itself is kept is the organization adapter's alone: no page names it. Rights come from roles: the project admin changes the project, and the adapter secures each change in its own way. A member's key is the one on their card. Writes name the person, revision and id, as on the organization's page.

The interface writes no `project.yml`: it asks through the same source, whatever keeps the project.

## Plan

- Extends the source of the organization's page in `lib/src/app/organization_source.dart` with a project's view and writes, and its fixtures.
- `lib/src/ui/organization_projects_page.dart` (new): the list for this person, one row per project, no machine. It takes *Projects* where this computer reads an organization; today's page per machine stays reachable until the cut's calls replace it, so that the suite holds what still depends on it.
- `lib/src/ui/project_page.dart` (new): repositories with *Add*/*Remove*, members with *Add*, *Remove* and a change of role in their rows, for the project admin; the same page read-only for a member.
- What today's page per machine also shows moves: saved jobs, terminals and running work stay with a machine or with *Work*; `project_details_page.dart` loses its *Machines* section and its registry parts. To be read per item when building, and said in the issue where it moves.
- Red first: widget tests for the admin's and the member's page, and that no host name occurs on either.

## Acceptance

- Widget tests with the fixtures: a project on two hosts is one row; the project admin's actions write what they say; a member sees every value and no action; no text on the list or the page names a host; a refused write shows the store's words and changes nothing.
- Seen to fail by giving a member an action, and by listing a project per host.

## To be checked

- Where a daily action of today's page per machine goes when it has no other home; a loss of function is said in the channel before it is built.
