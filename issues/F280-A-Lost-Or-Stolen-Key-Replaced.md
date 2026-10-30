# F280 — A Lost Or Stolen Key Replaced

**Status:** Accepted.
**Size:** S - another admin, or the backup key, replaces an admin's lost or stolen key in the access file or in the registry's owners.yml.

**What must be true.** A project admin can revoke another person's key in the project's access file and enter their new key, and a host admin can do the same in `hosts/<host>/access.yml`, chosen from the person list; the person keeps their login. A successor card signed by a revoked key is never offered; a registry owner can do the same in `owners.yml` for a host admin or another owner. A revoked key's person is shown locked on every host at once. Where a project, a host or the registry has a single admin or owner, *Use the backup key…* takes the offline backup key's file for this one commit: it may only replace the lost key's entry among the signers or in `owners.yml`, and the interface refuses any other change with it, in Core's words. The backup key file is read once, never copied and never kept; a new backup key is offered afterwards ([F268](README.md#f268)).

## Why

One-click joining from signed state (operator, 2026-10-30): an admin's own key is replaced by another admin or by the backup key; a stolen key is revoked first and locks the person's host accounts at once.

## Plan

- The commits go through Core's verbs; the interface signs nothing itself.
- **Red first:** a test that a backup-key commit changing anything but the lost entry is refused before anything is pushed; a test that a revoked person shows locked on each host.

## Test

Only the change: tests against a fake Core. No VM run.

## Estimate

`F280 size=S est=15 basis=median S 15 (11 records)`
