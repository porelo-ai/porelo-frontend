# F268 — One Key And One Card Per Person

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - an identity controller and settings view, Core client replies, publication tracking, and confirmed host-vault recovery.

**What must be true.** At first start the interface has Core make the person's one Ed25519 SSH key, kept in their KeePassXC file and served by its SSH agent, and their card (login, name, optional email, key, created, expires). *File my card* commits `people/<login>.card` to the registry when the person may write there; otherwise it names who may, with their email where their card names one (Write, Copy). *Change my key* runs Core's rotation and shows, per registry and host, whether the new card arrived (done, pending, refused) with Retry. *I lost my key* says plainly that the person's vault on each host is deleted and made again and the agents' sign-ins are made once more, lists those hosts and does it on one confirmation; a host vault that answers "made with another key" leads to the same offer, never to "wrong passphrase". A project with a single project admin and no backup key is warned about, with *Make a backup key…*, which runs Core's `identity backup-key`, opens the folder of the written file and says to keep it offline. *My key was stolen* cannot be done by the person alone: it says that an admin revokes the key first, which also locks the person's host accounts at once, and names those admins with their email where their card names one; after that it runs as a lost key, and a successor card signed by the revoked key is never offered. When the person's key is not among their central forge account's public keys, the identity place says so and links that page; on a forge without such a list it says that an admin confirms the fingerprint. *Make a backup key…* is offered likewise to a single host admin and to a registry with a single owner. No private key is shown, logged or put on a command line.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 1 and the decisions on a lost key and the backup key (operator, 2026-10-30).

## Plan

- **Red first:** add a fake-Core test in new `test/app/identity_test.dart`. Canceling recovery must make no destructive call. Confirmation must reset only the reviewed host vaults, once each. Refused hosts remain unfinished. This guards against deleting the wrong vault or repeating a successful deletion on Retry.
- Add an `Identity` controller in new `lib/src/app/identity.dart` and an `IdentityView` in new `lib/src/ui/identity_view.dart`. Connect first-start discovery and Settings actions through `lib/src/ui/shell.dart` (`_ShellState`) and `lib/src/app/commands.dart`, using the layout in [F278](README.md#f278). Read the local person's identity independently of the selected host backend.
- Extend `PoreloClient` in `lib/src/client/porelo_client.dart`, models in `lib/src/client/models.dart`, and `FleetBackend`/`PoreloBackend` in `lib/src/app/fleet_backend.dart`. Build against Core's agreed identity and card behavior from the one-click joining design, behind a fake in tests. These contracts are not implemented yet. Core creates the key in KeePassXC, signs and publishes cards, checks forge ownership, rotates keys, and enrolls the new host-vault slot before retiring the old one. Return public metadata and operation results only.
- Show the card fields and fingerprint. File it when Core reports write permission; otherwise show permitted contacts with Write and Copy. Show a missing forge key with the account-page link, or the admin fingerprint-confirmation instruction when no public key list exists. Core supplies the trust result.
- Track rotation by registry and host with done, pending, refused, and Retry. Preserve completed steps. For lost keys, list every affected host and the deletion and provider sign-in consequences before one confirmation. Require the authorized replacement from [F280](README.md#f280) where needed. For theft, show the revoking admins first and never offer rotation with the revoked predecessor.
- Route Core's typed host-vault key mismatch from `lib/src/app/vault_unlock.dart` and the shell's vault action to recovery instead of passphrase retry. Offer `identity backup-key` for each sole project admin, host admin, and registry owner without a backup. Core writes the offline file; open its containing folder after confirmation. Unlocks stay in KeePassXC or a Core terminal through `lib/src/ui/unlock_terminal.dart`.
- Use `Settings` in `lib/src/app/settings.dart` only for public view choices. Remove private-key selection and passphrase fallback from the person-identity flow; do not treat `HostUpRecord.identity` as that identity or erase legacy teardown records. The interface generates no key and retains no private key, unlock answer, or backup-file contents.

## Acceptance

- Fake-Core app tests cover first start, an existing identity, card filing, denied writes with contacts, forge-key mismatch, and a forge without a public key list. No action reports completion before Core confirms it.
- A refused rotation destination remains refused beside confirmed destinations. Retry sends only unfinished work. A revoked predecessor never enables rotation.
- Recovery cancellation makes zero clear/init calls. Confirmation uses the reviewed hosts and new identity without deleting unrelated vaults. Retry does not clear an already recreated vault. A key mismatch offers recovery without asking for a Vault-Passphrase.
- Check all three sole-admin or owner scopes. Backup creation opens the returned folder only after Core confirms the file. Unsupported Core methods disable the action with a reason.
- Inspect fake process calls and settings: no private key, sign-in answer, or derived vault share reaches command arguments, logs, clipboard, or settings. Secret input belongs to KeePassXC or the Core terminal.

## Deferred

- After a create, rotate or lost-key run in the KeePassXC terminal, the typed reason is read from the terminal's last line; when Core's answer does not fit on it, the view says to read the terminal and reads Core back.
- A filed card is committed in the registry checkout, not pushed; pushing it is the registry's publication step.
- The backup key waits for Core's backup-key verb and refuses until then.

## To be checked

- Confirm Core's identity verbs, public replies, KeePassXC creation handoff, mismatch error, and resumable recovery identifiers. Confirm how reset completion is read back after interruption.
- Confirm the registry location, card validity defaults, permitted contacts, forge public-key lookup, and backup-file result with Core and the forge client package. Use fakes until those contracts exist.
- Confirm host-vault reset and slot-enrollment acknowledgments over SSH with Core and Machines. Check existing unlock and settings migration callers before removing their person-key assumptions.

## Test

Only the change: widget and app tests against a fake Core. No VM run.

## Estimate

`F268 size=M est=60 basis=median M 61 (24 records)`
