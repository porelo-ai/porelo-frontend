# F271 — A Host Admin Admits From The Registry

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - about a day across preparation hooks, registry mutations, host delivery and admin actions, reusing the shared registry and SSH work.

**What must be true.** Only a host admin named in the registry's `owners.yml` is offered *Prepare a server…* and *Admit*; anyone else sees who may, with their email where their card names one. When *Prepare a server…* has a ready server, the interface files `hosts/<host>/card` (name, address, SSH port, SSH host key, services with the forge's web and Git ports and the homeserver's port), signed by the host admin. The give-back deletes it, only after the give-back was confirmed ([F264](README.md#f264)'s order). *Admit* is a pick from the registry's persons; it commits `hosts/<host>/access.yml` (each project with its admin, that admin's key fingerprint and its access repository's address, since the host anchors on its pinned host admin alone), brings the registry to the host through the tunnel, and asks for the sync. Lock, let back in and delete an account are chosen from the host's person list, with [F262](README.md#f262)'s words. A host whose synced commit is behind the registry shows "not on the host yet" with *Bring it to the host*.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 2, 3 and 7.

## Plan

- Use `Registry`'s accepted state and Core's current proven login/fingerprint in new `lib/src/app/host_access.dart`. Read the distinct host-admin entries accepted from `owners.yml`, require the matching trusted card and assigned host admin, and recheck before setup, signing, publication, upload and sync. Return permitted names and available email on refusal; never substitute registry owners for host admins.
- Keep the unbuilt signing/publication and pinned-host intake/sync contracts behind `HostRegistryWriter` and `HostRegistryTransport` in `lib/src/app/host_access_contract.dart`. The request carries one durable ID for idempotent signing, host, action, selected login/fingerprint, project and access repository, or the checked public card. The host answer carries host, applied registry revision, membership states and its own words. Do not guess a helper command or intake path before those adapters are available.
- Extend `PreparedHost`, `Step` and `HostRun` in `packages/porelo_host/lib/src/` to read, validate and round-trip the SSH-only completion: name, public address, SSH port, host key and nested service ports. Keep compatibility with existing completion records while the VPN removal is built separately. `HostRuns._addHost` publishes only after checked process success and matching completion, retains the completion before publication, and marks it ready without a VPN. Publication retry calls `HostAccess`, never setup.
- Persist exact signed revision, publication, delivery revision and final confirmation in `Settings`, with the published host card distinct from other operations. Refresh the accepted registry after publication. Bring recovers a retained ready completion even if publication never created progress, and a completed card publication permits a changed replacement card. A failed publication causes no upload; a failed upload causes no sync. Retry reuses the request ID and signed commit, checks verified ancestry before delivering a newer revision, and accepts a confirmed descendant without replaying superseded membership changes. A wrong host, fork, unknown revision or wrong membership at the original revision remains pending. Explicit Bring reads current host status and uploads again before sync when that revision is not applied; an old intake receipt cannot prove that staging survived. An unfiled admission whose selected card changes or is refused can be discarded and selected again.
- Persist provider return in its own `Settings` record after `hostGivenBack` confirms success, and clear the old ready completion. Both `HostRuns.confirmDown` and the standalone `HostDialog` teardown use the same app function and display deletion refusals with the permitted contacts after restart too. A concurrent admission cannot overwrite the return marker; only card deletion may continue afterward. A failed deletion retains recovery across restart, without another provider call. Name reuse clears the completed return and old registry progress before a new setup can rent; unfinished deletion prevents renting.
- Expose Prepare, Admit, Lock, Let back in, Delete the account and Bring it to the host as app operations for the new pages. Daily host operations require an accepted host entry and its assigned admin; new setup and return-card deletion allow an absent host entry without contacting the host. Host membership selection comes from a checked host status, excludes purged accounts, and requires a trusted registry person before unlock; permanent deletion requires a host lock and a separate confirmation. Returned hosts refuse retained membership callbacks. Gate existing commands, retire the callable laptop-block admission and host-admin registration menu, and replace manual public-value handover with publication status. Page composition belongs to [F278](README.md#f278); VPN removal belongs to [F276](README.md#f276).
- **Red first:** `test/app/host_access_test.dart` proves refused upload prevents sync, retains the signed revision and refuses a wrong sync revision. `test/app/host_runs_test.dart` and `test/ui/host_take_down_confirmation_test.dart` guard ready-before-card and confirmed-give-back-before-deletion. Additional harmful interleavings cover revocation during status, concurrent give-back, stale receipts, unsafe repository addresses and malformed retry records.

## Acceptance

- A non-admin cannot invoke preparation or admission, even through a retained callback after permissions change. The interface names the permitted host admins and available email. Refused registry people cannot be selected or written.
- A ready setup files one signed card with all public SSH and service fields. Waiting, malformed and failed completions file none. A publication retry does not rerun setup. Confirmed give-back precedes deletion; a failed give-back leaves the card and recovery state intact.
- Admit publishes the selected person's fingerprint and project/access address, uploads that signed revision, then syncs. A failed publication causes no upload; a failed upload causes no sync. A wrong host or revision is refused. Retry survives restart without a second commit or admission.
- Lock, let back in and delete target the selected host membership only and display the host's confirmed result. Registry state and the host's last applied revision remain distinct. A stale host offers Bring it to the host until the intended revision is confirmed.
- Tests use fake Core and Machines contracts. When their implementations are available, the targeted VM check proves registry intake accepts a descendant and refuses an older signed state without restoring a removed person. No laptop key block or secret field is part of admission.

## Open questions

None.

## To be checked

- Bind Core's signing adapter to the centralized request shape, including request-ID deduplication, host-admin entries, project/access association, host-wide lock/deletion, successor authorization and verified registry ancestry (`descendsFrom`). The generic registry filing API cannot yet carry these payloads.
- Bind the pinned SSH transport adapter once registry intake authorization, private setup location and sync/status commands are implemented. Its checked answer must identify the host, applied registry revision and each selected membership result.
- Run the targeted VM intake check when those implementations are available: accept a descendant; refuse an older signed state without restoring a removed person. The frontend fake checks revision/host confirmation and retry order, not the host's signature or ancestry implementation.

## Deferred

- Sanitizing preexisting machine-specific paths and VM addresses in unrelated walk guides and scripts is outside host administration; this change adds none.

## Test

Only the change: tests against a fake Core and the host stand-in. One VM check with porelo-host's registry intake.

## Estimate

`F271 size=M est=60 basis=median M 61 (24 records)`
