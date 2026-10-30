# F274 — Push And Pull With The Central Forge Started By A Person

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - adds project actions, terminal-to-SSH delivery and central pull requests and reviews across app, client and host package boundaries.

**What must be true.** A person admitted to push sees *Push the approved main…* and *Take the central state…* on the project. Each runs porelo-host's push or pull on the host with the person's own token on standard input through the tunnel, read from their vault without asking, never written on the host, never on a command line. The answer is shown in the host's words. Pull requests and reviews on the central forge are read and made with the person's own token, started by that person, without webhooks.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the central forge's token never lies on the host.

## Plan

- **Red first:** extend `packages/porelo_host/test/pinned_ssh_test.dart` to reproduce early broken-pipe refusals and CRLF redaction, and `packages/porelo_host/test/project_transfer_test.dart` to run the terminal feed with executable credential and SSH fakes. Only the selected host command's standard input receives the synthetic credential. Check arguments, environment, files, callbacks and diagnostics for disclosure, including echoed input. `test/ui/project_actions_test.dart` proves unauthorized actions and unavailable local credentials start no host command.
- Add `ProjectTransfers` in `lib/src/app/project_transfers.dart` and explicit command factories in `lib/src/app/commands.dart`. Keep page layout and menu placement for the separate page implementation: *Push the approved main…* and *Take the central state…* belong on the project menu; central pull-request listing and creation belong there too, with reading and submitting reviews on the selected central request. Capture the verified host, current person, central forge, project and immutable repository list before credential delivery. Use verified push admission, independent of startup roles; block duplicate starts and retries after an unconfirmed result. A timed-out submission stays pending until the original operation settles, and reconciliation must read observed state after that; a concurrent newer operation invalidates the read. Negative and signal-derived SSH exits and provider failures after submission remain unconfirmed.
- `packages/porelo_host/lib/src/project_transfer.dart` defines `porelo-host-push <project> [repositories...]` and `porelo-host-push --pull <project> [repositories...]` in the admitted account's login shell. Its terminal feed uses the published host-card config and existing owned master, disables fallback, and merges and redacts host output before Dart receives it. `SecretsFile.projectTransferScripts` supplies exactly one `forge-central-token <base64 of token>` line. `OpenSsh` retains stdin-only redaction for its other callers, drains confirmed host refusals after a broken stdin pipe, and cleans up its owned child on callback failures. The host selects approved local `main`; pull brings central `main` to `central/main`, which reaches protected local `main` through a local pull request. No token goes into argv, environment, settings, history or a host file. The existing `forge-central-token` bring stop remains unchanged.
- `CentralTransferSource` takes public selections and returns public terminal results; no token-bearing callback enters Dart. `TransferTerminal` captures this interface instance's `Settings.secretsFile` and a visible terminal opener. Only `keepassxc-cli` inside that terminal reads the root entry `forge-central-token`, and the shell pipes its encoded line to SSH after local validation. Local config and terminal-spawn failures remain retryable. Once an owned terminal may submit, a lost output stream is unconfirmed unless the terminal explicitly confirms that it sent nothing. All failures, including Dart Errors, release busy state and retain uncertainty where submission was possible. Core supplies verified admission only; neither Core nor the platform token store supplies the transfer token.
- The current `Forge` clients have no central pull-request or review calls. Add the typed `CentralForgeReviews` capability, `CentralForgeSource` authentication boundary and explicit `CentralReviews` functions in `lib/src/app/central_reviews.dart`, tested with a stateful fake. Public app types describe pull requests, reviews, decisions and opaque page continuations; they are not assumed JSON fields. List, read, create and review only on the person's explicit request. A lost write response, including decoding Errors, blocks another write until an explicit successful read reconciles observed state. Known sanitized refusals keep their reasons. Write commands recheck current availability at dispatch, and write-state transitions notify menus. Gate approval remains local to the host forge.
- `ProjectCheck` and `Backups` take a `HostForgeRefresh` adapter for joined hosts. Their shell callers identify imported host cards. Every check and sync caller explicitly identifies whether it is a joined host; sync captures its own project and repository without changing an open backup listing. Joined refresh and sync fail closed when that adapter is absent, and never fall back to the legacy `RefreshProjects` or `SyncUpstream` calls, whose contract does not identify a host-only target. Other machines retain their existing behavior. Add no webhook, background central transfer or unattended-token option.

