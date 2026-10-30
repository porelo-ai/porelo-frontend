# F271 — A Host Admin Admits From The Registry

**Status:** Accepted.
**Size:** M - a server's card filed when it is ready and deleted after its give-back, and project admins admitted, locked and removed by commits to the registry that are brought to the host.

**What must be true.** Only a host admin named in the registry's `owners.yml` is offered *Prepare a server…* and *Admit*; anyone else sees who may, with their email. When *Prepare a server…* has a ready server, the interface files `hosts/<host>/card` (name, address, SSH port, SSH host key, services with the forge's ports and SSH host key, the homeserver's port), signed by the host admin. The give-back deletes it, only after the give-back was confirmed ([F264](README.md#f264)'s order). *Admit* is a pick from the registry's persons; it commits `hosts/<host>/access.yml` (each project with its admin and its access repository's address), brings the registry to the host through the tunnel, and asks for the sync. Lock, let back in and delete an account are chosen from the host's person list, with [F262](README.md#f262)'s words. A host whose synced commit is behind the registry shows "not on the host yet" with *Bring it to the host*.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 2, 3 and 7.

## Plan

- The upload reuses the own-account bundle path ([F252](README.md#f252)), with the whole registry as Core and Machines agreed.
- **Red first:** a test that the card is filed only once the server is ready and deleted only after a confirmed give-back; a test that *Admit* commits, uploads, then asks for the sync, in that order.

## Test

Only the change: tests against a fake Core and the host stand-in. One VM check with porelo-host's registry intake.

## Estimate

`F271 size=M est=60 basis=median M 61 (24 records)`
