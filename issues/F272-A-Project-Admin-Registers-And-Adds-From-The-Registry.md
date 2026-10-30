# F272 — A Project Admin Registers And Adds From The Registry

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - about a day adapting the existing bring, signed access edits and sync retries to registry people and project-scoped actions.

**What must be true.** A project admin whom `hosts/<host>/access.yml` admits sees "admitted on host X" and *Register the project*, which brings the project to the host in one click (today's bring without pasted values or key paths). *Add a developer* is a pick from the registry's persons; it commits the access file signed by the project admin, brings it to the host and asks for the sync ([F252](README.md#f252), [F253](README.md#f253)). *Remove from the project* is chosen from the project's person list. *Lock in this project* marks the person `locked` in the access file, signed, brought to the host and synced: their access to this project's repositories and rooms goes, their account and other projects stay; *Let back in* undoes it. A person whose key changed without the predecessor's signature cannot be picked, unless an admin replaced their lost or stolen key in the access file ([F280](README.md#f280)). A project admin who may not do something sees who may, with their email where their card names one.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 4, 5 and 7.

## Plan

- Derive admitted hosts from [F269](README.md#f269)'s accepted registry and the person's identity ([F268](README.md#f268)). Wire Register the project through `lib/src/app/commands.dart` and `lib/src/ui/shell.dart`. Use the selected followed project's verified `project.yml` through `BringProjectFile` (`lib/src/app/bring_project_file.dart`) for its access repository and repositories. Match that access address and the person's fingerprint to the host admission before starting. Show permitted project admins and available email when denied.
- Adapt `ProjectBring` (`lib/src/app/project_bring.dart`) and `ProjectBringDialog` (`lib/src/ui/project_bring_dialog.dart`) so a click uses the registry host card and the person's existing agent identity and tunnel ([F270](README.md#f270)). Retain checked project/access bundles, private upload and the host daemon's confirmation of the expected project revision. Remove these paths' pasted host values, signing-key and SSH-identity file choices, VPN/CA setup and lasting forge-password step; coordinate their general removal with [F276](README.md#f276). Registration moves from the root helper in `lib/src/ui/host_admin_dialog.dart` to the admitted person's own-account flow.
- Adapt `AccessCheckout` (`lib/src/app/access_checkout.dart`) and `HostFiles.createProjectSetup` (`packages/porelo_host/lib/src/host_files.dart`) to the verified project-admin signer set and the person's signing key. Remove the assumption that one selected project key signs everything. Project admins' keys, with the backup-key restrictions from [F268](README.md#f268), replace the project's own signing key. Core supplies trust and authorization; do not implement a second signature verifier or parse its CLI. Keep credentials in Core's helper or terminal paths, never form fields or recorded arguments.
- Replace `ProjectDevelopersDialog` and its opening wizard (`lib/src/ui/project_developers_dialog.dart`) with the registry person picker and the project's person list. Replace `AccessLaptop`, the laptop-required `AccessDeveloper` shape and VPN address allocation in `lib/src/app/access_developers.dart` with the agreed person login, role, fingerprint and locked state. Preserve unrelated access settings when editing. Share the changed access model with the join path ([F273](README.md#f273)). Remove add/remove-laptop controls and automatic central-forge collaborator grants and revocations from `ProjectDevelopers` (`lib/src/app/project_developers.dart`); central access is a prerequisite.
- Extend `ProjectDevelopers`, `DeveloperHostSync` and `DeveloperSyncAnswer` in that file for add, remove, project lock and let back in. Sign and publish access, upload through `HostRun` (`packages/porelo_host/lib/src/host_run.dart`), then request sync as in [F252](README.md#f252) and [F253](README.md#f253). Retain the published revision for retry without another commit and persist pending delivery through `Settings` (`lib/src/app/settings.dart`). Core's person/access verdicts and Machines' registration and sync answers are not built yet; test their agreed shapes behind fakes. A changed key without its predecessor's signature stays unselectable unless Core confirms an authorized replacement in this project's access file ([F280](README.md#f280)).
- **Red first:** extend `test/app/project_developers_test.dart` and `test/app/project_developers_upload_test.dart` so selecting a refused person produces no signed change, upload or sync, and a failed upload cannot sync old access. Add project-lock cases proving the other project's access stays intact. Extend `test/app/project_bring_validation_test.dart` so absent admission prevents registration even through a stale callback. These guard unauthorized grants and changes outside the selected project.

## Acceptance

- An admitted project admin sees the named host and registers the selected verified project with one click. No pasted public values, key paths or secret fields intervene. Missing admission, a mismatched access address, an unverified project or unavailable signing agent prevents publication and upload with a reason.
- Register succeeds only after the host confirms the intended project and revision. Repeated clicks while busy do not register twice. Failed delivery remains retryable without repeating a published access change.
- Add chooses a Core-eligible registry person and signs and publishes their login, role and fingerprint before uploading and syncing the exact access revision. Refused cards and unapproved key changes produce no mutation. An authorized lost-key replacement is accepted only for the access scope Core confirms.
- Remove, lock and let back in change only the selected project's access. A host stand-in with two projects observes the locked person's repositories and rooms removed only from that project, while the account and other membership remain. Unlock restores only the retained membership. No success is inferred from process exit alone.
- Publication failure causes no host change; upload failure causes no sync; a wrong project or access revision cannot confirm success. Restart and retry finish the pending delivery without another commit. The targeted VM check later verifies the actual Machines registration and project sync effects.

## Open questions

None.

## To be checked

- Confirm Core's served fields for person identity, project-admin authorization, signer sets and authorized key replacement. Confirm the person-based access schema, including the signed project lock and how an admin's access-file replacement affects picker eligibility.
- Confirm Machines' own-account registration, bundle inputs, SSH service endpoints and sync/status replies for project locks and room removal. Today's sync reply reports laptop changes, not project lock effects; keep those new replies behind fakes until available.
- Confirm the source of the verified project selection and access address for an admitted admin on a new desktop. Check pending registration and access-delivery recovery, concurrent edits and retries after restart against the exact published revision.

## Test

Only the change: tests against a fake Core and the host stand-in. One VM check with porelo-host's sync.

## Estimate

`F272 size=M est=60 basis=median M 61 (24 records)`