## Acceptance

- Opening a project, refreshing its view or reconnecting starts no central transfer or central review request. Each explicit permitted action uses the captured project, repository, host and current person's credential once. A different role with push admission can use it; a role without that admission cannot.
- The process test proves stdin-only credential delivery on success, refusal, disconnect and echoed-input failure. A locked vault or missing token stops before host execution and is said without a secret input form. Host-side non-persistence is verified on a local VM once Machines provides the operation; a fake alone cannot prove it.
- A host refusal about approval, changed state or permission is shown without claiming success. Loss after submission is shown as an unconfirmed result, with no automatic replay. Refresh observed state after confirmed completion.
- Fake Gorge tests cover listing and reading pull requests and reviews, creating a pull request and submitting a review as the current person, and denied or lost responses. Merely viewing a project creates no pull request or review. A local VM check exercises real push and pull with the unlocked vault once the external contracts exist.

## To be checked

- Verify host-side token non-persistence, approved-main authorization and real push/pull using the unlocked vault on a local VM after the external implementations are available. A process fake proves local delivery and redaction, not host behavior.
- Connect Core's served admission contract and the person-authenticated forge client when available; do not infer method names or credential keys. Supply a served host-only refresh/sync adapter before enabling joined-host checks.
- Measure the operation deadline on that VM. The current five-minute terminal and six-minute overall bounds, and thirty-second central review bound, are conservative unmeasured defaults. Confirm reconciliation reads cover both host and central state before a transfer retry.

## Deferred

- Live verified-admission and forge-authentication adapters await a served contract; the transfer token comes only from the local secrets-file terminal, with no platform token-store fallback.
- Live central pull-request and review adapter: the existing `Forge` clients lack list/read/create pull requests and list/submit reviews, including their pagination and failure mappings.
- Joined host-forge refresh/sync adapter awaits a served contract that guarantees the central forge is not contacted.
- Project page wiring, progress/result presentation and central review forms belong to the separate page implementation; app functions and command factories are provided here.
- Host-side non-persistence and real unlocked-vault push/pull verification await the external implementations and local VM environment.
- Migration of the legacy bring/removal token entry is outside this transfer fix; the existing bring stop remains unchanged, while explicit transfers use the agreed root entry.
- Existing machine-specific identifiers in `doc/walks/19-sprints-6e-to-6i-a-rented-server.json`, `doc/walks/21-sluice-tried-on-this-laptop.json` and `tool/walk_on_this_laptop.sh` are outside this transfer fix; the tracked-file scan found none in changed or new files.

## Test

