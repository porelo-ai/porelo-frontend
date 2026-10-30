# F271 — A Host Admin Admits From The Registry

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - about a day across preparation hooks, registry mutations, host delivery and admin actions, reusing the shared registry and SSH work.

**What must be true.** Only a host admin named in the registry's `owners.yml` is offered *Prepare a server…* and *Admit*; anyone else sees who may, with their email where their card names one. When *Prepare a server…* has a ready server, the interface files `hosts/<host>/card` (name, address, SSH port, SSH host key, services with the forge's web and Git ports and the homeserver's port), signed by the host admin. The give-back deletes it, only after the give-back was confirmed ([F264](README.md#f264)'s order). *Admit* is a pick from the registry's persons; it commits `hosts/<host>/access.yml` (each project with its admin, that admin's key fingerprint and its access repository's address, since the host anchors on its pinned host admin alone), brings the registry to the host through the tunnel, and asks for the sync. Lock, let back in and delete an account are chosen from the host's person list, with [F262](README.md#f262)'s words. A host whose synced commit is behind the registry shows "not on the host yet" with *Bring it to the host*.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 2, 3 and 7.

## Plan

- Use the verified registry and current person's identity from [F269](README.md#f269) and [F268](README.md#f268). Change `prepareServerCommand` and `preparedHostCommands` in `lib/src/app/commands.dart` and their wiring in `lib/src/ui/shell.dart`. Enable preparation and admission only for a host admin in Core's accepted `owners.yml`; a denied action shows who may and their available email. Recheck authorization before a write, not just when building a menu.
- Hook ready completion in `HostRuns._addHost` (`lib/src/app/host_runs.dart`) and `HostSession.preparedHost` (`lib/src/app/host_session.dart`) to Core's registry file boundary. File the signed host card only after a checked successful setup. Adapt `PreparedHost` in `packages/porelo_host/lib/src/host_record.dart` and its protocol reader in `packages/porelo_host/lib/src/steps.dart` to Machines' SSH-only completion shape: name, address, SSH port, host key and forge/web/Git/homeserver service ports. Do not invent missing ports from today's VPN record. Share this work with [F270](README.md#f270).
- After `hostGivenBack` confirms teardown, delete the card through Core from `HostRuns.confirmDown` and the fallback teardown in `lib/src/ui/host_dialog.dart`. Keep publication separate from provider give-back. Persist an unfinished card write or deletion in `Settings` (`lib/src/app/settings.dart`) for retry without renting or giving back twice. Replace `PreparedHostPanel`'s manual public-value handover in `lib/src/ui/host_admin_dialog.dart` with registry publication status.
- Replace `HostAdminDialog`'s typed admin name and laptop key block with registry person selection and host membership actions. Add a host access controller in new `lib/src/app/host_access.dart`. It asks Core to file the selected login, fingerprint and project/access-repository association, signs and publishes, delivers the registry, then requests sync. Lock, let back in and delete act on the host's person list with [F262](README.md#f262)'s scope and confirmation. Remove direct `HostAdminRequest.admit` calls and its laptop-block path in `packages/porelo_host/lib/src/server_contract.dart`; retire host-admin project registration in favor of [F272](README.md#f272).
- Extend `HostRun` in `packages/porelo_host/lib/src/host_run.dart` from the private, checked bundle upload used by [F252](README.md#f252) to registry delivery over [F270](README.md#f270)'s pinned tunnel. Core's registry file and Machines' registry intake, descendant check and sync answers are agreed shapes, not built contracts; fake both boundaries. Keep the exact published revision pending until that host confirms it. Upload or sync failure shows "not on the host yet" and Bring it to the host; retry performs only unconfirmed work.
- **Red first:** add new `test/app/host_access_test.dart` with fake Core and a host stand-in. A refused upload must prevent sync and retain the published revision for retry; a wrong revision must not confirm admission. Extend `test/app/host_runs_test.dart` and `test/ui/host_take_down_confirmation_test.dart` to prove no card is filed before ready and no card is deleted on failed or unconfirmed give-back. These guards prevent unauthorized access, stale admission and loss of a still-rented host.

## Acceptance

- A non-admin cannot invoke preparation or admission, even through a retained callback after permissions change. The interface names the permitted host admins and available email. Refused registry people cannot be selected or written.
- A ready setup files one signed card with all public SSH and service fields. Waiting, malformed and failed completions file none. A publication retry does not rerun setup. Confirmed give-back precedes deletion; a failed give-back leaves the card and recovery state intact.
- Admit publishes the selected person's fingerprint and project/access address, uploads that signed revision, then syncs. A failed publication causes no upload; a failed upload causes no sync. A wrong host or revision is refused. Retry survives restart without a second commit or admission.
- Lock, let back in and delete target the selected host membership only and display the host's confirmed result. Registry state and the host's last applied revision remain distinct. A stale host offers Bring it to the host until the intended revision is confirmed.
- Tests use fake Core and Machines contracts. When their implementations are available, the targeted VM check proves registry intake accepts a descendant and refuses an older signed state without restoring a removed person. No laptop key block or secret field is part of admission.

## Open questions

None.

## To be checked

- Confirm Machines' completion fields, host registry intake location, upload authorization, sync/status reply and descendant refusal. The current `PreparedHost` requires VPN and CA fields and does not carry SSH or service ports.
- Confirm Core's host-card signing and deletion operations, and the host-access shape for admitting an admin before that admin registers a project. Confirm where host-wide lock and deletion are signed and how a successor host admin is authorized.
- Check both teardown paths retain a pending registry deletion after provider success and registry failure. Confirm host status can be queried after restart and cannot be confused with another host or a project-access commit.

## Test

Only the change: tests against a fake Core and the host stand-in. One VM check with porelo-host's registry intake.

## Estimate

`F271 size=M est=60 basis=median M 61 (24 records)`
