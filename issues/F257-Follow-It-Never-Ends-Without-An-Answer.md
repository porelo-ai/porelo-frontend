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

## Estimate

`F257 size=S est=15 basis=median S 15 (11 records)`
