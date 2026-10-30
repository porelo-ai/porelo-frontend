# F274 — Push And Pull With The Central Forge Started By A Person

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - adds project actions, vault-to-SSH delivery and central pull requests and reviews across app, client and host package boundaries.

**What must be true.** A person admitted to push sees *Push the approved main…* and *Take the central state…* on the project. Each runs porelo-host's push or pull on the host with the person's own token on standard input through the tunnel, read from their vault without asking, never written on the host, never on a command line. The answer is shown in the host's words. Pull requests and reviews on the central forge are read and made with the person's own token, started by that person, without webhooks.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the central forge's token never lies on the host.

## Plan

- **Red first:** extend `packages/porelo_host/test/pinned_ssh_test.dart` with a process-seam test that supplies a synthetic credential through a fake vault source. Observe that only the selected host command's standard input receives it. Check arguments, environment, files, callbacks and failure diagnostics for disclosure, including a fake command that echoes input. This guards credential leakage. Extend `test/ui/project_actions_test.dart` to prove an unauthorized action or a missing credential starts no host command.
- Add `ProjectTransfers` in `lib/src/app/project_transfers.dart` and explicit command factories in `lib/src/app/commands.dart`. Keep page layout and menu placement for the separate page implementation: *Push the approved main…* and *Take the central state…* belong on the project menu; central pull-request listing and creation belong there too, with reading and submitting reviews on the selected central request. Capture the verified host, current person, central forge, project and immutable repository list before credential delivery. Use verified push admission, independent of startup roles; block duplicate starts and retries after an unconfirmed result. A timed-out submission stays pending until the original operation settles, and reconciliation must read observed state after that; a concurrent newer operation invalidates the read. Negative SSH exit codes and provider failures after submission remain unconfirmed.
- Extend `OpenSsh` in `packages/porelo_host/lib/src/remote.dart` with the published host-card config and existing owned master. Disable a fallback connection, retain the pinned account, stream only redacted public progress, and bound completion. `packages/porelo_host/lib/src/project_transfer.dart` is the one command-shape definition: `porelo-host-push <project> [repositories...]` or `porelo-host-push --pull <project> [repositories...]` in the admitted account's login shell, with one newline-terminated credential on stdin. The host selects approved local `main`; pull brings central `main` to `central/main`, which reaches protected local `main` through a local pull request. No token goes into argv, environment, settings, history or a host file. The existing `forge-central-token` bring stop remains unchanged.
- Core's noninteractive `CentralCredentialSource` receives the captured selection and supplies the current person's unlocked-vault token to one callback. A missing or locked credential prevents host execution. No Core method or CLI command is invented before its served contract exists; the platform `ForgeTokens` store is not used as the new vault. Default transport uses the imported host config; tests replace vault delivery and transport.
- The current `Forge` clients have no central pull-request or review calls. Add the typed `CentralForgeReviews` capability, `CentralForgeSource` authentication boundary and explicit `CentralReviews` functions in `lib/src/app/central_reviews.dart`, tested with a stateful fake. Public app types describe pull requests, reviews, decisions and opaque page continuations; they are not assumed JSON fields. List, read, create and review only on the person's explicit request. A lost write response blocks another write until an explicit successful read reconciles observed state. Gate approval remains local to the host forge.
- `ProjectCheck` and `Backups` take a `HostForgeRefresh` adapter for joined hosts. Their shell callers identify imported host cards. Joined refresh and sync fail closed when that adapter is absent, and never fall back to the legacy `RefreshProjects` or `SyncUpstream` calls, whose contract does not identify a host-only target. Other machines retain their existing behavior. Add no webhook, background central transfer or unattended-token option.

## Acceptance

- Opening a project, refreshing its view or reconnecting starts no central transfer or central review request. Each explicit permitted action uses the captured project, repository, host and current person's credential once. A different role with push admission can use it; a role without that admission cannot.
- The process test proves stdin-only credential delivery on success, refusal, disconnect and echoed-input failure. A locked vault or missing token stops before host execution and is said without a secret input form. Host-side non-persistence is verified on a local VM once Machines provides the operation; a fake alone cannot prove it.
- A host refusal about approval, changed state or permission is shown without claiming success. Loss after submission is shown as an unconfirmed result, with no automatic replay. Refresh observed state after confirmed completion.
- Fake Gorge tests cover listing and reading pull requests and reviews, creating a pull request and submitting a review as the current person, and denied or lost responses. Merely viewing a project creates no pull request or review. A local VM check exercises real push and pull with the unlocked vault once the external contracts exist.

## To be checked

- Verify host-side token non-persistence, approved-main authorization and real push/pull using the unlocked vault on a local VM after the external implementations are available. A process fake proves local delivery and redaction, not host behavior.
- Connect Core's served noninteractive credential/admission contract and person-authenticated forge client when available; do not infer method names or credential keys. Supply a served host-only refresh/sync adapter before enabling joined-host checks.
- Measure the operation deadline on that VM. The current five-minute SSH and six-minute overall bounds, and thirty-second central review bound, are conservative unmeasured defaults. Confirm reconciliation reads cover both host and central state before a transfer retry.

## Deferred

- Live Core vault/admission and forge-authentication adapters await a served contract; no platform token-store fallback is built.
- Live central pull-request and review adapter: the existing `Forge` clients lack list/read/create pull requests and list/submit reviews, including their pagination and failure mappings.
- Joined host-forge refresh/sync adapter awaits a served contract that guarantees the central forge is not contacted.
- Project page wiring, progress/result presentation and central review forms belong to the separate page implementation; app functions and command factories are provided here.
- Host-side non-persistence and real unlocked-vault push/pull verification await the external implementations and local VM environment.

## Test

- Red first: `stdin credentials never escape through echoed output or diagnostics` failed with `Expected: false; Actual: <true>; refusal diagnostics must redact stdin`, then passed after redaction.
- `dart test test/pinned_ssh_test.dart` in `packages/porelo_host`: 13 passed, none skipped. Process tests cover stdin-only delivery, echoed output, refused and lost responses, pinned shared-host selection and owned-process timeout cleanup.
- `flutter test test/app/project_transfers_test.dart test/app/central_reviews_test.dart test/app/host_forge_refresh_test.dart test/ui/project_actions_test.dart`: 33 passed, none skipped. The admission, uncertain-review replay and joined-upstream-fallback guards were deliberately broken, seen to fail, and restored. Four further red-first tests reproduce pending-write reconciliation races, negative SSH exits and credential-provider failures after submission; their fixes pass. A joined-sync refusal also failed red before its public return value was fixed.
- `dart analyze` at the app root and in `packages/porelo_host`: no issues. Plain `dart format` ran on the changed Dart files; `git diff --check` passed. No feature or integration generation inputs changed.
- Read-only review by another model checked the requested skills and focused fixes; every finding was reproduced and resolved. No full suite or VM check ran; host-side persistence and live vault/forge behavior remain unverified until the deferred adapters and environment are available.

## Estimate

`F274 size=M est=60 basis=median M 61 (24 records)`
