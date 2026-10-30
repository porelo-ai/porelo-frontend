# F277 — Commits Signed With The Person's Key

**Status:** Accepted.
**Size:** S - the access and registry commits signed with the person's key through the agent, and verification by the signers Core names.

**What must be true.** Every commit the interface makes (access file, registry) is signed with the person's key through the SSH agent (`gpg.format ssh`, namespace `git`), never with a key file the interface holds. Verification uses the allowed-signers Core answers for the project (admins' keys, the backup key, task keys as `cert-authority`, old keys with `valid-before`), not a list the interface builds.

## Why

One-click joining from signed state (operator, 2026-10-30), building blocks 1 and 4.

## Plan

- `access_checkout.dart` and `project_workspace.dart` take the signer and allowed-signers from Core.
- **Red first:** a test that a commit is signed through the agent socket and that verification refuses a key Core does not name.

## Test

Only the change: the checkout tests. No VM run.

## Estimate

`F277 size=S est=15 basis=median S 15 (11 records)`