- Red first: the early-pipe refusal test failed `Expected: 65; Actual: 255`; CRLF redaction failed `Expected: false; Actual: true`; pre-start failure was `unconfirmed` instead of `unavailable`; provider/progress and central decoding Errors escaped; backup sync changed the open listing to the refused target; invalid names reported available; captured central commands dispatched twice. Each behavior was reproduced before its fix.
- The root-entry process test failed because the legacy shared entry was requested. Restoring bare-token delivery made the terminal process test fail `Expected: 0; Actual: 93; invalid token protocol`. Disabling notifications failed `Expected: non-empty; Actual: []`; disabling target capture sent both syncs to the open listing. Those guards were restored and passed.
- The terminal-output loss test failed `Expected: unconfirmed; Actual: unavailable`. The independent review's added signal-exit test failed `Expected: unconfirmed; Actual: refused` for 129; the launch-timeout test returned a result instead of throwing `RemoteNotStarted`. Their fixes passed and received a focused read-only review.
- `dart test test/pinned_ssh_test.dart test/project_transfer_test.dart` in `packages/porelo_host`: 25 passed before the final launch-timeout correction; its complete changed test file was rerun afterward, 17 passed, none skipped. The unchanged terminal-feed file contributes 9 passing tests, for 26 package tests covering stdin delivery, root entry, encoded lines, failure paths, redaction and cleanup.
- `flutter test test/app/project_transfers_test.dart test/app/central_reviews_test.dart test/app/host_forge_refresh_test.dart test/app/transfer_terminal_test.dart test/ui/project_actions_test.dart test/client/live_refresh_test.dart`: 40 passed, 5 live tests skipped. After the final signal-exit correction, the complete changed transfer test file was rerun, 11 passed, none skipped. Other code and test files were unchanged by those final corrections.
- The five skipped live tests were `a followed project is fetched now, and its record says when`, `a project this account does not follow is refused by name`, `"Check it now" says the follow and each repository, as the page shows them`, `a task is brought up to its source, with what moved and whether its agent heard`, and `a repository started in a checkout says so, with the checkout as where its work goes`. They require a configured live daemon and project or task.
- `dart analyze` at the app root and in `packages/porelo_host`: no issues after the final fixes. Plain `dart format` ran on all 18 changed Dart files; `git diff --check` passed. No feature or integration generation inputs changed, so build-runner generation was not needed.
- Read-only review by another model applied `dart-add-unit-test` 2026.910.3, `dart-write-documentation` 2026.910.3, `flutter-add-widget-test` 2026.911.3, `clean-code` 2026.906.3, `security-audit` 2026.906.3 and `test-quality` 2026.906.3. Both findings from that reading were reproduced, fixed and read again without findings. No full suite or VM check ran; live host non-persistence, admission and forge behavior remain blocked on the deferred implementations and environment.

## Review findings

| Finding | Result | Files and verification |
| --- | --- | --- |
| 1. Early stdin closure hides refusal | Fixed | `remote.dart`; `pinned_ssh_test.dart` preserves host exit 65 and stderr after a broken pipe. |
| 2. Local failures become uncertain | Fixed | `project_transfers.dart`, `transfer_terminal.dart`, `remote.dart`; preflight, spawn and launch-timeout tests keep local failures retryable. |
| 3. Transfer Errors bypass cleanup | Fixed | `project_transfers.dart`, `transfer_terminal.dart`, `remote.dart`; provider/progress Error tests check busy release, process cleanup and reconciliation. |
| 4. Central decoding Errors allow replay | Fixed | `central_reviews.dart`; create/review Error tests keep writes uncertain and diagnostics sanitized. |
| 5. Joined-host defaults permit fallback | Fixed | `backups.dart`, `project_check.dart` and their callers require explicit `joinedHost`; host-forge tests prove joined calls fail closed. |
| 6. CRLF echoes disclose input | Fixed | `remote.dart`; input redaction uses the same line splitting as decoded output, tested with CRLF, CR and LF. |
| 7. Sanitized refusal reasons are lost | Fixed | `central_reviews.dart` preserves `ForgeRefused` and uses a general connection/authentication refusal for unknown pre-request failures; no wording-only test added. |
| 8. Sync overwrites or races the listing target | Fixed | `backups.dart`; host-forge tests preserve the listing and capture independent sync targets. |
| 9. Invalid selections report available | Fixed | `project_transfers.dart`; transfer tests reject missing forges and invalid project/repository names before execution. |
| 10. Central write commands go stale | Fixed | `commands.dart`, `central_reviews.dart`; command dispatch rechecks live state and notification tests cover settlement and reconciliation. |
| 11. Token source enters Dart through Core | Fixed | `project_transfers.dart`, `transfer_terminal.dart`, `project_transfer.dart`, `secrets_file.dart`; the terminal reads the local root entry, with no token callback in Dart. |
| 12. Bare-token stdin form is wrong | Fixed | `project_transfer.dart`, `secrets_file.dart`; terminal process tests require the encoded labeled line for push and pull. |

## Estimate

`F274 size=M est=60 basis=median M 61 (24 records)`
