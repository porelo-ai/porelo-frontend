# F257 — Follow It Never Ends Without An Answer

**Status:** Accepted.
**Size:** S - *Follow it* always ends in a followed project or a refusal in words; a public repository is followed without a credential.

**What must be true.** Clicking *Follow it* in *Follow a project* shows that it runs and ends in exactly one of: the project followed (*Go to it*), or a refusal that says what is missing in words. A public repository over HTTPS is followed with no vault entry. A repository that needs a credential the machine lacks is refused naming the vault entry it looked for and how to add it.

## Why

Operator's walk 23, step 9-3 (2026-10-30): *Follow it* did nothing visible when no credential was in the vault, for a public repository.

## Plan

- Find where the follow (`lib/src/ui/project_following_view.dart` and its model) ends without changing the view: an answer from Core that is neither success nor a known refusal, or git asking a credential with no terminal.
- Map every ending to the view; git runs with no terminal prompt (`GIT_TERMINAL_PROMPT=0`), so a missing credential is an answer, not a wait.
- **Red first:** a test with a fake Core that answers the walk's case reproduces the silent ending; it then shows the refusal or the followed project.

## Test

Only the change: the tests above and the follow's own tests. On VM B: one follow of a public repository with an empty vault.

## Findings

- The offline credential check can answer `NO_CREDENTIAL` or `VAULT_LOCKED` for HTTPS with no credential record, without learning whether the repository is public. The daemon's actual follow can try with no credential.
- The daemon's follow fetch receives its credential and certificate environment without explicitly disabling Git's terminal prompt. That guarantee belongs in the daemon, which is outside this worktree's write scope.

## Implementation

- `lib/src/app/project_following.dart` lets the follow decide whether HTTPS needs a credential when the offline check has no credential record. A declared credential's refusal still holds the follow.
- Progress and empty-answer refusals use the existing answer place. Credential refusals carry the entry and storage command Core supplies; `lib/src/ui/project_following_view.dart` uses its existing detail text for a follow's storage remedy.
- Unexpected check or follow exceptions replace progress with a refusal and clear the busy state; a storage command is shown only when it needs no standard input, otherwise the entry and required piped value are named.
- `test/ui/project_following_test.dart` covers public HTTPS, private-repository refusal metadata, empty answers, pending progress, and preserving a declared credential's refusal. No control, layout, or dialog step changes.

## Validation

- Red first: the fake Core's empty check and pending answer found zero `follow-problem` widgets; both HTTPS cases expected one follow call and got zero. The empty final follow and missing remedy cases also failed before the implementation.
- The declared-credential guard was removed temporarily: its regression expected one `follow-check-says` widget and found zero. The guard is restored.
- The displayed storage command failed its process regression with `Expected: <0>; Actual: <2>` before shell quoting preserved Core's argument boundaries.
- Red first for unexpected check and follow failures: format, state, and timeout failures escaped instead of replacing progress; a credential requiring standard input showed no explanation of its pipe.
- Fifteen widget regressions and one command process regression pass, none skipped; the empty-answer tests assert the refusal text and the absence of progress. Existing follow scenarios were not rerun in this fix round; no VM run.
- The final changes have a read-only review against `dart-add-unit-test`, `dart-build-cli-app`, `dart-run-static-analysis`, `dart-use-pattern-matching`, and `dart-write-documentation` version `2026.910.3`, and `flutter-add-widget-test` version `2026.911.3`, with no remaining findings. Plain `dart format` and `dart analyze` pass.

## To be checked

- Verify the public HTTPS follow with an empty vault on VM B; its assigned SSH account and identity are not defined in this worktree. The walk's exact silent ending remains unverified.

## Deferred

- The private-HTTPS refusal test depends on Core supplying `detail` and `storeCommand`.
- Whether Core's follow sets `GIT_TERMINAL_PROMPT=0` remains a question for Agent Core.
- Cleaning existing machine-specific examples in other documents and test fixtures is outside this fix.

## Estimate

`F257 size=S est=15 basis=median S 15 (11 records)`
