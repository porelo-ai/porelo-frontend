# F312 — A Host Page For Its Host Admins

**Status:** Implementing.
**Size:** L - the host's page under *Machines* with projects, admins and its own connection, on a machine's page of today; several days, the calls behind it come separately.

**What must be true.** Under *Machines*, a host admin finds on the host's page its state, the projects it carries with *Put a project on the host* and *Take it off*, its host admins with *Add* and *Remove*, *Change address and host key…* and *Refresh*. Which projects a host carries is shown and changed here alone, whether or not this computer prepared it.

## The contract in words

A project is on one host at a time. A host admin decides which projects a host carries, never which persons: every member of a project is on its host. Putting a project on a host sends the host admin's central token through the tunnel once, typed in a terminal, so its repositories are on the configured forge at once, the host's own where one is installed and the central forge otherwise, and adds a read-only deploy key made on the host for each repository; taking it off removes them. The host fetches its organization's and projects' state itself every five minutes, or at once on *Refresh*. Taking a project off deletes its room there with its conversation, and the dialog says so. A host's last host admin cannot be removed: the store refuses.

## Plan

- `lib/src/ui/organization_host_pages.dart` shows the host's view and writes, with actions in rows; `lib/src/app/host_progress.dart` reads `org status` and `org refresh`.
- Today's per-person admission, lock and let back in, and *Bring the state to the host*, leave the page.
- Red first: widget tests for a host admin and for another person, who sees no management.

## Acceptance

- Widget tests with the fixtures: each action writes what it says; another person sees none of them; a host in the organization that this computer did not prepare has the page; a refused write shows the store's words; a person's own connection stands here for everyone connected.
- A connected host admin sees each project's state and `why`, and each locked person's `purge_on` as the account deletion day, read only. No per-person lock, add or purge action is offered.
- Seen to fail by showing management to a person who is no host admin.

## To be checked

- The design canvas's host page.
