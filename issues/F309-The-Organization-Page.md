# F309 — The Organization Page

**Status:** Implementing.
**Size:** L - a new rail item and page with four filtered sections, three dialogs and role-bound actions, against a source of its own and fixtures; several days, the calls behind it come separately.

**What must be true.** A person opens *Organization* in the rail, under *Set up* after *Projects*, and sees what the organization is, where it is kept and how their own card stands, then its people, projects, hosts and owners. Every action stands visibly in its row, and each person sees only the actions their roles give.

## The contract in words

An organization has four parts: owners, people (one card per person: login, public key, revocation), projects (name, project repository's address, project admin, members with a role) and hosts (address, host key, host admins, the projects it carries). The roles:

| Role | Holds it | May here |
|---|---|---|
| person | whose card the organization holds | read everything; file, change and withdraw their own card |
| organization owner | named among the owners | revoke any card; add and remove a project and change its admin; add and remove a host; add and remove an owner |
| project admin | named on the project's card | nothing on this page: their project's page has it |
| host admin | named on the host | nothing on this page: their host's page has it |

A read names the revision it rests on. A write names the acting person, the revision it was made against and an id, so a store that moved on refuses it and the same id asked again gets the same answer. The last owner cannot be removed: the store refuses, and the page shows that refusal in its words.

## Plan

- `lib/src/app/organization_source.dart` (new): plain data (`OrganizationView`: name, where it is kept, revision, my card's state, persons, projects, hosts, owners) and the abstract source the page reads and writes through. It carries no path, commit or signature. A person's state is trusted; not yet, the identity source not reached; or revoked.
- `test/support/organization_fixtures.dart` (new): a source holding such an organization, one view per role, that records each write and can refuse one with its words.
- `lib/src/ui/organization_page.dart` (new): the explanation block on top, then *People*, *Projects*, *Hosts* and *Organization owners* in `FilteredListSection`, with rows from `expandable_list_row.dart` and actions as `Command`s in `commands.dart` with their own `Home`, not behind ⋮. A person with no card sees a banner with *Add me* above the sections.
- Rows: *People*: own row *Change my key*, *Withdraw my card*; another's *Revoke the card…* for an owner. *Projects*: its admin, whether one is admin, member or neither, *Open under Projects* where one is in it; *Add a project*, *Change the project admin…*, *Remove the project…* for an owner. *Hosts*: its admins and projects, *Open the host's page* for its host admins; *Add a host*, *Remove the host…* for an owner. *Organization owners*: *Add an organization owner* and *Remove* for an owner.
- Dialogs: *Add a project* (a name and the project admin, any person whose card is trusted; no host), *Add a host* (a name and the first host admin), *Add me*. Nothing is shown as done before the source's own answer.
- `Section.organization` in `shell_model.dart`, the entry in `shell_rail.dart`, the page in `shell.dart`.
- Red first: a widget test per role over the fixtures, that the actions of another role are absent and each action writes what it says.

## Acceptance

- Widget tests with the fixtures: per role, the actions shown and absent; a person with no card sees *Add me*; each write carries the person, revision and id; a refused write shows the store's words and changes no row; a section's filter narrows its rows; the page works at phone width.
- An absent or unreadable state reads as such, never as trusted or empty: an identity source not reached says so in the row.
- Seen to fail by giving a member an owner's action on purpose.

## To be checked

- The design canvas's organization page and dialogs, read before the widgets are written.
- Where a machine and a project stand in their organization's tree, as [F123](README.md#f123) asks: shown here.
