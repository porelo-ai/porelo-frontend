# F274 — Push And Pull With The Central Forge Started By A Person

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - adds project actions, vault-to-SSH delivery and central pull requests and reviews across app, client and host package boundaries.

**What must be true.** A person admitted to push sees *Push the approved main…* and *Take the central state…* on the project. Each runs porelo-host's push or pull on the host with the person's own token on standard input through the tunnel, read from their vault without asking, never written on the host, never on a command line. The answer is shown in the host's words. Pull requests and reviews on the central forge are read and made with the person's own token, started by that person, without webhooks.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the central forge's token never lies on the host.

## Plan

- **Red first:** extend `packages/porelo_host/test/pinned_ssh_test.dart` with a process-seam test that supplies a synthetic credential through a fake vault source. Observe that only the selected host command's standard input receives it. Check arguments, environment, files, callbacks and failure diagnostics for disclosure, including a fake command that echoes input. This guards credential leakage. Extend `test/ui/project_actions_test.dart` to prove an unauthorized action or a missing credential starts no host command.
- Add `ProjectTransfers` in `lib/src/app/project_transfers.dart` and explicit commands in `lib/src/app/commands.dart`, wired through `lib/src/ui/shell.dart` and the project actions in `lib/src/ui/machine_view.dart`. Add `lib/src/ui/project_transfers_view.dart` for progress and results. Use verified admission permissions, independent of the selected role, for *Push the approved main…* and *Take the central state…*. Capture the chosen host, project and repository when the person starts the action. Disable duplicate starts and show the host's public progress, final answer or refusal.
- Extend the `Remote`/`OpenSsh` transport in `packages/porelo_host/lib/src/remote.dart` and its options in `packages/porelo_host/lib/src/ssh.dart` for [F270](README.md#f270)'s config and owned connection. Use its standard-input seam for the Machines push or pull operation. Core owns reading the person's unlocked vault and delivering the credential to that stream without a form or terminal prompt. Keep it out of settings, operation history, command text and host files. Bound completion and distinguish transport loss from a confirmed result; never retry a write automatically.
- Use `ForgeConnection` in `lib/src/app/forge_connection.dart` and `Forge`/`ForgeTokens` in `lib/src/app/forge.dart` as the existing seams for forge selection and authentication. Add a typed adapter for Gorge's central pull request and review behavior, with project controls to list and read them and explicitly create a pull request or submit a review. Authenticate as the current person through Core's vault integration. Do not reuse local gate approval as a central review or assume the existing platform token store is the new vault contract.
- Build against fakes for Core's noninteractive credential delivery, Machines' authorized push/pull of approved main and central state, and Gorge's pull requests and reviews. Those contracts are not implemented yet; confirm their fields before implementing the adapters. Keep gate approval within the host's forge. Remove the assumption that `syncUpstream`, used by `ProjectCheck` in `lib/src/app/project_check.dart` and `Backups` in `lib/src/app/backups.dart`, is permission to fetch the central forge: for joined hosts, those callers must target the host forge. Central transfer belongs to the explicit action. Add no webhook, background transfer or unattended-token option.

## Acceptance

- Opening a project, refreshing its view or reconnecting starts no central transfer or central review request. Each explicit permitted action uses the captured project, repository, host and current person's credential once. A different role with push admission can use it; a role without that admission cannot.
- The process test proves stdin-only credential delivery on success, refusal, disconnect and echoed-input failure. A locked vault or missing token stops before host execution and is said without a secret input form. Host-side non-persistence is verified on a local VM once Machines provides the operation; a fake alone cannot prove it.
- A host refusal about approval, changed state or permission is shown without claiming success. Loss after submission is shown as an unconfirmed result, with no automatic replay. Refresh observed state after confirmed completion.
- Fake Gorge tests cover listing and reading pull requests and reviews, creating a pull request and submitting a review as the current person, and denied or lost responses. Merely viewing a project creates no pull request or review. A local VM check exercises real push and pull with the unlocked vault once the external contracts exist.

## To be checked

- Confirm Machines' exact push/pull invocation, approved-main selection, permission checks, stdin framing, public output and non-persistence guarantee. Confirm Core's credential source and stream delivery so the host never needs the central credential at rest.
- Confirm Gorge's typed pull request and review fields, permission failures, pagination and authentication boundary. Read the served Core contract before extending `FleetBackend` or `lib/src/client/porelo_client.dart`; do not invent methods from operation names.
- Trace project refresh and backup callers to separate local host-forge refresh from central transfer. Confirm how an uncertain push, pull, pull request or review is reconciled before a person retries, and measure the operation deadline on the local VM.

## Test

Only the change: the test above. One VM check with porelo-host's push.

## Estimate

`F274 size=M est=60 basis=median M 61 (24 records)`
