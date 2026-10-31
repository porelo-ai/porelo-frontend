# F273 — A Developer Joins At One Click

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - replaces the join wizard and laptop-based setup across discovery, verification, project UI and saved host state.

**What must be true.** A person named in a project's access file, which they find through `hosts/<host>/access.yml`'s access repository addresses, sees "in project P on host X" and *Join*. One click follows the project (verified by its signers), writes the host's ssh config and opens the tunnel ([F270](README.md#f270)). Nothing is pasted or typed. A project whose access file cannot be read is said, naming the repository and who may grant it.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's step 6.

## Plan

- **Red first:** replace the setup fixture in `test/app/project_join_test.dart` with fake Core discovery and follow results. An unverified access state naming the person must cause no follow, config write or host connection. This guards joining through forged admission. Then supply verified admission and observe one follow with its trusted signers and one tunnel request after a click.
- Extend the Core boundary in `lib/src/app/fleet_backend.dart` and its adapter in `lib/src/client/porelo_client.dart` for verified admission discovery. Core reads the registry's host access entries, their project access repository addresses, the person's login and keys, and project signers. Consume typed verified results and repository-specific failures. Do not add a second YAML or signature verifier in Flutter. The agreed person, registry and access behavior is not implemented yet; use a fake Core with those shapes until the served contract is available.
- Add admitted project/host rows to `ProjectsPage` in `lib/src/ui/projects_page.dart`, even before a project is followed or a host is watched. Wire their *Join* command through `lib/src/app/commands.dart` and `lib/src/ui/shell.dart`. Replace the selected-project-only and secrets-file prerequisites. An unreadable access repository gets its own row naming the repository and the project admins who can grant access, using verified contact data.
- Rewrite `ProjectJoin` in `lib/src/app/project_join.dart` around the selected verified admission. Use the existing `FleetBackend.follow` signer-list support and observe its verified in-force result. Request the card config and host tunnel from [F270](README.md#f270). Reuse an already followed project or open host. Save the project/host association through `Settings` in `lib/src/app/settings.dart` and add the account to `Machines` in `lib/src/app/machines.dart` only after confirmation. Prevent overlapping clicks and resume safely after partial failure.
- Remove the join wizard and copy-laptop-keys action in `lib/src/ui/project_join_dialog.dart` and their shell and command wiring. Remove the join path's use of `AccessJoin` in `lib/src/app/access_join.dart`, `JoinKeys`, VPN/CA activation, signing-key and secrets-file pickers, local bundle creation, upload playbooks, forge-password feed and secrets terminal. Retire code used only by that path; retain helpers still used by host setup. Own-account provisioning belongs to Machines, tested here behind a fake admitted host. It does not run from the developer's interface.

## Acceptance

- Starting with no followed project and no watched host, verified access naming the current person offers *Join*. One click requests a follow with the supplied signers and the selected host tunnel, then records confirmed membership. It asks for no key, address, password, file or pasted value.
- Forged, revoked or stale admission supplied as a Core refusal starts nothing. An unreadable access repository names its address and the verified admins who may grant it; it does not appear as an empty project list. A follow refusal never falls back to unverified following.
- Double clicks and retry after a failed tunnel do not duplicate follows, watched accounts or host tunnels. A partial result stays visible and never claims the person is ready before confirmation. Two projects on one host reuse its connection.
- Once Machines admits the person's card key, rehearse a real join from an already configured identity and forge session. Check the verified followed revision and reachable account daemon, separately from fake tests.

## To be checked

- Confirm Core's discovery fields for project source, current login, trusted signer list, verified revision, host account and grant contacts. Confirm the served follow response can distinguish verified in-force state from a held or rewritten project.
- Trace remaining callers before deleting `AccessJoin`, `JoinKeys` or VPN helpers; project registration and host setup currently share them. Identify obsolete wizard tests to remove and retain guards for forged admission and failed confirmation.
- Confirm how retry observes a successful follow when host connection failed, and how a later revoked admission affects an already displayed join row. Measure Linux and Windows behavior against the card tunnel implementation.

## Test

Only the change: tests against a fake Core. One VM check once porelo-host admits by the card's key.

## Estimate

`F273 size=M est=60 basis=median M 61 (24 records)`
