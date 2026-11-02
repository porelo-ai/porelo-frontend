# F310 — A Project Page For Its Admin And Its Members

**Status:** Implementing.
**Size:** L - *Projects* becomes one entry per project with no machine, and a project's page with repositories and members replaces today's page per machine; several days, the calls behind it come separately.

**What must be true.** *Projects* lists the projects a person is a project admin or a member of, with the one host carrying each and their role. A project's page holds the project repository's address, its repositories and its members with their role and lock: its project admins change them there, a member reads the same page and changes nothing, and it opens the project on its host, where work, agents, messages and saved jobs start as today.

## The contract in words

A project is on one host at a time. It is its card in the organization (its name and the first admin an owner names), its members with their role (admin or developer) and lock, the address of its project repository in a file its admins write, and its `project.yml`, which stands in that repository and is what the project decides. The organization holds who and which keys, and never opens that repository. Porelo itself fetches `project.yml` with Git and checks it. Any unlocked member with role admin changes `project.yml` and the members; a locked member is listed but may do nothing until an admin unlocks them. A change of repositories is a signed commit of an admin, which `porelo project repository add|remove` makes. A member's key is the one on their card. Writes name the person, revision and id, as on the organization's page.

The interface writes no `project.yml` itself. A project starts not opened: an admin's `porelo project open` makes the project repository through the forge client with their token and signs the first commit; others read that it is not open yet.

## Plan

- Extends the source of the organization's page in `lib/src/app/organization_source.dart` with a project's view and writes, and its fixtures.
- `lib/src/ui/organization_projects_page.dart` (new): the list for this person, one row per project, no machine. It takes *Projects* where this computer reads an organization; today's page per machine stays reachable until the cut's calls replace it, so that the suite holds what still depends on it.
- `lib/src/ui/project_page.dart` (new): *Change the address…*, repositories with *Add*/*Remove*, members with *Add*, *Remove* and a change of role in their rows, for the project admin; the same page read-only for a member.
- What today's page per machine also shows moves: saved jobs, terminals and running work stay with a machine or with *Work*; `project_details_page.dart` loses its *Machines* section and its registry parts. To be read per item when building, and said in the issue where it moves.
- Red first: widget tests for the admin's and the member's page, and that no host name occurs on either.

## Acceptance

- Widget tests with the fixtures: a project on two hosts is one row; the project admin's actions write what they say; a member sees every value and no action; no text on the list or the page names a host; a refused write shows the store's words and changes nothing.
- Seen to fail by giving a member an action, and by listing a project per host.

## To be checked

- Where a daily action of today's page per machine goes when it has no other home; a loss of function is said in the channel before it is built.
