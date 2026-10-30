# F280 — A Lost Or Stolen Key Replaced

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - recovery spans project, host, and registry roles, a restricted Core backup operation, and confirmed results for every affected host.

**What must be true.** A project admin can revoke another person's key in the project's access file and enter their new key, and a host admin can do the same in `hosts/<host>/access.yml`, chosen from the person list; the person keeps their login. A successor card signed by a revoked key is never offered; a registry owner can do the same in `owners.yml` for a host admin or another owner. A revoked key's person is shown locked on every host at once. Where a project, a host or the registry has a single admin or owner, *Use the backup key…* takes the offline backup key's file for this one commit: it may only replace the lost key's entry among the signers or in `owners.yml`, and the interface refuses any other change with it, in Core's words. The backup key file is read once, never copied and never kept; a new backup key is offered afterwards ([F268](README.md#f268)).

## Why

One-click joining from signed state (operator, 2026-10-30): an admin's own key is replaced by another admin or by the backup key; a stolen key is revoked first and locks the person's host accounts at once.

## Plan

- **Red first:** add a fake-Core test in new `test/app/key_recovery_test.dart`. A backup operation changing a second entry or unrelated field must be refused before publication or host sync. A failed host acknowledgment must never appear as locked. These guard against extending backup authority and reporting a revocation that has not taken effect.
- Add a `KeyRecovery` controller in new `lib/src/app/key_recovery.dart` and a recovery dialog in new `lib/src/ui/key_recovery_dialog.dart`. Connect person actions in `lib/src/ui/project_developers_dialog.dart` (`ProjectDevelopersDialog`) and `lib/src/ui/host_admin_dialog.dart`, and registry owner actions through `lib/src/ui/shell.dart` and `lib/src/app/commands.dart`. Reuse the identity and contacts from [F268](README.md#f268).
- Extend `PoreloClient` in `lib/src/client/porelo_client.dart`, models in `lib/src/client/models.dart`, and `FleetBackend`/`PoreloBackend` in `lib/src/app/fleet_backend.dart`. Use Core's agreed recovery behavior from the one-click joining design behind a fake in tests. Core and Machines have not implemented these contracts yet. Core validates role, login, and replacement public key, signs and commits the permitted edit, and brings signed state through SSH. Machines confirms revocation, KRL update, and account locking.
- Select from verified people, preserving the login. Review old and new public fingerprints and the scope: project access, `hosts/<host>/access.yml`, or `owners.yml`. Theft requires revocation and locking first, without successor rotation by the revoked key. Extend `ProjectDevelopers` in `lib/src/app/project_developers.dart` beyond add/remove and laptop removal for this action. Remove reliance on `writeAccessDeveloper` in `lib/src/app/access_developers.dart` for recovery: its existing edit rule permits only laptop removal. Core owns the new format and validation.
- Offer backup recovery only for a sole admin or owner with a registered backup. A local Core terminal through `lib/src/ui/unlock_terminal.dart` consumes the offline file once for the reviewed replacement. Keep neither contents nor a saved file selection; take no passphrase in a form. Core enforces that the complete commit changes only the lost signer entry or permitted `owners.yml` entry. A UI restriction alone is insufficient. After confirmation, offer a replacement offline backup through [F268](README.md#f268).
- Show signed Git state beside per-host results, following `ProjectDevelopers`' publication and retry separation. Keep the confirmed revision and retry only unfinished delivery. Remove any inference of locking from push success or `DeveloperSyncAnswer.dropped`; that reply has no lock or KRL acknowledgment. An unreachable host stays pending with a reason. Hand the affected person to [F268](README.md#f268) for confirmed vault recreation and renewed provider sign-ins.

- “At once” means the revocation is sent to every host the person is on the moment it is committed; a host not reached shows *Lock not on the host yet* until it confirms, and the lock reaches it on the next connect.

## Acceptance

- Fake-Core tests cover project admins, host admins, and registry owners within their authorized scopes. A forged role, unknown person, changed login, or revoked predecessor is refused without publication. Successful replacement retains the login and reports the signed revision.
- Backup recovery accepts exactly the permitted replacement. An extra entry, role change, or unrelated field fails before push. Cancellation makes no recovery call. Missing or unreadable backup input leaves state unchanged. Secrets are entered only in the local Core terminal.
- For multiple host replies, show locked only for confirmed locks of the revoked key. Disconnection or refusal remains pending or refused beside Git state. Retry makes no second commit and repeats no confirmed host work.
- After replacement, offer a new backup and the person's vault-recreation path. Recorded calls, settings, and diagnostics contain no backup-key contents or passphrase.

## Open questions

None.

## To be checked

- Confirm Core's role and recovery verbs, reviewed-change identifier, backup-file consumption, and complete-commit restriction. Exact registry and access schemas remain to be agreed; use semantic fake replies until then.
- Confirm Machines' per-host KRL and lock acknowledgment, host-admin key repinning, and safe delivery retry after access changes. Check how recovery reaches a host after revoking the old key.

## Test

Only the change: tests against a fake Core. No VM run.

## Estimate

`F280 size=M est=60 basis=median M 61 (24 records)`
