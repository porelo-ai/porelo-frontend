# F272 — A Project Admin Registers And Adds From The Registry

**Status:** Accepted.
**Size:** M - *Register the project* at one click once admitted, and developers added and removed by a pick from the registry's persons.

**What must be true.** A project admin whom `hosts/<host>/access.yml` admits sees "admitted on host X" and *Register the project*, which brings the project to the host in one click (today's bring without pasted values or key paths). *Add a developer* is a pick from the registry's persons; it commits the access file signed by the project admin, brings it to the host and asks for the sync ([F252](README.md#f252), [F253](README.md#f253)). *Remove from the project* is chosen from the project's person list. *Lock in this project* marks the person `locked` in the access file, signed, brought to the host and synced: their access to this project's repositories and rooms goes, their account and other projects stay; *Let back in* undoes it. A person whose key changed without the predecessor's signature cannot be picked. A project admin who may not do something sees who may, with their email.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 4, 5 and 7.

## Plan

- Built on the access checkout and the bring of today, with the host values taken from the registry's host card.
- The project's signers are its project admins' keys (and a backup key, [F268](README.md#f268)); the project's own signing key goes ([F276](README.md#f276)).
- **Red first:** a test that *Add* commits, uploads and syncs; a test that a refused card cannot be picked.

## Test

Only the change: tests against a fake Core and the host stand-in. One VM check with porelo-host's sync.

## Estimate

`F272 size=M est=60 basis=median M 61 (24 records)`
