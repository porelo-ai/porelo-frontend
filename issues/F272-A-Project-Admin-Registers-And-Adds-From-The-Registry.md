# F272 — A Project Admin Registers And Adds From The Registry

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - about a day adapting the existing bring, signed access edits and sync retries to registry people and project-scoped actions.

**What must be true.** A project admin whom `hosts/<host>/access.yml` admits sees "admitted on host X" and *Register the project*, which brings the project to the host in one click (today's bring without pasted values or key paths). *Add a developer* is a pick from the registry's persons; it commits the access file signed by the project admin, brings it to the host and asks for the sync ([F252](README.md#f252), [F253](README.md#f253)). *Remove from the project* is chosen from the project's person list. *Lock in this project* marks the person `locked` in the access file, signed, brought to the host and synced: their access to this project's repositories and rooms goes, their account and other projects stay; *Let back in* undoes it. A person whose key changed without the predecessor's signature cannot be picked, unless an admin replaced their lost or stolen key in the access file ([F280](README.md#f280)). A project admin who may not do something sees who may, with their email where their card names one.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's steps 4, 5 and 7.

## Plan

- Derive admitted hosts from [F269](README.md#f269)'s accepted registry and the person's identity ([F268](README.md#f268)). Wire Register the project through `lib/src/app/commands.dart` and `lib/src/ui/shell.dart`. Use the selected followed project's verified `project.yml` through `BringProjectFile` (`lib/src/app/bring_project_file.dart`) for its access repository and repositories. Match that access address and the person's fingerprint to the host admission before starting. Show permitted project admins and available email when denied.
- Build on the existing secret-free `ProjectBring` and `SignedHostActions` flow, `ProjectBringDialog` and accepted SSH host cards. The legacy root registration dialog and pasted setup inputs are already removed. Add `RegistryProjectRegistration` in `lib/src/app/project_access.dart`, with one-click registration, fresh admission checks and exact project/access confirmation. Keep shell wiring to an injectable project service; the list pages can reuse its commands.
- Reuse `AccessCheckout` and `HostFiles.createProjectSetup`'s existing verified admin signer sets; no new key input or signature verifier is needed. Define the not-yet-served Core and host boundaries once in `lib/src/app/project_access_contract.dart`: verified project source, own identity, pinned admission fingerprint, active admin signers, project-scoped picker and lost-key-replacement verdicts; idempotent signed access edits; exact bundle intake and observed project state. Core preserves unrelated access settings and rejects stale parents. The host adapter uses the existing HostRun private own-account upload pattern. No CLI, token or new socket shape is invented.
- Replace the placeholder `ProjectDevelopersDialog` with the registry person picker and accepted project list. Reuse the existing `AccessDeveloper` login, role, fingerprint and locked state; laptop controls, VPN allocation and central-forge collaborator mutations are already removed. Keep `ProjectDevelopers` as the dialog controller and `ProjectAccess` as its authorization and delivery boundary. Add project-scoped add, remove, lock, let-back-in and Retry commands in `lib/src/app/commands.dart`. Recheck command availability at invocation, retain the displayed membership for stale-person checks, and require scoped key eligibility for both add and let-back-in, including retry. Wrong-project or failed reads invalidate admission and picker choices; registry and settings changes rebuild the dialog. Refusals retain their words and permitted contacts, sourced from trusted cards and the appropriate host or admitted project admins.
- Reuse the host-access signed/publication sequence through `lib/src/app/signed_publication.dart`, shared with `HostAccess`. Persist immutable project requests and signed, published, uploaded and confirmed receipts in `Settings`. Discard obsolete unsigned selections through the same guarded forget operation as host access; retain every signed request for exact retry. Keep confirmed registration in its own durable record so later person edits cannot erase it. Serialize mutations across reopened controllers and notify controls when the shared lock changes. Retry the exact access commit, uploading again before apply because host intake may disappear. Check host, project, both revisions and the selected membership effect; never confirm from process exit. Pin the dialog's whole accepted host card and project revision again at the final signing read. Registration and Retry share the injected idempotent Machine recorder and save the project-host association before marking delivery confirmed; a failed local save keeps the exact signed revision retryable. A repeated Register uses the separate confirmed record instead of signing another change. Core and host implementations remain behind fakes until served. The retired `DeveloperHostSync` and `DeveloperSyncAnswer` are replaced by this typed boundary.
- **Red first:** extend `test/app/project_developers_test.dart` and `test/app/project_developers_upload_test.dart` so selecting a refused person produces no signed change, upload or sync, and a failed upload cannot sync old access. Add project-lock cases proving the other project's access stays intact. Extend `test/app/project_bring_validation_test.dart` so absent admission prevents registration even through a stale callback. These guard unauthorized grants and changes outside the selected project. Add `test/app/project_access_recovery_test.dart` for stale reads and membership, refused-key unlocks, unsigned recovery across restart, host-card/revision pin races, registration recording failures and shared-lock notifications; extend `test/app/project_access_commands_test.dart`, `test/ui/project_people_test.dart` and `test/ui/project_access_callbacks_test.dart` for disabled and retained callbacks and registry-refresh revocations.

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

## Implementation boundary

- `ProjectAccessCore` supplies the verified followed project YAML, project/access revisions, actor login/fingerprint, pinned admission fingerprint, active signer keys, signing availability, scoped eligible fingerprints and authorized lost-key replacements. The accepted registry must independently name the same host, project admin and access repository.
- A `ProjectAccessChange` carries a durable request ID, host and immutable host card, project, access repository, project/base-access revisions, actor login/fingerprint, action, and optional person login/role/fingerprint/locked state. Core signs once per ID and rejects stale bases; publication retries that exact revision. Core separately authorizes delivery of that exact accepted, published request using its signing-time authority, so a self-removal can finish delivery without retaining authority to sign further changes. Revoked identities and removed host admission still refuse delivery. A read-only exact-publication check reconciles a lost push receipt before requiring authority to publish again.
- `ProjectAccessTransport` connects through the accepted card and agent, confirms private project/access bundle intake, and returns observed host, project, project revision, access revision and project-only membership states. No command or additional socket format is assumed.
- `ProjectAccess.rememberMachine` is an injected idempotent local recording operation (the application's `Machines.add`), shared by registration and direct delivery retry. `Settings.projectRegistrations` stores the confirmed registration independently of `projectAccess`; both use the existing checked progress shape. Existing confirmed registration receipts migrate on read.
- The stand-in measures project repository and room removal while retaining the account and other project membership. Preservation of unrelated access settings belongs to Core and remains to be verified with its actual adapter; a fixture that never edits those settings cannot measure it. Served Core fields, actual HostRun delivery and the targeted VM effects still need confirmation before live use.

## Deferred

- Automatic central-forge collaborator grants and revocations; central-forge access remains a prerequisite.
- New list and item pages; the shared project commands and minimal dialog wiring are available for page integration.
