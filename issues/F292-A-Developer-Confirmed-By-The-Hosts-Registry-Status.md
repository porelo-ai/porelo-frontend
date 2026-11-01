# F292 — A Developer Confirmed By The Host's Registry Status

**Status:** Idea.
**Severity:** medium.
**Size:** M - the confirmation of project access changes, the project developers dialog and its commands, and the
host transport's read of the status; built against an answer porelo-host serves.

**What must be true.** *Add a developer* counts as done only when the host says the person is active in the project.
*Lock in this project* and *Let back in* are offered in the app and count as done only when the host says the person
is locked or active again in that project.

## Why

The host's `sync` answers whom it `added`, `dropped` and `refused`, not each person's state. A sync whose answer was
lost and that runs again answers `unchanged`, so it cannot confirm an Add, and nothing can confirm a Lock or a Let
back in. Today the app therefore lists Lock and Let back in as not connected.

## The shape

- After the sync, the interface asks the host's `registry status` (root, over the card's `-F` file) and reads the
  person's state in the project: `active`, `locked`, `pending`, `purged` or `named`.
- Add is confirmed by `active`; Lock by `locked`; Let back in by `active`. Any other state keeps the change *not
  confirmed yet* with the host's state in words, and a retry runs the sync and the read again without a new commit.
- Lock and Let back in become commands in `commands.dart`, offered in the project developers dialog for a person of
  the project, with their reason when they cannot run.

## Plan

- `CardProjectAccessTransport` (`lib/src/app/project_access_transport.dart`) reads `registry status` after `sync`;
  `ProjectAccess._continue` (`lib/src/app/project_access.dart`) confirms from that state instead of `added`.
- `ProjectDevelopers` (`lib/src/app/project_developers.dart`) and `ProjectDevelopersDialog` offer Lock and Let back in.
- **Red first:** with the host stand-in, a sync answer lost and run again (`unchanged`) leaves Add unconfirmed today;
  with the status read, the person's `active` confirms it, and `pending` does not.

## Acceptance

- Add, Lock and Let back in are confirmed only by the person's state in `registry status`, never by the sync's exit
  or its `added` list alone.
- A host stand-in with two projects: Lock changes only the selected project's state; Let back in restores it.

## To be checked

- That porelo-host's `registry status` answers each person's state per project, leaves out revoked or refused
  logins, and answers `pending` for a purge cut off halfway, before this is built.
