# F473 — The Window Calls The Host Programs It Has Now

```json
{
  "$schema": "issue-1.json",
  "id": "F473",
  "title": "The Window Calls The Host Programs It Has Now",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "Every call the window makes on a host names a program the host has now: root's org status, org refresh and person purge by /usr/sbin/porelo-host, and a project's central state from the person's own daemon there, so no machine page fails on a removed program."
}
```

**Why this size.** Five remote command lines in two modules and the package, one read moved to the daemon's answer, and
their tests; no contract changes.

**What must be true.** A host admin who opens a machine's page, presses *Fetch now*, gives a host their token, or takes
Porelo off a machine reaches the host's own program, not one the host no longer has. A person on *My projects* sees how
a project stands with central as the daemon on its host says it.

## Plan

The host package no longer installs `/usr/local/sbin/porelo-host-person` or `/usr/local/sbin/porelo-host-push`; its
root program is `/usr/sbin/porelo-host`, and a person's push and pull are Porelo's own `porelo host push` and
`porelo host pull`. Built:

- `lib/src/app/host_progress.dart`: `SshHostProgress.statusVerb` is `/usr/sbin/porelo-host org status --json` (without
  `--json` the host answers in words) and `refreshVerb` is `/usr/sbin/porelo-host org refresh`, both still as root over
  the pinned config with nothing on standard input. Both answer the same JSON as before, so `HostProgress.read`, the
  give-back's central blockers and `aheadOfCentral` in `central_release.dart` keep their input.
- The same file: `SshHostProgress.central`, which ran `porelo-host-push --central <project>` as root, is gone, and so is
  `CentralState.fromAnswer`. `CentralState.fromRepositories` reads the daemon's `Projects` row instead: each repository
  it carries with a `central` other than `no-central`, its `ahead` as the count and the oldest `aheadMeasured` as when it
  was read. A repository said `ahead` with no count reads as cannot say, never as up to date.
- `lib/src/app/organization_connections.dart`: `CardHostConnections.central` asks the person's own daemon on the host
  (`Machines.of(machine).backend.projects()`) once the connection is up; anything it cannot ask or that is not listed
  cannot say. `organization_project_pages.dart` asks once the connection is up rather than as soon as it is made.
- `packages/porelo_host/lib/src/host_run.dart`: the take-down's membership read is `/usr/sbin/porelo-host org status
  --json` and its purge `/usr/sbin/porelo-host person purge <login>`, as root.
- `packages/porelo_host/lib/src/project_transfer.dart`: *Give it my token* feeds `/usr/sbin/porelo-host org refresh`,
  through a terminal or directly, as root. The token feed shared with the gathered push stays as it was:
  `projectTransferCommand`, which still names `porelo-host-push`, is no longer called by the window.
- Red first: `test/app/host_progress_test.dart` (the status and refresh lines), `test/app/organization_connections_test.dart`
  (central from the daemon, nothing run as root), and the package's `host_run_test.dart`, `down_cli_test.dart` and
  `project_transfer_test.dart` with the new lines; each was seen red against the old names.

## Acceptance

- A machine's page, *Fetch now*, *Give it my token* and *Take Porelo off this machine…* run against a host of the
  current host package, and none names `porelo-host-person` or `porelo-host-push`.
- *My projects* shows a project's central state as the host's daemon lists it, and never up to date for a count nobody
  gave.

## How it stands

- Built on the branch `fix-host-programs`, with the tests above red first and the whole suite run once.
- The host's `person purge` purges only a person locked, listed in no project and past their purge day; the old one
  purged any recorded person. The take-down still purges each membership holder the person confirmed, so a holder still
  listed in a project is now refused in the host's words, and the take-down stops there, as `doc/design.md` says.
  Whether the confirmation should offer only those the host can purge is for the operator to decide.
- `projectTransferCommand` and its `porelo-host-push` line stay in the package unused by the window; the gathered push
  goes through the daemon's `PushToCentral`.
- Not tried against a live host: the five lines were read in Porelo's host program and its manual page, not run.
